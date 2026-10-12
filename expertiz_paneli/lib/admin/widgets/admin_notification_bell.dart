/// Admin bildirim zili: personel saha adımları (harekete geçti, araç başında,
/// kurumsal ekspertizde), onaya gelen raporlar ve görev aktif/pasif
/// değişiklikleri. 30 sn'de bir yenilenir; yeni bildirim kısa mesajla görünür.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

class AdminNotificationBell extends StatefulWidget {
  const AdminNotificationBell({
    super.key,
    this.apiService,
    this.color,
    this.refreshInterval = const Duration(seconds: 30),
    this.onOpenReport,
  });

  final YerimebakExpertizApiService? apiService;
  final Color? color;
  final Duration refreshInterval;

  /// Bildirime tıklanınca (ör. Araç Operasyonu sekmesine geçmek için).
  final void Function(String reportId)? onOpenReport;

  @override
  State<AdminNotificationBell> createState() => _AdminNotificationBellState();
}

class _AdminNotificationBellState extends State<AdminNotificationBell> {
  late final YerimebakExpertizApiService _api;
  Timer? _timer;
  List<Map<String, dynamic>> _items = [];
  int _unread = 0;
  int? _lastId;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load(initial: true);
    _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final response = await _api.getNotifications(admin: true, limit: 50);
      final rows = (response['notifications'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      final newest = rows.isEmpty ? null : (rows.first['id'] as num?)?.toInt();
      final isNew = !initial && newest != null && _lastId != null && newest != _lastId;
      setState(() {
        _items = rows;
        _unread = (response['unread'] as num?)?.toInt() ?? 0;
        _lastId = newest ?? _lastId;
      });
      if (isNew) {
        final n = rows.first;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text('${n['title']}${(n['body'] ?? '').toString().isEmpty ? '' : ' — ${n['body']}'}'),
        ));
      }
    } catch (_) {
      // Bağlantı hatası: bir sonraki yenilemede tekrar denenir
    }
  }

  Future<void> _open() async {
    if (_unread > 0) {
      setState(() => _unread = 0);
      try {
        await _api.markNotificationsRead(admin: true);
      } catch (_) {}
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bildirimler'),
        content: SizedBox(
          width: 460,
          child: _items.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text('Henüz bildirim yok'))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    final created = DateTime.tryParse(n['created_at']?.toString() ?? '');
                    final reportId = n['report_id']?.toString();
                    return ListTile(
                      dense: true,
                      leading: Icon(_icon(n['kind']?.toString() ?? '')),
                      title: Text(n['title']?.toString() ?? ''),
                      subtitle: Text([
                        n['body']?.toString() ?? '',
                        if (created != null) DateFormat('dd.MM.yyyy HH:mm').format(created.toLocal()),
                      ].where((e) => e.isNotEmpty).join('\n')),
                      onTap: reportId == null || widget.onOpenReport == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              widget.onOpenReport!(reportId);
                            },
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
      ),
    );
  }

  static IconData _icon(String kind) {
    switch (kind) {
      case 'task_depart':
        return Icons.directions_car;
      case 'task_arrive':
        return Icons.place;
      case 'task_corporate':
        return Icons.business;
      case 'report_submitted':
        return Icons.assignment_turned_in;
      case 'duty_changed':
        return Icons.toggle_on;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('adminNotificationsButton'),
      tooltip: 'Bildirimler',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 99 ? '99+' : '$_unread'),
        child: Icon(Icons.notifications, color: widget.color),
      ),
    );
  }
}

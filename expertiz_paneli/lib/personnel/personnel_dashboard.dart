/// PERSONEL PANELİ
///
/// - Görev için aktif / pasif anahtarı (pasif personele yeni görev atanmaz)
/// - Görevler: Aktif, Beklemede (admin kontrolünde), Reddedildi (düzelt ve
///   tekrar gönder), Tamamlanan (admin onayladı, müşteriye gönderildi)
/// - Saha adımları: Kabul et → Harekete geçtim → Araç başındayım →
///   Kurumsal ekspertizdeyim → Rapora başla. Her adım müşteriye ve admine
///   anlık bildirim olarak düşer.
/// - Bildirimler: yeni görev, red (nedeniyle), onay.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../providers/expertiz_provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../screens/personel/expertiz_sihirbazi.dart';
import '../services/yerimebak_expertiz_api_service.dart';

/// Saha adımı düğmeleri (backend task_progress.ACTIONS ile aynı sıra).
const Map<String, String> kGorevAdimEtiketleri = {
  'accept': 'Görevi Kabul Et',
  'depart': 'Harekete Geçtim',
  'arrive': 'Araç Başındayım',
  'corporate': 'Kurumsal Ekspertizdeyim',
  'start': 'Rapora Başla',
};

const Map<String, IconData> _adimIkonlari = {
  'accept': Icons.check,
  'depart': Icons.directions_car,
  'arrive': Icons.place,
  'corporate': Icons.business,
  'start': Icons.edit_note,
};

const Map<String, String> _asamaEtiketleri = {
  'assigned': 'Personele atandı',
  'accepted': 'Kabul edildi',
  'on_the_way': 'Harekete geçti',
  'at_vehicle': 'Araç başında',
  'at_corporate': 'Kurumsal ekspertizde',
  'in_progress': 'Rapor hazırlanıyor',
  'submitted': 'Rapor gönderildi',
};

class PersonnelDashboard extends StatefulWidget {
  const PersonnelDashboard({super.key, this.apiService, this.refreshInterval = const Duration(seconds: 20)});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;
  final Duration refreshInterval;

  @override
  State<PersonnelDashboard> createState() => _PersonnelDashboardState();
}

class _PersonnelDashboardState extends State<PersonnelDashboard> {
  late final YerimebakExpertizApiService _api;
  Timer? _timer;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _me = const {};
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _notifications = [];
  int _unread = 0;
  int? _lastNotificationId;
  bool _dutyBusy = false;
  final Set<String> _busyTasks = {};

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

  static List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  Future<void> _load({bool initial = false}) async {
    try {
      final results = await Future.wait([
        _api.getPersonnelMe(),
        _api.getMyTasks(),
        _api.getNotifications(limit: 30),
      ]);
      if (!mounted) return;
      final notifications = _rows(results[2]['notifications']);
      final newestId = notifications.isEmpty ? null : (notifications.first['id'] as num?)?.toInt();
      final hasNew = !initial && newestId != null && _lastNotificationId != null && newestId != _lastNotificationId;
      setState(() {
        _me = Map<String, dynamic>.from(results[0]['personnel'] as Map? ?? const {});
        _tasks = _rows(results[1]['tasks']);
        _notifications = notifications;
        _unread = (results[2]['unread'] as num?)?.toInt() ?? 0;
        _lastNotificationId = newestId ?? _lastNotificationId;
        _error = null;
        _loading = false;
      });
      if (hasNew) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(notifications.first['title']?.toString() ?? 'Yeni bildirim')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Veriler yüklenemedi: $e';
        _loading = false;
      });
    }
  }

  bool get _onDuty => _me['on_duty'] != false;

  Future<void> _setDuty(bool value) async {
    setState(() => _dutyBusy = true);
    try {
      final response = await _api.setMyDuty(value);
      if (!mounted) return;
      setState(() => _me = Map<String, dynamic>.from(response['personnel'] as Map? ?? _me));
      _snack(value ? 'Görev için aktifsiniz; yeni görev alabilirsiniz' : 'Görev için pasifsiniz; yeni görev atanmayacak');
    } catch (e) {
      _snack('Görev durumu değiştirilemedi: ${e is ApiException ? e.message : e}', error: true);
    } finally {
      if (mounted) setState(() => _dutyBusy = false);
    }
  }

  Future<void> _step(Map<String, dynamic> task, String action) async {
    final id = task['id']?.toString() ?? '';
    if (_busyTasks.contains(id)) return;
    setState(() => _busyTasks.add(id));
    try {
      await _api.updateMyTask(id, action);
      await _load();
      if (action == 'start') _openReport(task);
    } catch (e) {
      _snack('İşlem başarısız: ${e is ApiException ? e.message : e}', error: true);
    } finally {
      if (mounted) setState(() => _busyTasks.remove(id));
    }
  }

  void _openReport(Map<String, dynamic> task) {
    final vehicle = Map<String, dynamic>.from(task['vehicle'] as Map? ?? const {});
    final customer = Map<String, dynamic>.from(task['customer'] as Map? ?? const {});
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => ExpertizProvider(),
            child: ExpertizSihirbazi(
              gorevId: task['id']?.toString() ?? '',
              musteriAdi: customer['name']?.toString() ?? '',
              aracPlaka: vehicle['plate']?.toString() ?? '',
            ),
          ),
        ))
        .then((_) => _load());
  }

  Future<void> _openNotifications() async {
    if (_unread > 0) {
      setState(() => _unread = 0);
      try {
        await _api.markNotificationsRead();
      } catch (_) {
        // bir sonraki yenilemede düzelir
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FuturisticTheme.bgSecondary,
      builder: (_) => _NotificationList(items: _notifications),
    );
    _load();
  }

  Future<void> _logout() async {
    final userProvider = context.read<UserProvider>();
    await userProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  List<Map<String, dynamic>> _bucket(String name) =>
      _tasks.where((t) => (t['personnel_bucket'] ?? 'active') == name).toList();

  @override
  Widget build(BuildContext context) {
    final active = _bucket('active');
    final pending = _bucket('pending');
    final rejected = _bucket('rejected');
    final approved = _bucket('approved');

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: FuturisticTheme.bgPrimary,
        appBar: AppBar(
          title: const Text('Personel Paneli'),
          actions: [
            IconButton(
              key: const Key('notificationsButton'),
              tooltip: 'Bildirimler',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text(_unread > 9 ? '9+' : '$_unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
            IconButton(tooltip: 'Yenile', onPressed: _load, icon: const Icon(Icons.refresh)),
            IconButton(tooltip: 'Çıkış', onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: FuturisticTheme.neon,
            indicatorColor: FuturisticTheme.neon,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Aktif (${active.length})'),
              Tab(text: 'Beklemede (${pending.length})'),
              Tab(text: 'Reddedildi (${rejected.length})'),
              Tab(text: 'Tamamlanan (${approved.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_error != null) _errorBanner(),
                  _dutyCard(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _list(active, 'Aktif göreviniz yok', _onDuty ? 'Admin size görev atadığında burada görünür.' : 'Görev için pasifsiniz; yeni görev atanmaz.'),
                        _list(pending, 'Admin kontrolünde rapor yok', 'Gönderdiğiniz raporlar onaylanana kadar burada bekler.'),
                        _list(rejected, 'Reddedilen rapor yok', 'Admin hata bulursa rapor nedeniyle buraya döner.'),
                        _list(approved, 'Tamamlanan görev yok', 'Admin onaylayıp müşteriye gönderdiği raporlar.'),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      color: Colors.red.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white70))),
          TextButton(onPressed: _load, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  Widget _dutyCard() {
    final name = _me['full_name']?.toString() ?? '';
    final place = [_me['city'], _me['district']].where((e) => (e?.toString() ?? '').isNotEmpty).join(' / ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GlassCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (_onDuty ? Colors.green : Colors.grey).withValues(alpha: 0.25),
              child: Icon(_onDuty ? Icons.work : Icons.work_off, color: _onDuty ? Colors.greenAccent : Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Personel' : name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (place.isNotEmpty) Text(place, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    _onDuty ? 'Görev için AKTİF — yeni görev alabilirsiniz' : 'Görev için PASİF — yeni görev atanmaz',
                    style: TextStyle(color: _onDuty ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_dutyBusy)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Switch(key: const Key('dutySwitch'), value: _onDuty, onChanged: _setDuty),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> tasks, String emptyTitle, String emptyHint) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.assignment_outlined, size: 56, color: Colors.white24),
            const SizedBox(height: 12),
            Center(child: Text(emptyTitle, style: const TextStyle(color: Colors.white70))),
            const SizedBox(height: 4),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(emptyHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _taskCard(tasks[i]),
      ),
    );
  }

  static String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? '' : DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final id = task['id']?.toString() ?? '';
    final vehicle = Map<String, dynamic>.from(task['vehicle'] as Map? ?? const {});
    final customer = Map<String, dynamic>.from(task['customer'] as Map? ?? const {});
    final assignment = Map<String, dynamic>.from(task['assignment'] as Map? ?? const {});
    final bucket = task['personnel_bucket']?.toString() ?? 'active';
    final stage = assignment['status']?.toString() ?? 'assigned';
    final actions = (task['next_actions'] as List? ?? const []).map((e) => e.toString()).toList();
    final busy = _busyTasks.contains(id);
    final place = [task['city'], task['district']].where((e) => (e?.toString() ?? '').isNotEmpty).join(' / ');

    final (chipText, chipColor) = switch (bucket) {
      'pending' => ('Admin kontrolünde', Colors.orangeAccent),
      'rejected' => ('Reddedildi — düzeltin', Colors.redAccent),
      'approved' => ('Onaylandı', Colors.greenAccent),
      _ => (_asamaEtiketleri[stage] ?? stage, FuturisticTheme.neon),
    };

    final steps = <(String, dynamic)>[
      ('Atandı', assignment['assigned_at']),
      ('Kabul', assignment['accepted_at']),
      ('Harekete geçti', assignment['departed_at']),
      ('Araç başında', assignment['arrived_at']),
      if (task['corporate_required'] == true) ('Kurumsal ekspertiz', assignment['corporate_at']),
      ('Rapor', assignment['started_at']),
      ('Gönderildi', assignment['submitted_at']),
    ].where((s) => s.$2 != null).toList();

    return GlassCard(
      key: Key('task-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  vehicle['title']?.toString() ?? 'Araç',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.15),
                  border: Border.all(color: chipColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(chipText, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if ((vehicle['plate']?.toString() ?? '').isNotEmpty)
            Text(vehicle['plate'].toString(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          _line(Icons.location_on, place.isEmpty ? 'Konum belirtilmedi' : place),
          _line(Icons.person_outline, [customer['name'], customer['phone']].where((e) => (e?.toString() ?? '').isNotEmpty).join(' • ')),
          if ((task['firm_name']?.toString() ?? '').isNotEmpty)
            _line(Icons.business, '${task['firm_name']} — ${task['package_name'] ?? ''}'),
          if ((task['note']?.toString() ?? '').isNotEmpty) _line(Icons.notes, task['note'].toString()),
          if (bucket == 'rejected' && (task['rejection_reason']?.toString() ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
              ),
              child: Text('Admin notu: ${task['rejection_reason']}', style: const TextStyle(color: Colors.redAccent)),
            ),
          if (bucket == 'pending') _line(Icons.hourglass_top, 'Gönderildi: ${_date(task['submitted_at'])}'),
          if (bucket == 'approved') _line(Icons.verified, 'Onaylandı: ${_date(task['published_at'])}'),
          if (steps.isNotEmpty && bucket != 'approved') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: steps
                  .map((s) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${s.$1} ${_date(s.$2).split(' ').last}', style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
          if (bucket == 'active' || bucket == 'rejected') ...[
            const SizedBox(height: 12),
            if (busy)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    action == actions.first
                        ? FilledButton.icon(
                            key: Key('action-$id-$action'),
                            onPressed: () => _step(task, action),
                            icon: Icon(_adimIkonlari[action]),
                            label: Text(action == 'start' && bucket == 'rejected' ? 'Düzeltmeye Başla' : kGorevAdimEtiketleri[action] ?? action),
                          )
                        : OutlinedButton.icon(
                            key: Key('action-$id-$action'),
                            onPressed: () => _step(task, action),
                            icon: Icon(_adimIkonlari[action]),
                            label: Text(kGorevAdimEtiketleri[action] ?? action),
                          ),
                  if (stage == 'in_progress')
                    FilledButton.icon(
                      key: Key('report-$id'),
                      onPressed: () => _openReport(task),
                      icon: const Icon(Icons.edit_document),
                      label: const Text('Rapora Devam Et'),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12))),
        ],
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: Text('Henüz bildirim yok', style: TextStyle(color: Colors.white60))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
      itemBuilder: (_, i) {
        final n = items[i];
        final kind = n['kind']?.toString() ?? '';
        final color = kind == 'report_rejected'
            ? Colors.redAccent
            : kind == 'report_approved'
                ? Colors.greenAccent
                : FuturisticTheme.neon;
        final created = DateTime.tryParse(n['created_at']?.toString() ?? '');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            kind == 'report_rejected'
                ? Icons.report_problem
                : kind == 'report_approved'
                    ? Icons.verified
                    : Icons.notifications,
            color: color,
          ),
          title: Text(n['title']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            [n['body']?.toString() ?? '', if (created != null) DateFormat('dd.MM HH:mm').format(created.toLocal())]
                .where((e) => e.isNotEmpty)
                .join('\n'),
            style: const TextStyle(color: Colors.white54),
          ),
        );
      },
    );
  }
}

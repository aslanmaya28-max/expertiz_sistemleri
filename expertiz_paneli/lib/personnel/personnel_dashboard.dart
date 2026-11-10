/// PERSONEL PANELİ
///
/// - Görev için aktif / pasif anahtarı (pasif personele yeni görev atanmaz)
/// - Görevler: Aktif, Beklemede (admin kontrolünde), Reddedildi (düzelt ve
///   tekrar gönder), Tamamlanan (admin onayladı, müşteriye gönderildi)
/// - Saha adımları: Kabul et → Harekete geçtim → Araç başındayım →
///   Kurumsal ekspertizdeyim → Rapora başla. Her adım müşteriye ve admine
///   anlık bildirim olarak düşer.
/// - Bildirimler: yeni görev, red (nedeniyle), onay.
/// - Kontrol merkezi (9 Kasım 2026): personel müşteriye/satıcıya doğrudan bağlanmaz; ekranda müşteri/satıcı
///   numarası yoktur. "Kontrol merkezini ara", "Kontrol merkezine not" ve (yolda/araç başında) "Araç adreste yok".
library;

import 'dart:async';
import '../core/widgets/yerimebak_logo.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/widgets/sifre_degistir_dialog.dart';
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
  'accept': LucideIcons.check,
  'depart': LucideIcons.car,
  'arrive': LucideIcons.mapPin,
  'corporate': LucideIcons.building2,
  'start': LucideIcons.filePenLine,
};

const Map<String, String> _asamaEtiketleri = {
  'assigned': 'Personele atandı',
  'accepted': 'Kabul edildi',
  'on_the_way': 'Harekete geçti',
  'at_vehicle': 'Araç başında',
  'at_corporate': 'Kurumsal ekspertizde',
  'in_progress': 'Rapor hazırlanıyor',
  'submitted': 'Rapor gönderildi',
  'vehicle_not_found': 'Araç adreste yok',
};

/// "Araç adreste yok" yalnız bu aşamalarda bildirilebilir (sunucu da aynı kuralı uygular).
const Set<String> kBulunamadiAsamalari = {'on_the_way', 'at_vehicle'};

const List<String> kKontrolNotSecenekleri = [
  'Satıcı telefonu açmıyor',
  'Gecikeceğim',
  'Adreste sorun var'
];

class PersonnelDashboard extends StatefulWidget {
  const PersonnelDashboard({
    super.key,
    this.apiService,
    this.refreshInterval = const Duration(seconds: 20),
    this.baglantiAc,
  });

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;
  final Duration refreshInterval;

  /// tel: ve harita bağlantılarını açar; testlerde yakalanır.
  final Future<bool> Function(Uri uri)? baglantiAc;

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
  Map<String, dynamic> _kontrolMerkezi = const {};
  int _unread = 0;
  int? _lastNotificationId;
  bool _dutyBusy = false;
  bool _passwordDialogOpen = false;
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
      (value as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Future<void> _load({bool initial = false}) async {
    try {
      final results = await Future.wait([
        _api.getPersonnelMe(),
        _api.getMyTasks(),
        _api.getNotifications(limit: 30),
      ]);
      if (!mounted) return;
      final notifications = _rows(results[2]['notifications']);
      final newestId = notifications.isEmpty
          ? null
          : (notifications.first['id'] as num?)?.toInt();
      final hasNew = !initial &&
          newestId != null &&
          _lastNotificationId != null &&
          newestId != _lastNotificationId;
      setState(() {
        _me = Map<String, dynamic>.from(
            results[0]['personnel'] as Map? ?? const {});
        _tasks = _rows(results[1]['tasks']);
        _kontrolMerkezi = Map<String, dynamic>.from(
            results[1]['kontrol_merkezi'] as Map? ?? const {});
        _notifications = notifications;
        _unread = (results[2]['unread'] as num?)?.toInt() ?? 0;
        _lastNotificationId = newestId ?? _lastNotificationId;
        _error = null;
        _loading = false;
      });
      // Admin'in verdigi gecici sifre ile girildiyse once sifre degistirilir
      if (_me['must_change_password'] == true) _changePassword(zorunlu: true);
      if (hasNew) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
              content: Text(
                  notifications.first['title']?.toString() ?? 'Yeni bildirim')),
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
      setState(() => _me =
          Map<String, dynamic>.from(response['personnel'] as Map? ?? _me));
      _snack(value
          ? 'Görev için aktifsiniz; yeni görev alabilirsiniz'
          : 'Görev için pasifsiniz; yeni görev atanmayacak');
    } catch (e) {
      _snack(
          'Görev durumu değiştirilemedi: ${e is ApiException ? e.message : e}',
          error: true);
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
      _snack('İşlem başarısız: ${e is ApiException ? e.message : e}',
          error: true);
    } finally {
      if (mounted) setState(() => _busyTasks.remove(id));
    }
  }

  String get _kontrolTelefonu =>
      (_kontrolMerkezi['telefon'] ?? '').toString().trim();

  Future<void> _ac(Uri uri) async {
    bool acildi;
    try {
      acildi = await (widget.baglantiAc?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      acildi = false;
    }
    if (!acildi) {
      _snack('Bağlantı açılamadı: ${uri.path.isEmpty ? uri : uri.path}',
          error: true);
    }
  }

  Future<void> _kontrolMerkeziniAra() async {
    final tel = _kontrolTelefonu.replaceAll(RegExp(r'[^0-9+]'), '');
    if (tel.isEmpty) return;
    await _ac(Uri(scheme: 'tel', path: tel));
  }

  Future<void> _kontrolNotu(Map<String, dynamic> task) async {
    final not = await showDialog<String>(
        context: context, builder: (_) => const _KontrolNotuDialog());
    if (not == null) return;
    try {
      await _api.sendControlNote(task['id']?.toString() ?? '', not);
      _snack('Not kontrol merkezine iletildi');
    } catch (e) {
      _snack('Not gönderilemedi: ${e is ApiException ? e.message : e}',
          error: true);
    }
  }

  Future<void> _aracYok(Map<String, dynamic> task) async {
    final not = await showDialog<String>(
        context: context, builder: (_) => const _AracYokDialog());
    if (not == null) return;
    final id = task['id']?.toString() ?? '';
    setState(() => _busyTasks.add(id));
    try {
      await _api.reportVehicleNotFound(id, not);
      _snack('Bildirildi. Görev kapandı; karar kontrol merkezinde.');
      await _load();
    } catch (e) {
      _snack('Bildirilemedi: ${e is ApiException ? e.message : e}',
          error: true);
    } finally {
      if (mounted) setState(() => _busyTasks.remove(id));
    }
  }

  void _openReport(Map<String, dynamic> task) {
    final vehicle =
        Map<String, dynamic>.from(task['vehicle'] as Map? ?? const {});
    final customer =
        Map<String, dynamic>.from(task['customer'] as Map? ?? const {});
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
      backgroundColor: context.renkler.yuzey,
      builder: (_) => _NotificationList(items: _notifications),
    );
    _load();
  }

  Future<void> _changePassword({bool zorunlu = false}) async {
    if (_passwordDialogOpen) return;
    _passwordDialogOpen = true;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: !zorunlu,
      builder: (_) => SifreDegistirDialog(api: _api, zorunlu: zorunlu),
    );
    _passwordDialogOpen = false;
    if (changed == true) {
      if (mounted) {
        setState(() => _me = {..._me, 'must_change_password': false});
      }
      _snack('Şifreniz değiştirildi');
    }
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
      SnackBar(
          content: Text(text),
          backgroundColor: error ? context.renkler.tehlike : null),
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
        backgroundColor: context.renkler.zemin,
        appBar: AppBar(
          title: MediaQuery.sizeOf(context).width < 760
              ? const Text('Saha')
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const YerimeBakLogo(height: 28),
                    SizedBox(width: 12),
                    if (MediaQuery.sizeOf(context).width >= 760)
                      Text('Saha paneli'),
                  ],
                ),
          actions: [
            IconButton(
              key: const Key('notificationsButton'),
              tooltip: 'Bildirimler',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: _unread > 0,
                label: Text(_unread > 9 ? '9+' : '$_unread'),
                child: const Icon(LucideIcons.bell),
              ),
            ),
            IconButton(
                tooltip: 'Yenile',
                onPressed: _load,
                icon: const Icon(LucideIcons.refreshCw)),
            IconButton(
              key: const Key('changePasswordButton'),
              tooltip: 'Şifre Değiştir',
              onPressed: () => _changePassword(),
              icon: const Icon(LucideIcons.lockKeyhole),
            ),
            IconButton(
                tooltip: 'Çıkış',
                onPressed: _logout,
                icon: const Icon(LucideIcons.logOut)),
          ],
          bottom: MediaQuery.sizeOf(context).width < 760
              ? null
              : TabBar(
                  isScrollable: true,
                  labelColor: context.renkler.birincil,
                  indicatorColor: context.renkler.birincil,
                  unselectedLabelColor: context.renkler.metinIkincil,
                  tabs: [
                    Tab(text: 'Aktif (${active.length})'),
                    Tab(text: 'Beklemede (${pending.length})'),
                    Tab(text: 'Reddedildi (${rejected.length})'),
                    Tab(text: 'Tamamlanan (${approved.length})'),
                  ],
                ),
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width >= 760
            ? null
            : Builder(
                builder: (context) {
                  final controller = DefaultTabController.of(context);
                  return AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => NavigationBar(
                            height: 72,
                            selectedIndex: controller.index,
                            onDestinationSelected: controller.animateTo,
                            destinations: [
                              NavigationDestination(
                                  icon: const Icon(LucideIcons.clipboardList),
                                  label: 'Aktif (${active.length})'),
                              NavigationDestination(
                                  icon: const Icon(LucideIcons.hourglass),
                                  label: 'Beklemede (${pending.length})'),
                              NavigationDestination(
                                  icon: const Icon(LucideIcons.filePenLine),
                                  label: 'Reddedildi (${rejected.length})'),
                              NavigationDestination(
                                  icon: const Icon(LucideIcons.circleCheck),
                                  label: 'Tamamlanan (${approved.length})'),
                            ],
                          ));
                },
              ),
        body: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  YbIskelet(height: 80),
                  SizedBox(height: 16),
                  YbIskelet(height: 80),
                  SizedBox(height: 16),
                  YbIskelet(height: 80)
                ]))
            : Column(
                children: [
                  if (_error != null) _errorBanner(),
                  _dutyCard(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _list(
                            active,
                            'Aktif göreviniz yok',
                            _onDuty
                                ? 'Yönetim size görev atadığında burada görünür.'
                                : 'Görev için pasifsiniz; yeni görev atanmaz.'),
                        _list(pending, 'Admin kontrolünde rapor yok',
                            'Gönderdiğiniz raporlar onaylanana kadar burada bekler.'),
                        _list(rejected, 'Reddedilen rapor yok',
                            'Admin hata bulursa rapor nedeniyle buraya döner.'),
                        _list(approved, 'Tamamlanan görev yok',
                            'Admin onaylayıp müşteriye gönderdiği raporlar.'),
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
      color: context.renkler.tehlike.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert,
              color: context.renkler.tehlike, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(_error!,
                  style: TextStyle(color: context.renkler.metinIkincil))),
          TextButton(onPressed: _load, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  Widget _dutyCard() {
    final name = _me['full_name']?.toString() ?? '';
    final place = [_me['city'], _me['district']]
        .where((e) => (e?.toString() ?? '').isNotEmpty)
        .join(' / ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: YbKart(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: (_onDuty
                      ? context.renkler.birincilMetin
                      : context.renkler.metinIkincil)
                  .withValues(alpha: 0.25),
              child: Icon(
                  _onDuty
                      ? LucideIcons.briefcaseBusiness
                      : LucideIcons.briefcaseBusiness,
                  color: _onDuty
                      ? context.renkler.birincilMetin
                      : context.renkler.metinIkincil),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Personel' : name,
                      style: TextStyle(
                          color: context.renkler.metin,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  if (place.isNotEmpty)
                    Text(place,
                        style: TextStyle(
                            color: context.renkler.metinIkincil, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    _onDuty
                        ? 'Görev için AKTİF — yeni görev alabilirsiniz'
                        : 'Görev için PASİF — yeni görev atanmaz',
                    style: TextStyle(
                        color: _onDuty
                            ? context.renkler.birincilMetin
                            : context.renkler.uyari,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
            if (_dutyBusy)
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Switch(
                  key: const Key('dutySwitch'),
                  value: _onDuty,
                  onChanged: _setDuty),
          ],
        ),
      ),
    );
  }

  Widget _list(
      List<Map<String, dynamic>> tasks, String emptyTitle, String emptyHint) {
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Icon(LucideIcons.clipboardList,
                size: 56, color: context.renkler.kenarlik),
            const SizedBox(height: 12),
            Center(
                child: Text(emptyTitle,
                    style: TextStyle(color: context.renkler.metinIkincil))),
            const SizedBox(height: 4),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(emptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.renkler.metinIkincil, fontSize: 13)),
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
    return parsed == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  Widget _taskCard(Map<String, dynamic> task) {
    final id = task['id']?.toString() ?? '';
    final vehicle =
        Map<String, dynamic>.from(task['vehicle'] as Map? ?? const {});
    final customer =
        Map<String, dynamic>.from(task['customer'] as Map? ?? const {});
    final assignment =
        Map<String, dynamic>.from(task['assignment'] as Map? ?? const {});
    final bucket = task['personnel_bucket']?.toString() ?? 'active';
    final stage = assignment['status']?.toString() ?? 'assigned';
    final actions = (task['next_actions'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final busy = _busyTasks.contains(id);
    final place = [task['city'], task['district']]
        .where((e) => (e?.toString() ?? '').isNotEmpty)
        .join(' / ');
    final randevu =
        Map<String, dynamic>.from(task['randevu'] as Map? ?? const {});
    final adres = (randevu['adres'] ?? '').toString().trim();
    final saticiAdi = (randevu['satici_adi'] ?? '').toString().trim();
    final acik = bucket == 'active' || bucket == 'rejected';

    final (chipText, chipColor) = switch (bucket) {
      'pending' => ('Admin kontrolünde', context.renkler.uyari),
      'rejected' => ('Reddedildi — düzeltin', context.renkler.tehlike),
      'approved' => ('Onaylandı', context.renkler.birincilMetin),
      _ => (_asamaEtiketleri[stage] ?? stage, context.renkler.birincil),
    };

    final steps = <(String, dynamic)>[
      ('Atandı', assignment['assigned_at']),
      ('Kabul', assignment['accepted_at']),
      ('Harekete geçti', assignment['departed_at']),
      ('Araç başında', assignment['arrived_at']),
      if (task['corporate_required'] == true)
        ('Kurumsal ekspertiz', assignment['corporate_at']),
      ('Rapor', assignment['started_at']),
      ('Gönderildi', assignment['submitted_at']),
    ].where((s) => s.$2 != null).toList();

    return YbKart(
      key: Key('task-$id'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle['title']?.toString() ?? 'Araç',
                style: TextStyle(
                    color: context.renkler.metin,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.15),
                  border: Border.all(color: chipColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(chipText,
                    style: TextStyle(
                        color: chipColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if ((vehicle['plate']?.toString() ?? '').isNotEmpty)
            Text(vehicle['plate'].toString(),
                style: TextStyle(
                    color: context.renkler.metinIkincil,
                    fontWeight: FontWeight.w600)),
          _line(
              LucideIcons.mapPin, place.isEmpty ? 'Konum belirtilmedi' : place),
          // Müşteri/satıcı numarası gösterilmez; bağlantı kontrol merkezi üzerinden.
          _line(LucideIcons.user, customer['name']?.toString() ?? ''),
          if (randevu.isNotEmpty) ...[
            _line(LucideIcons.calendar,
                'Randevu: ${_date(randevu['tarih_saat'])}'),
            if (adres.isNotEmpty)
              Row(
                children: [
                  Expanded(child: _line(LucideIcons.house, adres)),
                  TextButton.icon(
                    key: Key('harita-$id'),
                    onPressed: () =>
                        _ac(Uri.https('www.google.com', '/maps/search/', {
                      'api': '1',
                      'query':
                          [adres, place].where((e) => e.isNotEmpty).join(', '),
                    })),
                    icon: const Icon(LucideIcons.map, size: 16),
                    label: const Text('Harita'),
                  ),
                ],
              ),
            if (saticiAdi.isNotEmpty)
              _line(LucideIcons.store, 'Satıcı: $saticiAdi'),
          ],
          if ((task['firm_name']?.toString() ?? '').isNotEmpty)
            _line(LucideIcons.building2,
                '${task['firm_name']} — ${task['package_name'] ?? ''}'),
          if ((task['note']?.toString() ?? '').isNotEmpty)
            _line(LucideIcons.notebookPen, task['note'].toString()),
          if (bucket == 'rejected' &&
              (task['rejection_reason']?.toString() ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.renkler.tehlike.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.renkler.tehlike.withValues(alpha: 0.6)),
              ),
              child: Text('Admin notu: ${task['rejection_reason']}',
                  style: TextStyle(color: context.renkler.tehlike)),
            ),
          if (bucket == 'pending')
            _line(LucideIcons.hourglass,
                'Gönderildi: ${_date(task['submitted_at'])}'),
          if (bucket == 'approved')
            _line(LucideIcons.badgeCheck,
                'Onaylandı: ${_date(task['published_at'])}'),
          if (steps.isNotEmpty && bucket != 'approved') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: steps
                  .map((s) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${s.$1} ${_date(s.$2).split(' ').last}',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
            ),
          ],
          if (bucket == 'active' || bucket == 'rejected') ...[
            const SizedBox(height: 12),
            if (busy)
              const SizedBox(
                  height: 48,
                  width: 48,
                  child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    action == actions.first
                        ? FilledButton.icon(
                            key: Key('action-$id-$action'),
                            style: const ButtonStyle(
                                minimumSize:
                                    WidgetStatePropertyAll(Size(44, 48)),
                                visualDensity: VisualDensity.standard),
                            onPressed: () => _step(task, action),
                            icon: Icon(_adimIkonlari[action]),
                            label: Text(
                                action == 'start' && bucket == 'rejected'
                                    ? 'Düzeltmeye Başla'
                                    : kGorevAdimEtiketleri[action] ?? action),
                          )
                        : OutlinedButton.icon(
                            key: Key('action-$id-$action'),
                            style: const ButtonStyle(
                                minimumSize:
                                    WidgetStatePropertyAll(Size(44, 48)),
                                visualDensity: VisualDensity.standard),
                            onPressed: () => _step(task, action),
                            icon: Icon(_adimIkonlari[action]),
                            label: Text(kGorevAdimEtiketleri[action] ?? action),
                          ),
                  if (stage == 'in_progress')
                    FilledButton.icon(
                      key: Key('report-$id'),
                      style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size(44, 48)),
                          visualDensity: VisualDensity.standard),
                      onPressed: () => _openReport(task),
                      icon: const Icon(LucideIcons.filePenLine),
                      label: const Text('Rapora Devam Et'),
                    ),
                  if (bucket == 'active' &&
                      kBulunamadiAsamalari.contains(stage))
                    OutlinedButton.icon(
                      key: Key('bulunamadi-$id'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: context.renkler.metinIkincil,
                          minimumSize: const Size(44, 48),
                          visualDensity: VisualDensity.standard),
                      onPressed: () => _aracYok(task),
                      icon: const Icon(LucideIcons.mapPinOff),
                      label: const Text('Araç adreste yok'),
                    ),
                ],
              ),
          ],
          if (acik || stage == 'vehicle_not_found') _kontrolMerkeziSatiri(task),
        ],
      ),
    );
  }

  Widget _kontrolMerkeziSatiri(Map<String, dynamic> task) {
    final id = task['id']?.toString() ?? '';
    final tel = _kontrolTelefonu;
    final saatler =
        (_kontrolMerkezi['calisma_saatleri'] ?? '').toString().trim();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.renkler.birincil.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: context.renkler.birincil.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tel.isEmpty
                ? 'Kontrol merkezi numarası henüz girilmedi'
                : 'Müşteri ve satıcıyla bağlantıyı kontrol merkezi kurar${saatler.isEmpty ? '' : ' • $saatler'}',
            style: TextStyle(
                color: tel.isEmpty
                    ? context.renkler.uyari
                    : context.renkler.metinIkincil,
                fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: Key('kontrol-ara-$id'),
                onPressed: tel.isEmpty ? null : _kontrolMerkeziniAra,
                icon: const Icon(LucideIcons.headset),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 48),
                    visualDensity: VisualDensity.standard),
                label: const Text('Kontrol merkezini ara'),
              ),
              OutlinedButton.icon(
                key: Key('kontrol-not-$id'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 48),
                    visualDensity: VisualDensity.standard),
                onPressed: () => _kontrolNotu(task),
                icon: const Icon(LucideIcons.filePenLine),
                label: const Text('Kontrol merkezine not'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    if (text.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: context.renkler.metinIkincil),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: context.renkler.metinIkincil, fontSize: 13))),
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
      return SizedBox(
        height: 160,
        child: Center(
            child: Text('Henüz bildirim yok',
                style: TextStyle(color: context.renkler.metinIkincil))),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(color: context.renkler.ayirici),
      itemBuilder: (_, i) {
        final n = items[i];
        final kind = n['kind']?.toString() ?? '';
        final color = kind == 'report_rejected'
            ? context.renkler.tehlike
            : kind == 'report_approved'
                ? context.renkler.birincilMetin
                : context.renkler.birincil;
        final created = DateTime.tryParse(n['created_at']?.toString() ?? '');
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            kind == 'report_rejected'
                ? LucideIcons.triangleAlert
                : kind == 'report_approved'
                    ? LucideIcons.badgeCheck
                    : LucideIcons.bell,
            color: color,
          ),
          title: Text(n['title']?.toString() ?? '',
              style: TextStyle(color: context.renkler.metin)),
          subtitle: Text(
            [
              n['body']?.toString() ?? '',
              if (created != null)
                DateFormat('dd.MM HH:mm').format(created.toLocal())
            ].where((e) => e.isNotEmpty).join('\n'),
            style: TextStyle(color: context.renkler.metinIkincil),
          ),
        );
      },
    );
  }
}

/// Kontrol merkezine not: hazır seçenekler + serbest metin. Onaylanırsa notu döner.
class _KontrolNotuDialog extends StatefulWidget {
  const _KontrolNotuDialog();

  @override
  State<_KontrolNotuDialog> createState() => _KontrolNotuDialogState();
}

class _KontrolNotuDialogState extends State<_KontrolNotuDialog> {
  final TextEditingController _not = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kontrol merkezine not'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final secenek in kKontrolNotSecenekleri)
                  ActionChip(
                      label: Text(secenek),
                      onPressed: () => setState(() => _not.text = secenek)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('kontrol-not-metni'),
              controller: _not,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                  labelText: 'Not',
                  border: const OutlineInputBorder(),
                  errorText: _hata),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(44, 48)),
                visualDensity: VisualDensity.standard),
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('kontrol-not-gonder'),
          style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(44, 48)),
              visualDensity: VisualDensity.standard),
          onPressed: () {
            final not = _not.text.trim();
            if (not.length < 3) {
              setState(() => _hata = 'Notu yazın ya da bir seçenek seçin');
              return;
            }
            Navigator.pop(context, not);
          },
          child: const Text('Gönder'),
        ),
      ],
    );
  }
}

/// "Araç adreste yok": not ≥ 10 karakter ve onay. Görev kapanır; karar yönetimdedir.
class _AracYokDialog extends StatefulWidget {
  const _AracYokDialog();

  @override
  State<_AracYokDialog> createState() => _AracYokDialogState();
}

class _AracYokDialogState extends State<_AracYokDialog> {
  final TextEditingController _not = TextEditingController();
  bool _onay = false;
  String? _hata;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Araç adreste yok'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Satıcıyı aradınız mı? Bu işlem görevi kapatır. '
                'Önce kontrol merkezini arayıp satıcıya ulaşılmasını isteyin.'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('bulunamadi-notu'),
              controller: _not,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Ne oldu? (en az 10 karakter)',
                border: const OutlineInputBorder(),
                errorText: _hata,
              ),
            ),
            CheckboxListTile(
              key: const Key('bulunamadi-onay'),
              contentPadding: EdgeInsets.zero,
              value: _onay,
              onChanged: (v) => setState(() => _onay = v ?? false),
              title: const Text(
                  'Kontrol merkezi satıcıya ulaşmayı denedi; araç adreste yok'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(44, 48)),
                visualDensity: VisualDensity.standard),
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          key: const Key('bulunamadi-gonder'),
          style: FilledButton.styleFrom(
              backgroundColor: context.renkler.uyari,
              minimumSize: const Size(44, 48),
              visualDensity: VisualDensity.standard),
          onPressed: !_onay
              ? null
              : () {
                  final not = _not.text.trim();
                  if (not.length < 10) {
                    setState(
                        () => _hata = 'En az 10 karakterle ne olduğunu yazın');
                    return;
                  }
                  Navigator.pop(context, not);
                },
          child: const Text('Bildir ve görevi kapat'),
        ),
      ],
    );
  }
}

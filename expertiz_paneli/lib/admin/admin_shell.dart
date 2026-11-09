import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../core/widgets/sidebar.dart';
import '../core/widgets/sifre_degistir_dialog.dart';
import '../services/yerimebak_expertiz_api_service.dart';
import '../models/dashboard_stats.dart';
import '../tema/renkler.dart';
import 'unauthorized_screen.dart';
import 'widgets/admin_notification_bell.dart';
import 'modules/dashboard_module.dart';
import 'modules/arac_operasyonu.dart';
import '../screens/personel/personel_bolge_sistemi.dart';
import 'modules/musteri_yonetimi_module.dart';
import 'modules/rapor_inceleme_module.dart';
import 'modules/fiyatlandirma_module.dart';
import 'modules/finans_yonetimi.dart';
import 'modules/ayarlar_module.dart';
import 'modules/piyasa_takibi_module.dart';
import 'modules/kontrol_merkezi_module.dart';

/// Yetki denetimi, modül gezinmesi ve sunucu kaynaklı menü rozetleri.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selected = 0;
  String? _filter;
  Map<int, int> _badges = {};
  final _api = YerimebakExpertizApiService();
  bool _badgesStarted = false;
  Future<void> _loadBadges() async {
    try {
      final data = await _api.getAdminDashboard();
      final ozet = DashboardOzet.fromResponse(data);
      if (mounted) {
        setState(() => _badges = {
              2: ozet?.ekspertiz['waiting_assignment']?.toInt() ?? 0,
              6: ozet?.krediSatisi['bekleyen_havale']?.toInt() ?? 0
            });
      }
      final control = await _api.getControlCenterTasks();
      final now = DateTime.now().toUtc().add(const Duration(hours: 3));
      final wall = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      const departed = {
        'on_the_way',
        'at_vehicle',
        'at_corporate',
        'in_progress',
        'submitted'
      };
      final urgent =
          (control['gorevler'] as List? ?? []).whereType<Map>().where((row) {
        final slot = row['randevu'];
        final date =
            slot is Map ? DateTime.tryParse('${slot['tarih_saat']}') : null;
        return date != null &&
            !departed.contains(row['stage']) &&
            date.difference(wall).inMinutes < 60;
      }).length;
      if (mounted) setState(() => _badges = {..._badges, 1: urgent});
    } catch (_) {/* Rozet hatası modül kullanımını engellemez. */}
  }

  void _open(int index, [String? filter]) => setState(() {
        _selected = index;
        _filter = filter;
      });
  void _navigate(String page, String? filter) {
    const indices = {
      'musteriler': 4,
      'raporlar': 5,
      'finans': 6,
      'talepler': 2,
      'kontrol': 1
    };
    _open(indices[page] ?? 0, filter);
  }

  Widget _page(UserProvider user) => switch (_selected) {
        0 => DashboardModule(
            displayName: user.currentUser?.fullName,
            email: user.currentUser?.email,
            onNavigate: _navigate,
            onUpdated: _loadBadges),
        1 => const KontrolMerkeziModule(),
        2 => AracOperasyonu(
            key: ValueKey('talepler:$_filter'),
            initialBucket:
                _filter == 'arac_bulunamadi' ? 'in_progress' : _filter,
            refundOnly: _filter == 'arac_bulunamadi'),
        3 => const PersonelBolgePaneli(),
        4 => const MusteriYonetimiModule(),
        5 => const RaporIncelemeModule(),
        6 => FinansYonetimi(key: ValueKey('finans:$_filter'), initialFilter: _filter),
        7 => const FiyatlandirmaModule(),
        8 => const AyarlarModule(),
        _ => const PiyasaTakibiModule(),
      };
  @override
  Widget build(BuildContext context) =>
      Consumer<UserProvider>(builder: (context, user, _) {
        if (!user.isAuthenticated || !user.isAdmin) {
          return const UnauthorizedScreen();
        }
        if (!_badgesStarted) {
          _badgesStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadBadges());
        }
        final name = user.currentUser?.fullName.trim() ?? '';
        final label = name.isNotEmpty
            ? name
            : (user.currentUser?.email.split('@').first ?? 'Yönetici');
        final dark = Theme.of(context).brightness == Brightness.dark;
        return PanelYerlesim(
            secili: _selected,
            onSelect: (i) => _open(i),
            sayilar: _badges,
            actions: [
              IconButton(
                  tooltip: dark ? 'Açık temaya geç' : 'Koyu temaya geç',
                  icon: Icon(dark ? LucideIcons.sun : LucideIcons.moon),
                  onPressed: () => context.read<ThemeProvider>().toggleTheme()),
              AdminNotificationBell(
                  color: context.renkler.metinIkincil,
                  onOpenReport: (_) => _open(2)),
              PopupMenuButton<String>(
                  tooltip: 'Kullanıcı menüsü',
                  onSelected: (action) async {
                    if (action == 'password') {
                      await showDialog<void>(
                          context: context,
                          builder: (_) => SifreDegistirDialog(api: _api));
                    } else {
                      await user.logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'password', child: Text('Şifre değiştir')),
                        PopupMenuItem(value: 'logout', child: Text('Çıkış'))
                      ],
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(
                            radius: 16,
                            backgroundColor: context.renkler.birincilYuzey,
                            child: Text(label.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                    color: context.renkler.birincilMetin,
                                    fontSize: 12))),
                        if (MediaQuery.sizeOf(context).width >= 1100) ...[
                          const SizedBox(width: 8),
                          Text(label, style: const TextStyle(fontSize: 13))
                        ],
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.chevronDown, size: 14)
                      ]))),
            ],
            child: _page(user));
      });
}

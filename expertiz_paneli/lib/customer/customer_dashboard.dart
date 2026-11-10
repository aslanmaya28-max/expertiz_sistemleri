import 'dart:async';
import '../core/widgets/yerimebak_logo.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import '../services/yerimebak_expertiz_api_service.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/screens/login_screen.dart';
import '../../core/layout/base_scaffold.dart';
import 'create_request_screen.dart';
import '../../screens/musteri/oto_analiz_merkezi.dart';
import 'profile_edit_screen.dart';
import 'analysis_history_screen.dart';
import '../../core/constants/roles.dart';
import '../../providers/user_provider.dart';
import '../../models/report_status.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _subscribeToReports();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  final YerimebakExpertizApiService _api = YerimebakExpertizApiService();

  /// Talepler ve canlı durumları merkezi API'den gelir (önceden Supabase).
  Future<void> _loadDashboardData() async {
    try {
      final response = await _api.getMyRequests();
      final rows = (response['requests'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _dashboardData = {
          'total_reports': rows.length,
          'published_reports': rows
              .where((r) => r['status'] == ReportStatus.published.value)
              .length,
          'recent_transactions': rows.take(10).map((r) {
            final progress =
                r['progress'] is Map ? r['progress'] as Map : const {};
            return {
              'plaka': r['plate'],
              'firma': r['firm_name'],
              'durum': _durumMetni(
                  r['status']?.toString(), progress['label']?.toString()),
            };
          }).toList(),
        };
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  static String _durumMetni(String? status, String? canliDurum) {
    switch (status) {
      case 'published':
        return 'Tamamlandı';
      case 'cancelled':
        return 'İptal Edildi';
      case 'payment_pending':
        return 'Ödeme bekliyor';
      case 'payment_failed':
        return 'Ödeme başarısız';
      case 'pending_ai':
      case 'pending_admin':
      case 'rejected':
        return 'Rapor kontrol ediliyor';
      default:
        return canliDurum ?? 'İşlemde';
    }
  }

  /// Canlı durum: 30 sn'de bir yenilenir.
  void _subscribeToReports() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadDashboardData();
      _loadNotificationCount();
    });
  }

  Future<void> _loadNotificationCount() async {
    try {
      final response = await _api.getNotifications(limit: 1);
      if (mounted) {
        setState(() =>
            _unreadNotifications = (response['unread'] as num?)?.toInt() ?? 0);
      }
    } catch (e) {
      debugPrint('Bildirim sayısı alınamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.currentUser?.fullName ?? 'Müşteri';

    return BaseScaffold(
      role: UserRole.customer,
      appBar: AppBar(
        title: MediaQuery.sizeOf(context).width < 600
            ? const Text('Müşteri Paneli')
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  YerimeBakLogo(height: 32, onDark: true),
                  SizedBox(width: 12),
                  Text('Müşteri Paneli'),
                ],
              ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // FAZ-3.0: Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.bell),
                onPressed: () {
                  // TODO: Navigate to notifications screen
                },
              ),
              if (_unreadNotifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.renkler.tehlike,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: TextStyle(
                        color: context.renkler.metin,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YbKart(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              context.renkler.birincil.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(LucideIcons.user,
                            size: 25, color: context.renkler.birincil),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Merhaba, $userName',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: context.renkler.metin,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Araç ekspertiz işlemlerinizi buradan yönetebilirsiniz.',
                              style: TextStyle(
                                color: context.renkler.metinIkincil,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtoAnalizMerkezi()),
                );
              },
              child: YbKart(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: context.renkler.birincil,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(LucideIcons.sparkles,
                          color: context.renkler.birincil, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Oto-Analiz',
                            style: TextStyle(
                              color: context.renkler.metin,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Yapay zeka destekli araç değerleme',
                            style: TextStyle(
                              color: context.renkler.metinIkincil,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.renkler.birincil.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.chevronRight,
                          color: context.renkler.birincil, size: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateRequestScreen()),
                );
              },
              child: YbKart(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: context.renkler.birincil,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(LucideIcons.circlePlus,
                          color: context.renkler.birincil, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yeni Ekspertiz Talebi',
                            style: TextStyle(
                              color: context.renkler.metin,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hemen bir araç için randevu oluşturun',
                            style: TextStyle(
                              color: context.renkler.metinIkincil,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.renkler.birincil.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(LucideIcons.chevronRight,
                          color: context.renkler.birincil, size: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // FAZ-3.0: YAYINLANAN RAPORLARIM BÖLÜMÜ
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Yayınlanan Raporlarım',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.metin,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.renkler.birincil.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.renkler.birincil),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.badgeCheck,
                          color: context.renkler.birincil, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Sadece Onaylı',
                        style: TextStyle(
                          color: context.renkler.birincil,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real data or loading/error state
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(LucideIcons.circleAlert,
                          size: 48,
                          color:
                              context.renkler.tehlike.withValues(alpha: 0.7)),
                      const SizedBox(height: 16),
                      Text('Veri yüklenemedi: $_error',
                          style:
                              TextStyle(color: context.renkler.metinIkincil)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_dashboardData != null &&
                _dashboardData!['recent_transactions'] != null)
              for (var tx in (_dashboardData!['recent_transactions'] as List))
                _buildIslemCard(
                  tx['plaka']?.toString() ?? '---',
                  tx['firma']?.toString() ?? '---',
                  tx['durum']?.toString() ?? '---',
                  _getStatusColor(tx['durum']?.toString()),
                )
            else
              Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(LucideIcons.history,
                          size: 64, color: context.renkler.kenarlik),
                      SizedBox(height: 16),
                      Text('Henüz ekspertiz talebiniz yok',
                          style:
                              TextStyle(color: context.renkler.metinIkincil)),
                      SizedBox(height: 8),
                      Text(
                        'Raporlarınız inceleme ve onaylandıktan sonra burada görünecektir',
                        style: TextStyle(
                            color: context.renkler.metinIkincil, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),

            YbKart(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı İşlemler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.renkler.metin,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceAround,
                    spacing: 20,
                    runSpacing: 16,
                    children: [
                      _buildQuickAction(
                        LucideIcons.history,
                        'Raporlarım',
                        context.renkler.birincil,
                        () {
                          // Rapor listesine yönlendir
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AnalysisHistoryScreen()),
                          );
                        },
                      ),
                      _buildQuickAction(
                        LucideIcons.messageSquare,
                        'Mesajlar',
                        context.renkler.bilgi,
                        () {
                          // TODO: Bildirimler sayfasına yönlendir
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Mesajlar sayfası yakında gelecek')),
                          );
                        },
                      ),
                      _buildQuickAction(
                        LucideIcons.settings,
                        'Ayarlar',
                        context.renkler.metinIkincil,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileEditScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: YbButon(
                metin: 'Çıkış Yap',
                onPressed: () async {
                  await context.read<UserProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIslemCard(String plaka, String detay, String durum, Color renk) {
    return YbKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.wrench, color: renk, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plaka,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: context.renkler.metin,
                      ),
                    ),
                    Text(
                      detay,
                      style: TextStyle(
                        color: context.renkler.metinIkincil,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: renk),
            ),
            child: Text(
              durum,
              style: TextStyle(
                color: renk,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    // FAZ-3.0: Customer only sees published reports
    return context.renkler.birincil;
  }
}

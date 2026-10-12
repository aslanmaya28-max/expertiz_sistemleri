import 'dart:async';
import '../core/widgets/yerimebak_logo.dart';
import 'package:flutter/material.dart';
import '../services/yerimebak_expertiz_api_service.dart';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/screens/login_screen.dart';
import '../../core/theme/futuristic_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/layout/base_scaffold.dart';
import 'create_request_screen.dart';
import 'external_report_entry.dart';
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
          'published_reports': rows.where((r) => r['status'] == ReportStatus.published.value).length,
          'recent_transactions': rows.take(10).map((r) {
            final progress = r['progress'] is Map ? r['progress'] as Map : const {};
            return {
              'plaka': r['plate'],
              'firma': r['firm_name'],
              'durum': _durumMetni(r['status']?.toString(), progress['label']?.toString()),
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
      if (mounted) setState(() => _unreadNotifications = (response['unread'] as num?)?.toInt() ?? 0);
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
        title: const Row(
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
                icon: const Icon(Icons.notifications),
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
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
            // HOŞ GELDİNİZ BÖLÜMÜ - Premium GlassCard
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: FuturisticTheme.neon.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Icon(Icons.person, size: 25, color: FuturisticTheme.neon),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba, $userName',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Araç ekspertiz işlemlerinizi buradan yönetebilirsiniz.',
                              style: TextStyle(
                                color: Colors.white54,
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
            
            // AI OTO-ANALİZ KARTI - Premium GlassCard
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OtoAnalizMerkezi()),
                );
              },
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FuturisticTheme.neon.withValues(alpha: 0.3),
                            FuturisticTheme.neon.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.auto_awesome, color: FuturisticTheme.neon, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Oto-Analiz',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Yapay zeka destekli araç değerleme',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FuturisticTheme.neon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon, size: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // RAPOR YÜKLEME KARTI - Premium GlassCard
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExternalReportEntry()),
                );
              },
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FuturisticTheme.neon.withValues(alpha: 0.3),
                            Colors.purple.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.cloud_upload, color: FuturisticTheme.neon, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rapor Yükle',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Dışarıdan aldığınız raporu sisteme yükleyin',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FuturisticTheme.neon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon, size: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // YENİ EKSPERTİZ TALEBİ KARTI - Premium GlassCard
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
                );
              },
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withValues(alpha: 0.3),
                            Colors.orange.withValues(alpha: 0.3),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Yeni Ekspertiz Talebi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Hemen bir araç için randevu oluşturun',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // FAZ-3.0: YAYINLANAN RAPORLARIM BÖLÜMÜ
            Row(
              children: [
                const Text(
                  'Yayınlanan Raporlarım',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FuturisticTheme.neon),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: FuturisticTheme.neon, size: 16),
                      const SizedBox(width: 4),
                      const Text(
                        'Sadece Onaylı',
                        style: TextStyle(
                          color: FuturisticTheme.neon,
                          fontSize: 12,
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
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.7)),
                      const SizedBox(height: 16),
                      Text('Veri yüklenemedi: $_error', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_dashboardData != null && _dashboardData!['recent_transactions'] != null)
              for (var tx in (_dashboardData!['recent_transactions'] as List))
                _buildIslemCard(
                  tx['plaka']?.toString() ?? '---',
                  tx['firma']?.toString() ?? '---',
                  tx['durum']?.toString() ?? '---',
                  _getStatusColor(tx['durum']?.toString()),
                )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('Henüz ekspertiz talebiniz yok', style: TextStyle(color: Colors.white54)),
                      SizedBox(height: 8),
                      Text(
                        'Raporlarınız inceleme ve onaylandıktan sonra burada görünecektir',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // HIZLI İŞLEMLER - GlassCard ile
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hızlı İşlemler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickAction(
                        Icons.history,
                        'Raporlarım',
                        Colors.blue,
                        () {
                          // Rapor listesine yönlendir
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AnalysisHistoryScreen()),
                          );
                        },
                      ),
                      _buildQuickAction(
                        Icons.message,
                        'Mesajlar',
                        Colors.purple,
                        () {
                          // TODO: Bildirimler sayfasına yönlendir
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mesajlar sayfası yakında gelecek')),
                          );
                        },
                      ),
                      _buildQuickAction(
                        Icons.settings,
                        'Ayarlar',
                        Colors.grey,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                          );
                        },
                      ),

                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ÇIKIŞ YAP BUTONU - NeonButton
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'Çıkış Yap',
                onTap: () async {
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
    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.car_repair, color: renk, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plaka,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                Text(
                  detay,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
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
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    // FAZ-3.0: Customer only sees published reports
    // All reports in customer dashboard are published (green/neon)
    return FuturisticTheme.neon;
  }
}

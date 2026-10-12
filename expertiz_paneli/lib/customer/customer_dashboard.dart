import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../../services/notification_service.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _reportsSubscription;
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
    _reportsSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadDashboardData() async {
    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.userId;
      
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Oturum açılmadı';
        });
        return;
      }

      // FAZ-3.0: Customer ONLY sees their own published reports
      // 🔒 GÜVENLİK: user_id filtresi ile kendi raporlarini gorebilir
      final response = await Supabase.instance.client
          .from('reports')
          .select('id, plaka, firma, status, created_at, status_updated_at')
          .eq('status', ReportStatus.published.value) // 🔒 Published ONLY
          .eq('user_id', userId) // 🔒 GÜVENLİK: Sadece kendi raporlari
          .order('status_updated_at', ascending: false)
          .limit(10);
      
      final reports = response as List<dynamic>;

      setState(() {
        _dashboardData = {
          'total_reports': reports.length,
          'published_reports': reports.length,
          'recent_transactions': reports.cast<Map<String, dynamic>>(),
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// FAZ-3.0: Subscribe to published reports in real-time
  void _subscribeToReports() {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    
    if (userId == null) return;

    try {
      // 🔒 DÜZELTİLDİ (B10): user_id filtresi eklendi — her müşteri sadece kendi raporlarını görür.
      // KVKK/GDPR uyumu: Müşteriler diğer müşterilerin raporlarını göremez.
      final stream = Supabase.instance.client
          .from('reports')
          .stream(primaryKey: ['id'])
          // Supabase realtime akışı tek filtre destekler: güvenlik filtresi
          // (user_id) sunucuda, yayın durumu filtresi istemcide uygulanır.
          .eq('user_id', userId) // 🔒 Kendi raporlarına filtrele
          .order('status_updated_at', ascending: false);


      _reportsSubscription = stream.listen((rows) {
        final event = rows
            .where((r) => r['status'] == ReportStatus.published.value)
            .toList();
        if (mounted) {
          setState(() {
            _dashboardData = {
              'total_reports': event.length,
              'published_reports': event.length,
              'recent_transactions': event.cast<Map<String, dynamic>>(),
            };
          });
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to subscribe to reports: $e');
    }
  }

  /// Load notification count
  Future<void> _loadNotificationCount() async {
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    
    if (userId == null) return;

    try {
      final notificationService = NotificationService(Supabase.instance.client);
      notificationService.init(userId);
      
      final count = await notificationService.getUnreadCount();
      if (mounted) {
        setState(() => _unreadNotifications = count);
      }
    } catch (e) {
      debugPrint('❌ Failed to load notification count: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.currentUser?.fullName ?? 'Müşteri';

    return BaseScaffold(
      role: UserRole.customer,
      appBar: AppBar(
        title: const Text('Müşteri Paneli'),
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
                      Text('Henüz yayınlanmış rapor yok', style: TextStyle(color: Colors.white54)),
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

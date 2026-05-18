import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "package:yerimebak_sistemleri/providers/user_provider.dart";
import "package:yerimebak_sistemleri/models/user_model.dart";
import "package:yerimebak_sistemleri/screens/login_screen.dart";
import "../../core/theme/futuristic_theme.dart";
import "../../core/widgets/glass_card.dart";
import "../../core/widgets/neon_button.dart";
import "../../core/layout/base_scaffold.dart";
import "../../providers/expertiz_provider.dart";
import "../../providers/admin_provider.dart";
import "../../models/talep_model.dart";
import "../../screens/expertiz_akisi/expertiz_baslat_sayfasi.dart";

// ANA PERSONEL PANEL SINIFI
// PersonnelPanel - Personelin kendi dashboard'u
class PersonnelPanel extends StatefulWidget {
  const PersonnelPanel({super.key});

  @override
  State<PersonnelPanel> createState() => _PersonnelPanelState();
}

class _PersonnelPanelState extends State<PersonnelPanel> {
  final int _currentIndex = 0;
  UserModel? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _initDemoData(); // Demo verileri yükle
  }
  
  Future<void> _loadCurrentUser() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.currentUser;
    if (mounted) {
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        context.read<AdminProvider>().loadTalepler();
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  /// Demo amaçlı test talepleri oluşturur
  Future<void> _initDemoData() async {
    try {
      final adminProvider = context.read<AdminProvider>();
      await Future.delayed(const Duration(milliseconds: 500)); // UI render bekle
      
      // Demo talep oluştur (Eğer hiç talep yoksa)
      if (adminProvider.talepler.isEmpty && _currentUser != null && _currentUser!.role == UserRole.fieldStaff) {
        final demoTalep = TalepModel(
          id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
          musteriAdi: 'Demo Müşteri',
          musteriId: 'demo_customer_001',
          telefon: '+905551234567',
          aracPlaka: '34ABC123',
          aracMarka: 'BMW',
          aracModel: '320i',
          durum: 'Onaylandı',
          olusturulma: DateTime.now().subtract(const Duration(hours: 2)),
          atananPersonel: _currentUser!.id, // Bu personel'e atandı
          aciklama: 'Demo amaçlı test talebi - Araç ekspertiz isteği',
          sehir: 'İstanbul',
          expertizFirmasi: 'YerimeBak',
          expertizPaketi: 'Basic',
          paketFiyati: 0.0,
          motorNo: '123456',
          hizmetBedeli: 6500.0,
          toplamTutar: 7800.0,
          hasarTutar: 0.0,
          isPaid: false,
          aiAnaliziYapildiMi: false,
        );
        
        await adminProvider.yeniTalepOlustur(demoTalep);
        debugPrint('✅ Demo talep oluşturuldu: ${demoTalep.id}');
      }
    } catch (e) {
      debugPrint('❌ Demo veri oluşturma hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      _buildDashboard(),
      _buildGorevler(),
      _buildProfil(),
    ];

    return BaseScaffold(
      role: UserRole.fieldStaff,
      body: pages[_currentIndex],
    );
  }

  List<TalepModel> _getPersonelTalepleri(List<TalepModel> tumTalepler) {
    if (_currentUser == null) return [];
    return tumTalepler.where((t) => 
      t.atananPersonel == _currentUser!.id || 
      t.atananPersonel == _currentUser!.fullName
    ).toList();
  }

  // ========== DASHBOARD ==========
  Widget _buildDashboard() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final myTasks = _getPersonelTalepleri(adminProvider.talepler);
        final assignedTasks = myTasks.where((t) => t.durum != 'Raporlandı' && t.durum != 'Tamamlandı').toList();
        final completedTasks = myTasks.where((t) => t.durum == 'Raporlandı' || t.durum == 'Tamamlandı').toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hoş Geldiniz Kartı - GlassCard ile
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: FuturisticTheme.neon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.person, size: 30, color: FuturisticTheme.neon),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hoş Geldiniz, ${_currentUser!.fullName}!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${_currentUser!.id}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                          ),
                          Text(
                            DateFormat('dd.MM.yyyy').format(DateTime.now()),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // İstatistikler - GlassCard ile
              Row(
                children: [
                  Expanded(
                    child: _buildGlassStatCard('Atanan', assignedTasks.length.toString(), Icons.assignment, Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassStatCard('Tamamlanan', completedTasks.length.toString(), Icons.check_circle, Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGlassStatCard('Toplam', '${myTasks.length}', Icons.work, Colors.blue),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Bugünün Görevleri
              if (assignedTasks.isNotEmpty) ...[
                const Text(
                  "📋 Atanan Görevler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  "(${assignedTasks.length} adet)",
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 12),
                ...assignedTasks.map((gorev) => _buildGorevCard(gorev)),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: Colors.white.withValues(alpha: 0.24)),
                        const SizedBox(height: 16),
                        Text('Atanan aktif görev bulunmuyor', style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.70))),
        ],
      ),
    );
  }

  // ========== GÖREVLER SAYFASI ==========
  Widget _buildGorevler() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final myTasks = _getPersonelTalepleri(adminProvider.talepler);
        final assignedTasks = myTasks.where((t) => t.durum != 'Raporlandı' && t.durum != 'Tamamlandı').toList();
        final completedTasks = myTasks.where((t) => t.durum == 'Raporlandı' || t.durum == 'Tamamlandı').toList();

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: FuturisticTheme.bgSecondary,
                child: TabBar(
                  labelColor: FuturisticTheme.neon,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.54),
                  indicatorColor: FuturisticTheme.neon,
                  tabs: [
                    Tab(text: 'Aktif (${assignedTasks.length})'),
                    Tab(text: 'Geçmiş (${completedTasks.length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGorevListesi(assignedTasks, false),
                    _buildGorevListesi(completedTasks, true),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildGorevListesi(List<TalepModel> gorevler, bool tamamlandi) {
    if (gorevler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tamamlandi ? Icons.check_circle_outline : Icons.assignment_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.24),
            ),
            const SizedBox(height: 16),
            Text(
              tamamlandi ? 'Tamamlanan görev bulunmuyor' : 'Aktif görev bulunmuyor',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: gorevler.length,
      itemBuilder: (context, index) => _buildGorevCard(gorevler[index]),
    );
  }

  Widget _buildGorevCard(TalepModel gorev) {
    void navigateToWorkflow() {
      final BuildContext dialogContext = context;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ExpertizProvider(),
            child: ExpertizBaslatSayfasi(
              gorevId: gorev.id,
              personelId: _currentUser!.id,
              personelAdi: _currentUser!.fullName,
              musteriAdi: gorev.musteriAdi,
              aracPlakasi: gorev.aracPlaka,
            ),
          ),
        ),
      ).then((_) {
        if (mounted && dialogContext.mounted) {
          dialogContext.read<AdminProvider>().loadTalepler();
        }
      });
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${gorev.aracMarka} ${gorev.aracModel}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDurumColor(gorev.durum).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getDurumColor(gorev.durum)),
                ),
                child: Text(
                  gorev.durum,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getDurumColor(gorev.durum),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gorev.aracPlaka,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            gorev.aciklama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  gorev.sehir.isNotEmpty ? gorev.sehir : "İstanbul",
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.54)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_month, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd.MM.yyyy HH:mm').format(gorev.olusturulma),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.54)),
              ),
            ],
          ),
          
          // Aksiyon Butonları
          if (gorev.durum != 'Raporlandı' && gorev.durum != 'Tamamlandı') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'GÖREVİ BAŞLAT',
                onTap: navigateToWorkflow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getDurumColor(String durum) {
    switch (durum) {
      case 'Onaylandı':
        return Colors.orange;
      case 'Raporlandı':
      case 'Tamamlandı':
        return Colors.green;
      case 'Beklemede':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ========== PROFİL SAYFASI ==========
  Widget _buildProfil() {
    // Mock personel data - Gerçek uygulamada veritabanından gelecek
    final personelData = {
      'id': _currentUser!.id,
      'adSoyad': _currentUser!.fullName,
      'email': _currentUser!.email,
      'rol': _currentUser!.role.displayName,
      'aktif': true, // Online/Offline status
      'musait': true, // Görevde olup olmadığı
      'uzmanlikAlani': 'Mekanik', // Mekanik, Kaporta, AI Analiz
      'performansSkoru': 87.5, // 0-100 arası
      'aktifGorevSayisi': 3, // Şu an aktif görev sayısı
      'il': 'İstanbul',
      'ilce': 'Merkez',
    };
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Dijital Kimlik Kartı - Siber Temalı
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FuturisticTheme.bgSecondary,
                  FuturisticTheme.bgPrimary,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: FuturisticTheme.neon.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // Header: Avatar + Status
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              FuturisticTheme.neon.withValues(alpha: 0.3),
                              FuturisticTheme.neon.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: FuturisticTheme.neon.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(Icons.person, size: 40, color: FuturisticTheme.neon),
                      ),
                      const SizedBox(width: 20),
                      // Name + Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personelData['adSoyad']?.toString() ?? '---',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Online/Offline Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (personelData['aktif'] as bool? ?? false) ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (personelData['aktif'] as bool? ?? false) ? 'Online' : 'Offline',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Müsait/Meşgul Status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (personelData['musait'] as bool? ?? false) ? Colors.blue.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (personelData['musait'] as bool? ?? false) ? Icons.check_circle : Icons.work,
                                        size: 12,
                                        color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        (personelData['musait'] as bool? ?? false) ? 'Müsait' : 'Meşgul',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
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
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                ),
                
                // Stats Grid
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Performans Skoru
                      _buildStatRow(
                        Icons.trending_up,
                        'Performans Skoru',
                        '${personelData['performansSkoru']}',
                        FuturisticTheme.neon,
                      ),
                      const SizedBox(height: 16),
                      // Aktif Görev Sayısı
                      _buildStatRow(
                        Icons.assignment_turned_in,
                        'Aktif Görev',
                        '${personelData['aktifGorevSayisi']}',
                        Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      // Uzmanlık Alanı
                      _buildStatRow(
                        Icons.engineering,
                        'Uzmanlık Alanı',
                        personelData['uzmanlikAlani']?.toString() ?? '---',
                        Colors.purple,
                      ),
                      const SizedBox(height: 16),
                      // Rol
                      _buildStatRow(
                        Icons.badge,
                        'Rol',
                        (personelData['rol'] as String?)?.toUpperCase() ?? '---',
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
                
                // Divider
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                ),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              Icons.add_task,
                              'Görev Ata',
                              Colors.green,
                              () {
                                if (!mounted) return;
                                // Görev atama işlemi
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Görev atama modülü açılıyor...'),
                                    backgroundColor: FuturisticTheme.neon,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              Icons.show_chart,
                              'Performans İzle',
                              Colors.blue,
                              () {
                                if (!mounted) return;
                                // Performans izleme işlemi
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Performans analizi açılıyor...'),
                                    backgroundColor: FuturisticTheme.neon,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        Icons.chat,
                        'İletişime Geç',
                        FuturisticTheme.neon,
                        () {
                          if (!mounted) return;
                          // Internal Chat açma işlemi
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sohbet açılıyor...'),
                              backgroundColor: FuturisticTheme.neon,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          GlassCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
              onTap: () async {
                final userProvider = context.read<UserProvider>();
                await userProvider.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

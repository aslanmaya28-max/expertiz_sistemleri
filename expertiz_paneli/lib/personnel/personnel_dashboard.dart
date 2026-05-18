import "dart:async";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:yerimebak_sistemleri/models/user_model.dart";
import "package:yerimebak_sistemleri/screens/login_screen.dart";
import "../../core/theme/futuristic_theme.dart";
import "../../core/widgets/glass_card.dart";
import "../../core/widgets/neon_button.dart";
import "../../core/layout/base_scaffold.dart";
import "../../providers/expertiz_provider.dart";
import "../../providers/admin_provider.dart";
import "../../providers/user_provider.dart";
import "../../models/talep_model.dart";
import "../../screens/personel/expertiz_sihirbazi.dart";

// ANA PERSONEL DASHBOARD SINIFI
class PersonnelDashboard extends StatefulWidget {
  const PersonnelDashboard({super.key});

  @override
  State<PersonnelDashboard> createState() => _PersonnelDashboardState();
}

class _PersonnelDashboardState extends State<PersonnelDashboard> {
  final int _currentIndex = 0;
  UserModel? _currentUser;
  List<TalepModel> _supabaseGorevler = [];
  StreamSubscription? _gorevSubscription;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _gorevSubscription?.cancel();
    super.dispose();
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
        _loadSupabaseGorevler();
        _subscribeGorevler();
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  Future<void> _loadSupabaseGorevler() async {
    if (_currentUser == null) return;
    try {
      final client = Supabase.instance.client;
      final userId = _currentUser!.id;
      final userName = _currentUser!.fullName;
      final response = await client
          .from('reports')
          .select()
          .or('assigned_personel_id.eq.$userId,data->assigned_personel_id.eq.$userId,data->assigned_personel_id.eq.$userName')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _supabaseGorevler = response
              .whereType<Map<String, dynamic>>()
              .map(_mapReportToTalep)
              .whereType<TalepModel>()
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Supabase gorev yukleme hatasi: $e');
    }
  }

  void _subscribeGorevler() {
    if (_currentUser == null) return;
    try {
      final stream = Supabase.instance.client
          .from('reports')
          .stream(primaryKey: ['id']);
      _gorevSubscription = stream.listen((data) {
        if (mounted && _currentUser != null) {
          final userId = _currentUser!.id;
          final userName = _currentUser!.fullName;
          setState(() {
            _supabaseGorevler = data
                .whereType<Map<String, dynamic>>()
                .where((row) {
                  final data = row['data'];
                  final assignedInData = data is Map
                      ? data['assigned_personel_id']?.toString()
                      : null;
                  return assignedInData == userId ||
                      assignedInData == userName;
                })
                .map(_mapReportToTalep)
                .whereType<TalepModel>()
                .toList();
          });
        }
      });
    } catch (e) {
      debugPrint('Gorev stream hatasi: $e');
    }
  }

  TalepModel? _mapReportToTalep(Map<String, dynamic> row) {
    try {
      final data = row['data'] is Map
          ? Map<String, dynamic>.from(row['data'] as Map)
          : <String, dynamic>{};
      final assignedPersonel = data['assigned_personel_id']?.toString();
      final status = row['status']?.toString();
      String durum;
      switch (status) {
        case 'published':
          durum = 'Tamamlandi';
          break;
        case 'rejected':
          durum = 'Iptal';
          break;
        case 'pending_admin':
          durum = 'Raporland\u0131';
          break;
        case 'pending_ai':
          durum = 'Raporland\u0131';
          break;
        case 'draft':
          durum = assignedPersonel != null && assignedPersonel.isNotEmpty
              ? 'Islemde'
              : 'Beklemede';
          break;
        default:
          durum = row['durum']?.toString() ?? 'Beklemede';
      }
      return TalepModel(
        id: row['id']?.toString() ?? '',
        musteriAdi: data['customer_name']?.toString() ?? row['user_id']?.toString() ?? 'Musteri',
        musteriId: row['user_id']?.toString() ?? '',
        telefon: data['customer_phone']?.toString() ?? '',
        aracPlaka: row['plaka']?.toString() ?? '',
        aracMarka: data['vehicle_snapshot'] is Map
            ? (data['vehicle_snapshot']['marka']?.toString() ?? 'Belirtilmedi')
            : 'Belirtilmedi',
        aracModel: data['vehicle_snapshot'] is Map
            ? (data['vehicle_snapshot']['model']?.toString() ?? 'Belirtilmedi')
            : 'Belirtilmedi',
        durum: durum,
        olusturulma: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
        atananPersonel: assignedPersonel,
        aciklama: row['ilan_linki']?.toString() ?? '',
        sehir: row['sehir']?.toString() ?? '',
        expertizFirmasi: row['ekspertiz_firmasi']?.toString() ?? '',
        expertizPaketi: data['expertiz_paketi']?.toString() ?? 'Belirtilmedi',
        paketFiyati: (row['paket_fiyati'] as num?)?.toDouble() ?? 0.0,
        hizmetBedeli: (row['hizmet_bedeli'] as num?)?.toDouble() ?? 6500.0,
        toplamTutar: (row['toplam_tutar'] as num?)?.toDouble() ?? 0.0,
        isPaid: row['odendi_mi'] == true,
      );
    } catch (e) {
      debugPrint('Report->Talep map hatasi: $e');
      return null;
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
    final merged = <String, TalepModel>{};
    for (final t in tumTalepler) {
      if (t.atananPersonel == _currentUser!.id ||
          t.atananPersonel == _currentUser!.fullName) {
        merged[t.id] = t;
      }
    }
    for (final t in _supabaseGorevler) {
      merged[t.id] = t;
    }
    return merged.values.toList()
      ..sort((a, b) => b.olusturulma.compareTo(a.olusturulma));
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChangeNotifierProvider(
            create: (_) => ExpertizProvider(),
            child: ExpertizSihirbazi(
              gorevId: gorev.id,
              musteriAdi: gorev.musteriAdi,
              aracPlaka: gorev.aracPlaka,
            ),
          ),
        ),
      ).then((_) {
        if (mounted) {
          context.read<AdminProvider>().loadTalepler();
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
    return FutureBuilder<Map<String, dynamic>>(
      future: loadPersonelData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.7)),
                const SizedBox(height: 16),
                Text('Veri yüklenemedi: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        final personelData = snapshot.data ?? {
          'id': _currentUser!.id,
          'adSoyad': _currentUser!.fullName,
          'email': _currentUser!.email,
          'rol': _currentUser!.role.displayName,
          'aktif': false,
          'musait': false,
          'uzmanlikAlani': 'Belirtilmemiş',
          'performansSkoru': 0.0,
          'aktifGorevSayisi': 0,
          'il': '---',
          'ilce': '---',
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Dijital Kimlik Kartı
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
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
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
                    
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          buildStatRow(
                            Icons.trending_up,
                            'Performans Skoru',
                            '${personelData['performansSkoru']}',
                            FuturisticTheme.neon,
                          ),
                          const SizedBox(height: 16),
                          buildStatRow(
                            Icons.assignment_turned_in,
                            'Aktif Görev',
                            '${personelData['aktifGorevSayisi']}',
                            Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          buildStatRow(
                            Icons.engineering,
                            'Uzmanlık Alanı',
                            personelData['uzmanlikAlani']?.toString() ?? '---',
                            Colors.purple,
                          ),
                          const SizedBox(height: 16),
                          buildStatRow(
                            Icons.badge,
                            'Rol',
                            (personelData['rol'] as String?)?.toUpperCase() ?? '---',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: buildActionButton(
                                  Icons.add_task,
                                  'Görev Ata',
                                  Colors.green,
                                  () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Görev atama modülü açılıyor...'),
                                        backgroundColor: FuturisticTheme.neon,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: buildActionButton(
                                  Icons.show_chart,
                                  'Performans İzle',
                                  Colors.blue,
                                  () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
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
                          buildActionButton(
                            Icons.chat,
                            'İletişime Geç',
                            FuturisticTheme.neon,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
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
                    await context.read<UserProvider>().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> loadPersonelData() async {
    try {
      final userProvider = context.read<UserProvider>();
      final userId = userProvider.userId;

      if (userId == null) {
        throw Exception('Oturum açılmadı');
      }

      final response = await Supabase.instance.client.rpc(
        'get_personnel_dashboard_stats',
        params: {'p_personnel_id': userId},
      );

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }

      return {
        'id': _currentUser!.id,
        'adSoyad': _currentUser!.fullName,
        'email': _currentUser!.email,
        'rol': _currentUser!.role.displayName,
        'aktif': false,
        'musait': false,
        'uzmanlikAlani': 'Belirtilmemiş',
        'performansSkoru': 0.0,
        'aktifGorevSayisi': 0,
        'il': '---',
        'ilce': '---',
      };
    } catch (e) {
      return {
        'id': _currentUser!.id,
        'adSoyad': _currentUser!.fullName,
        'email': _currentUser!.email,
        'rol': _currentUser!.role.displayName,
        'aktif': false,
        'musait': false,
        'uzmanlikAlani': 'Belirtilmemiş',
        'performansSkoru': 0.0,
        'aktifGorevSayisi': 0,
        'il': '---',
        'ilce': '---',
      };
    }
  }
  
  Widget buildStatRow(IconData icon, String label, String value, Color color) {
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
  
  Widget buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
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

// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/admin_provider.dart';
import '../providers/user_provider.dart';
import '../core/constants/roles.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../core/mappers/location_mapper.dart';
import '../core/constants/location_data.dart';
import '../widgets/status_chip.dart';
import '../services/personel_service.dart';
import '../services/finance_service.dart';
import '../screens/personel/personel_bolge_sistemi.dart';
import 'modules/finans_yonetimi.dart';
import 'modules/arac_operasyonu.dart';
import 'modules/rapor_inceleme_module.dart';
import '../models/personel_model.dart';
import '../models/talep_model.dart';
import '../ui/viewmodels/personel_viewmodel.dart';
import 'modules/ai_merkezi.dart';

// ==================== MODELLER ====================
// MÜŞTERİ MODELİ
class AdminMusteriModel {
  final String id;
  final String adSoyad;
  final String email;
  final String telefon;
  final int ilId;
  final String ilce;
  final int toplamExpertiz;
  final double toplamOdeme;
  final DateTime kayitTarihi;

  AdminMusteriModel({
    required this.id,
    required this.adSoyad,
    required this.email,
    required this.telefon,
    required this.ilId,
    required this.ilce,
    required this.toplamExpertiz,
    required this.toplamOdeme,
    required this.kayitTarihi,
  });

  /// Get city name using LocationMapper
  String get ilAdi => LocationMapper().getIlAdi(ilId);
}

// RAPOR TALEP MODELİ
class AdminRaporTalepModel {
  final String id;
  final String baslik;
  final String musteriAdi;
  final String musteriId;
  final String aracPlaka;
  final String durum;
  final DateTime talepTarihi;
  final String? aciklama;
  final String? notlar;
  final String? raporUrl;
  final String? personelId;
  final String? sehir;
  final double? ucret;

  AdminRaporTalepModel({
    required this.id,
    required this.baslik,
    required this.musteriAdi,
    required this.musteriId,
    required this.aracPlaka,
    required this.durum,
    required this.talepTarihi,
    this.aciklama,
    this.notlar,
    this.raporUrl,
    this.personelId,
    this.sehir,
    this.ucret,
  });

  /// Personel ID ata
  AdminRaporTalepModel personelIdAta(String personelId) {
    return AdminRaporTalepModel(
      id: id,
      baslik: baslik,
      musteriAdi: musteriAdi,
      musteriId: musteriId,
      aracPlaka: aracPlaka,
      durum: durum,
      talepTarihi: talepTarihi,
      aciklama: aciklama,
      notlar: notlar,
      raporUrl: raporUrl,
      personelId: personelId,
      sehir: sehir,
      ucret: ucret,
    );
  }

  /// CopyWith method for immutable updates
  AdminRaporTalepModel copyWith({
    String? id,
    String? baslik,
    String? musteriAdi,
    String? musteriId,
    String? aracPlaka,
    String? durum,
    DateTime? talepTarihi,
    String? aciklama,
    String? notlar,
    String? raporUrl,
    String? personelId,
    String? sehir,
    double? ucret,
  }) {
    return AdminRaporTalepModel(
      id: id ?? this.id,
      baslik: baslik ?? this.baslik,
      musteriAdi: musteriAdi ?? this.musteriAdi,
      musteriId: musteriId ?? this.musteriId,
      aracPlaka: aracPlaka ?? this.aracPlaka,
      durum: durum ?? this.durum,
      talepTarihi: talepTarihi ?? this.talepTarihi,
      aciklama: aciklama ?? this.aciklama,
      notlar: notlar ?? this.notlar,
      raporUrl: raporUrl ?? this.raporUrl,
      personelId: personelId ?? this.personelId,
      sehir: sehir ?? this.sehir,
      ucret: ucret ?? this.ucret,
    );
  }
}

// ==================== ANA ADMIN DASHBOARD ====================
/// AdminDashboard - Enterprise Grade Read-Only View
/// 
/// ARCHITECTURAL RULES:
/// - Dashboard NEVER filters manually
/// - Uses PersonelService results (already-filtered)
/// - Mapping layer used ONLY for display
/// - Zero business logic inside UI
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<AdminMusteriModel> _musteriler = [];
  
  // Location mapper for display purposes ONLY
  final LocationMapper _locationMapper = LocationMapper();
  
  // FINANSAL VERİLER - initState içinde çekilir
  double _toplamCiro = 0.0;
  double _kdvTutari = 0.0;
  double _personelPayi = 0.0;
  double _hakedisBorcu = 0.0;
  bool _finansalVerilerYuklendi = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _finansalVerileriYukle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PersonelService>().loadPersoneller();
      context.read<AdminProvider>().loadTalepler();
    });
  }
  
  /// Finansal verileri initState içinde bir kez çek
  void _finansalVerileriYukle() {
    FinanceService().getFinansalOzet().then((data) {
      if (mounted) {
        setState(() {
          _toplamCiro = (data['toplamCiro'] as num).toDouble();
          _kdvTutari = (data['kdvTutari'] as num).toDouble();
          _personelPayi = (data['toplamKomisyon'] as num).toDouble();
          _hakedisBorcu = (data['toplamHakedisBorcu'] as num).toDouble();
          _finansalVerilerYuklendi = true;
        });
      }
    }).catchError((error) {
      debugPrint('Finansal veriler yüklenirken hata: $error');
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  
  // ==================== PERSONEL YÖNETİMİ FONKSİYONLARI ====================
  /// Add personnel - delegates to PersonelService
  Future<void> _personelEkle(PersonelModel personel) async {
    final personelService = PersonelService();
    await personelService.addPersonel(personel);
  }
  
  /// Update personnel - delegates to PersonelService
  Future<void> _personelDuzenle(PersonelModel personel) async {
    final personelService = PersonelService();
    await personelService.updatePersonel(personel);
  }
  
  /// Delete personnel - delegates to PersonelService
  Future<void> _personelSil(String personelId) async {
    final personelService = PersonelService();
    await personelService.deletePersonel(personelId);
  }
  
  /// Personnel status toggle
  Future<void> _personelAktiflikDegistir(PersonelModel personel) async {
    final personelService = PersonelService();
    final updatedPersonel = personel.copyWith(aktif: !personel.aktif);
    await personelService.updatePersonel(updatedPersonel);
  }
  
  // ==================== ARAYÜZ WIDGET'LARI ====================
  @override
  Widget build(BuildContext context) {
    // Watch PersonelService for reactive updates
    final personelService = context.watch<PersonelService>();
    final locationMapper = LocationMapper();
    
    // UserProvider'dan current user'ı al - SINGLE SOURCE OF TRUTH
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    // Eğer kullanıcı gerçekten yoksa yönlendir
    if (currentUser == null) {
      Future.microtask(() {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const SizedBox.shrink();
    }
        
        // Calculate province counters from real PersonelService data
        final Map<int, int> provinceCounters = {};
        for (final personel in personelService.personeller) {
          provinceCounters[personel.ilId] = (provinceCounters[personel.ilId] ?? 0) + 1;
        }
        
        // Use PersonelService.personeller for role-based filtering and mapping
        // AUTHORITY LAYER - All filtering and mapping happens in service, NOT in UI
        final filteredPersoneller = personelService.personeller.where((p) {
          switch (currentUser.role) {
            case UserRole.admin:
              return true;
            case UserRole.fieldStaff:
              return p.ilId == currentUser.ilId;
            case UserRole.customer:
              return false;
            case UserRole.unauthorized:
              return false;
          }
        }).toList();
        
        final personelViewModels = filteredPersoneller.map((p) =>
          PersonelViewModel.fromModel(p, locationMapper)
        ).toList();
            
            return Scaffold(
              body: Column(
                children: [
                  // HEADER
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: FuturisticTheme.bgSecondary,
                      border: Border(
                        bottom: BorderSide(
                          color: FuturisticTheme.neon.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: FuturisticTheme.neon, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Admin Dashboard', style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              )),
                              Text(DateFormat('dd MMMM yyyy, EEEE').format(DateTime.now()), style: TextStyle(
                                color: Colors.white54,
                              )),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.notifications, color: FuturisticTheme.neon),
                          onPressed: _bildirimleriGoster,
                        ),
                        IconButton(
                          icon: Icon(Icons.exit_to_app, color: FuturisticTheme.neon),
                          onPressed: () => _cikisYap(context),
                        ),
                      ],
                    ),
                  ),
                  // TABS
                  Container(
                    color: FuturisticTheme.bgSecondary,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: FuturisticTheme.neon,
                      unselectedLabelColor: Colors.white54,
                      indicatorColor: FuturisticTheme.neon,
                      tabs: [
                        Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                        Tab(icon: Icon(Icons.directions_car), text: 'Araç Operasyonu'),
                        Tab(icon: Icon(Icons.people), text: 'Personel'),
                        Tab(icon: Icon(Icons.person), text: 'Müşteriler'),
                        Tab(icon: Icon(Icons.description), text: 'Raporlar'),
                        Tab(icon: Icon(Icons.psychology), text: 'AI Merkezi'),
                        Tab(icon: Icon(Icons.attach_money), text: 'Finans Yönetimi'),
                        Tab(icon: Icon(Icons.settings), text: 'Ayarlar'),
                      ],
                    ),
                  ),
                  // BODY
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDashboard(personelViewModels),
                        const AracOperasyonu(),
                        PersonelBolgePaneli(
                          personeller: filteredPersoneller.map((p) => p.toMap()).toList(),
                          onPersonelEkle: (p) => _personelEkle(PersonelModel.fromMap(p)),
                          onPersonelDuzenle: (p) => _personelDuzenle(PersonelModel.fromMap(p)),
                          onPersonelSil: (p) => _personelSil(PersonelModel.fromMap(p).id),
                          onPersonelAktiflikDegistir: (p) => _personelAktiflikDegistir(PersonelModel.fromMap(p)),
                        ),
                        _buildMusterilerTab(),
                        _buildRaporlarTab(),
                        const AIMerkezi(),
                        const FinansYonetimi(),
                        _buildAyarlarTab(),

                      ],
                    ),
                  ),
                ],
              ),
            );
  }

  void _bildirimleriGoster() {
    final bildirimler = context.read<AdminProvider>().bildirimler;
    showModalBottomSheet(
      context: context,
      backgroundColor: FuturisticTheme.bgSecondary,
      builder: (_) {
        if (bildirimler.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Bildirim yok', style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bildirimler.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white12),
          itemBuilder: (_, index) => ListTile(
            leading: const Icon(Icons.notifications, color: FuturisticTheme.neon),
            title: Text(
              bildirimler[index],
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
  void _cikisYap(BuildContext context) async {
    await context.read<UserProvider>().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  AdminRaporTalepModel _mapTalepToAdminRapor(TalepModel talep) {
    final aracBaslik = [
      talep.aracMarka,
      talep.aracModel,
    ].where((part) => part.trim().isNotEmpty).join(' ');

    return AdminRaporTalepModel(
      id: talep.id,
      baslik: aracBaslik.isNotEmpty ? aracBaslik : 'Ekspertiz Talebi',
      musteriAdi: talep.musteriAdi,
      musteriId: talep.musteriId,
      aracPlaka: talep.aracPlaka,
      durum: talep.durum,
      talepTarihi: talep.olusturulma,
      aciklama: talep.aciklama,
      personelId: talep.atananPersonel,
      sehir: talep.sehir,
      ucret: talep.toplamTutar > 0 ? talep.toplamTutar : talep.hesaplananToplamTutar,
    );
  }

  Widget _buildDashboard(List<PersonelViewModel> personelViewModels) {
    final personelService = context.watch<PersonelService>();
    final adminProvider = context.watch<AdminProvider>();
    final talepler = adminProvider.talepler;
    final gelenRaporlar = talepler
        .where((t) =>
            t.durum == 'Beklemede' ||
            t.durum == 'Personele Atandı' ||
            t.durum == 'Personele Atandı' ||
            t.durum == 'Islemde')
        .map(_mapTalepToAdminRapor)
        .toList();
    final gonderilecekRaporlar = talepler
        .where((t) => t.durum == 'Raporlandı')
        .map(_mapTalepToAdminRapor)
        .toList();
    final musteriSayisi = talepler
        .map((t) => t.musteriId.isNotEmpty ? t.musteriId : t.musteriAdi)
        .toSet()
        .length;

    final Map<int, int> bolgeCounters = {};
    final allBolgeIds = _locationMapper.getAllBolgeIds();

    for (final bolgeId in allBolgeIds) {
      bolgeCounters[bolgeId] = personelService.personeller
          .where((p) => p.bolgeId == bolgeId)
          .length;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildStatCard('Toplam Talep', talepler.length.toString(), Icons.directions_car, Colors.blue)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Atama/İşlem', gelenRaporlar.length.toString(), Icons.description, Colors.orange)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Müşteri', musteriSayisi.toString(), Icons.people, Colors.green)),
              SizedBox(width: 12),
              Expanded(child: _buildStatCard('Personel', personelViewModels.length.toString(), Icons.person, Colors.purple)),
            ],
          ),
          SizedBox(height: 20),
          Text('Bölgeye Göre Personel Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: allBolgeIds.map((bolgeId) {
              final bolgeAdi = _locationMapper.getBolgeAdi(bolgeId);
              final count = bolgeCounters[bolgeId] ?? 0;
              final renk = _locationMapper.getBolgeRenk(bolgeId);
              return _buildBolgeStatCard(bolgeAdi, count, renk);
            }).toList(),
          ),
          SizedBox(height: 20),
          if (_finansalVerilerYuklendi) _buildFinancialSummary(),
          SizedBox(height: 20),
          if (adminProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (adminProvider.error != null)
            _buildErrorSection(adminProvider.error!)
          else ...[
            _buildSection('Atama ve İşlem Bekleyen Talepler', gelenRaporlar),
            SizedBox(height: 20),
            _buildSection('Admin Onayı Bekleyen Raporlar', gonderilecekRaporlar),
          ],
        ],
      ),
    );
  }
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height:4),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildBolgeStatCard(String bolgeAdi, int count, Color renk) {
    return GlassCard(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: renk, width: 2),
            ),
            child: Icon(Icons.location_city, color: renk, size: 24),
          ),
          SizedBox(height: 8),
          Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: renk)),
          SizedBox(height: 4),
          Text(bolgeAdi, style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Finansal Özet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 16),
          _buildFinancialRow('Toplam Ciro', _toplamCiro, Colors.green),
          _buildFinancialRow('KDV Tutarı', _kdvTutari, Colors.orange),
          _buildFinancialRow('Personel Payı', _personelPayi, Colors.blue),
          _buildFinancialRow('Hakediş Borcu', _hakedisBorcu, Colors.red),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70)),
          Text('₺${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildErrorSection(String message) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.read<AdminProvider>().loadTalepler(),
            icon: const Icon(Icons.refresh),
            label: const Text('Tekrar dene'),
          ),
        ],
      ),
    );
  }
  Widget _buildSection(String title, List<AdminRaporTalepModel> raporlar) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
        SizedBox(height: 12),
        ...raporlar.map((rapor) => _buildRaporCard(rapor)),
      ],
    );
  }

  List<PersonelModel> _getAssignablePersoneller(
    AdminRaporTalepModel rapor,
    Iterable<PersonelModel> personeller,
  ) {
    final activePersoneller = personeller.where((p) => p.aktif).toList();
    final targetCity = _normalizeLocation(rapor.sehir ?? '');
    if (targetCity.isEmpty) return activePersoneller;
    final targetIlId = _getIlIdFromCityName(rapor.sehir);

    final cityMatches = activePersoneller.where((personel) {
      if (targetIlId != 0 && personel.ilId == targetIlId) return true;
      final modelCity = _normalizeLocation(personel.il ?? '');
      final mapperCity = _normalizeLocation(_locationMapper.getIlAdi(personel.ilId));
      return modelCity == targetCity || mapperCity == targetCity;
    }).toList();

    return cityMatches;
  }

  String _normalizeLocation(String value) {
    return value
        .toLowerCase()
        .replaceAll('\u0131', 'i')
        .replaceAll('\u0130', 'i')
        .replaceAll('\u011f', 'g')
        .replaceAll('\u00fc', 'u')
        .replaceAll('\u015f', 's')
        .replaceAll('\u00f6', 'o')
        .replaceAll('\u00e7', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _getIlIdFromCityName(String? cityName) {
    final normalized = _normalizeLocation(cityName ?? '');
    if (normalized.isEmpty) return 0;

    for (final city in LocationData.cities) {
      if (_normalizeLocation(city.ilAdi) == normalized) {
        return city.plakaKodu;
      }
    }

    return 0;
  }

  Widget _buildRaporCard(AdminRaporTalepModel rapor) {
    final personelService = context.watch<PersonelService>();
    
    // Personel listesi - tüm personeller
    final availablePersoneller = _getAssignablePersoneller(
      rapor,
      personelService.personeller,
    );
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(rapor.baslik, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Müşteri: ${rapor.musteriAdi}', style: TextStyle(color: Colors.white70)),
                Text('Plaka: ${rapor.aracPlaka}', style: TextStyle(color: Colors.white70)),
                if (rapor.sehir?.isNotEmpty == true)
                  Text('Sehir: ${rapor.sehir}', style: TextStyle(color: Colors.white70)),
                if (rapor.ucret != null)
                  Text('Ücret: ₺${rapor.ucret!.toStringAsFixed(2)}', style: TextStyle(color: FuturisticTheme.neon)),
              ],
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon),
            onTap: () {
              // Rapor detayına git
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // StatusChip ile durum gösterimi
                StatusChip(durum: rapor.durum),
                SizedBox(height: 8),
                
                // Personel Atama Butonu
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showPersonelAtamaDialog(context, rapor, availablePersoneller),
                        icon: Icon(Icons.person_add, size: 18),
                        label: Text(rapor.personelId?.isNotEmpty == true ? 'Personeli Değiştir' : 'Personel Ata'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FuturisticTheme.neon.withValues(alpha: 0.2),
                          foregroundColor: FuturisticTheme.neon,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: FuturisticTheme.neon.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Personel Atama Dialog - Futuristic Cyber Style with Safe UI Feedback
  /// ID Based Assignment: Uses personel.id only, not personel.name
  /// Data Source: PersonelService (already filtered by role)
  void _showPersonelAtamaDialog(
    BuildContext context,
    AdminRaporTalepModel rapor,
    List<PersonelModel> availablePersoneller,
  ) async {
    final adminProvider = context.read<AdminProvider>();
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                FuturisticTheme.bgSecondary.withValues(alpha: 0.95),
                FuturisticTheme.bgPrimary.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FuturisticTheme.neon.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: FuturisticTheme.neon.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Neon Effect
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                      FuturisticTheme.neon.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: FuturisticTheme.neon.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.person_add_alt_1,
                        color: FuturisticTheme.neon,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERSONEL ATAMA',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            rapor.baslik,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Personel Listesi - Cyber Personel Cards
              Flexible(
                child: availablePersoneller.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color: Colors.white30,
                              ),
                              SizedBox(height: 16),
                              Text(
                                rapor.sehir?.isNotEmpty == true
                                    ? '${rapor.sehir} icin aktif personel bulunamadi'
                                    : 'Uygun personel bulunamadi',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: availablePersoneller.length,
                        itemBuilder: (context, index) {
                          final personel = availablePersoneller[index];
                          final ilAdi = _locationMapper.getIlAdi(personel.ilId);
                          final isSelected = rapor.personelId == personel.id;
                          
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        FuturisticTheme.neon.withValues(alpha: 0.3),
                                        FuturisticTheme.neon.withValues(alpha: 0.1),
                                      ],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.05),
                                        Colors.white.withValues(alpha: 0.02),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? FuturisticTheme.neon
                                    : Colors.white.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            FuturisticTheme.neon,
                                            FuturisticTheme.neon.withValues(alpha: 0.6),
                                          ],
                                        )
                                      : LinearGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.1),
                                            Colors.white.withValues(alpha: 0.05),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: isSelected ? Colors.white : Colors.white60,
                                  size: 28,
                                ),
                              ),
                              title: Text(
                                personel.adSoyad ?? personel.tamAd,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: FuturisticTheme.neon,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        ilAdi,
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Icon(
                                        Icons.work,
                                        size: 14,
                                        color: FuturisticTheme.neon,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          personel.uzmanlikAlani ?? personel.unvan,
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: isSelected
                                  ? Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: FuturisticTheme.neon,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                              onTap: () async {
                                // ID Based Assignment - Use personel.id ONLY
                                final success = await adminProvider.atananPersonelGuncelle(
                                  rapor.id,
                                  personel.id, // ID based assignment
                                );
                                
                                // Dialog'u kapat
                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                                
                                // Safe UI Feedback
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            success ? Icons.check_circle : Icons.error,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              success
                                                  ? 'Personel atandı: ${personel.adSoyad ?? personel.tamAd}'
                                                  : 'Atama başarısız',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: success ? Colors.green : Colors.red,
                                      duration: Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                                if (success && mounted) {
                                  await context.read<AdminProvider>().loadTalepler();
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              
              // Footer
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: Icon(Icons.close, color: Colors.white70),
                        label: Text(
                          'İptal',
                          style: TextStyle(color: Colors.white70),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMusterilerTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Müşteriler', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 20),
          ..._musteriler.map((musteri) => _buildMusteriCard(musteri)),
        ],
      ),
    );
  }

  Widget _buildMusteriCard(AdminMusteriModel musteri) {
    // Use LocationMapper to get city name for display ONLY
    final ilAdi = _locationMapper.getIlAdi(musteri.ilId);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: ListTile(
          title: Text(musteri.adSoyad, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${musteri.email}', style: TextStyle(color: Colors.white70)),
              Text('Telefon: ${musteri.telefon}', style: TextStyle(color: Colors.white70)),
              // Display location using LocationMapper - NO string-based logic
              Text('Konum: $ilAdi, ${musteri.ilce}', style: TextStyle(color: Colors.white70)),
              Text('Toplam Expertiz: ${musteri.toplamExpertiz}', style: TextStyle(color: Colors.white70)),
              Text('Toplam Ödeme: ₺${musteri.toplamOdeme.toStringAsFixed(2)}', style: TextStyle(color: FuturisticTheme.neon)),
            ],
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon),
          onTap: () {
            // Müşteri detayına git
          },
        ),
      ),
    );
  }

  Widget _buildRaporlarTab() {
    final adminProvider = context.watch<AdminProvider>();
    final raporlanmisTalepler = adminProvider.talepler
        .where((t) =>
            t.durum == 'Raporland\u0131' ||
            t.durum == 'Raporland\u0061' ||
            t.durum == 'Tamamlandi' ||
            t.durum == 'Iptal')
        .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Raporlar',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: FuturisticTheme.neon)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: FuturisticTheme.neon),
                ),
                child: Text('${raporlanmisTalepler.length} rapor',
                    style: TextStyle(
                        color: FuturisticTheme.neon,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (raporlanmisTalepler.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(height: 16),
                    const Text('Henuz rapor bulunmuyor',
                        style: TextStyle(color: Colors.white38)),
                  ],
                ),
              ),
            )
          else
            ...raporlanmisTalepler.map((talep) => _buildTalepRaporCard(talep)),
        ],
      ),
    );
  }

  /// Ayarlar Tab'ı - Sistem yapılandırması
  Widget _buildAyarlarTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sistem Ayarları', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: FuturisticTheme.neon)),
          SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Genel Ayarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 16),
                _buildAyarlarItem(Icons.language, 'Dil', 'Türkçe'),
                Divider(color: Colors.white12),
                _buildAyarlarItem(Icons.palette, 'Tema', 'Karanlık'),
                Divider(color: Colors.white12),
                _buildAyarlarItem(Icons.notifications, 'Bildirimler', 'Açık'),
                Divider(color: Colors.white12),
                _buildAyarlarItem(Icons.security, 'Güvenlik', '2FA Kapalı'),
              ],
            ),
          ),
          SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sistem Bilgisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 16),
                _buildAyarlarItem(Icons.info, 'Versiyon', '1.0.0'),
                Divider(color: Colors.white12),
                _buildAyarlarItem(Icons.cloud, 'Supabase', 'Bağlı'),
                Divider(color: Colors.white12),
                _buildAyarlarItem(Icons.storage, 'Veritabanı', 'PostgreSQL'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAyarlarItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: FuturisticTheme.neon, size: 20),
          SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.white70)),
          Spacer(),
          Text(value, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTalepRaporCard(TalepModel talep) {

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
                '${talep.aracMarka} ${talep.aracModel} - ${talep.aracPlaka}',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Musteri: ${talep.musteriAdi}',
                    style: TextStyle(color: Colors.white70)),
                Text('Personel: ${talep.atananPersonel ?? "Atanmadi"}',
                    style: TextStyle(color: Colors.white70)),
                Text('Sehir: ${talep.sehir}',
                    style: TextStyle(color: Colors.white70)),
                Text('Tutar: ${talep.toplamTutar > 0 ? talep.toplamTutar : talep.hesaplananToplamTutar} TL',
                    style: TextStyle(color: FuturisticTheme.neon)),
                Text(
                    'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(talep.olusturulma)}',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                StatusChip(durum: talep.durum),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RaporIncelemeModule(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Incele'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        FuturisticTheme.neon.withValues(alpha: 0.2),
                    foregroundColor: FuturisticTheme.neon,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: FuturisticTheme.neon.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}


import 'package:flutter/material.dart';
import '../../../core/theme/futuristic_theme.dart';
import '../../../widgets/cyber/cyber_shimmer_loading.dart';
import '../../../widgets/cyber/cyber_error_widget.dart';
import '../../../widgets/cyber/cyber_radar_scan.dart';
import '../../../models/personel_model.dart';
import '../../../services/personel_service.dart';
import '../../../core/constants/roles.dart';

/// Araç Operasyonu Modülü
/// Araç operasyonlarını 4 sekme üzerinden yönetir:
/// - Atama Bekleyen
/// - İşlemdeki
/// - Onay Bekleyen
/// - Tamamlanan
class AracOperasyonu extends StatefulWidget {
  const AracOperasyonu({super.key});

  @override
  State<AracOperasyonu> createState() => _AracOperasyonuState();
}

class _AracOperasyonuState extends State<AracOperasyonu> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Mock veriler
  final List<Map<String, dynamic>> _atamaBekleyenRaporlar = [
    {
      'id': 'AR001',
      'baslik': 'BMW 320i Motor Ses İncelemesi',
      'musteriAdi': 'Ahmet Yılmaz',
      'musteriId': 'M001',
      'aracPlaka': '34ABC123',
      'aciklama': 'Araç çalıştığında motor bölgesinden anormal ses geliyor',
      'talepTarihi': DateTime.now().subtract(const Duration(hours: 2)),
      'ucret': 2500,
    },
    {
      'id': 'AR002',
      'baslik': 'Mercedes C200 Değerleme Talebi',
      'musteriAdi': 'Mehmet Kaya',
      'musteriId': 'M002',
      'aracPlaka': '06XYZ789',
      'aciklama': 'Satın almak için ekspertiz raporu gerekiyor',
      'talepTarihi': DateTime.now().subtract(const Duration(hours: 5)),
      'ucret': 3500,
    },
  ];
  
  final List<Map<String, dynamic>> _islemdekiRaporlar = [
    {
      'id': 'AR003',
      'baslik': 'Audi A4 Kaza Sonrası Hasar Tespiti',
      'musteriAdi': 'Ayşe Demir',
      'musteriId': 'M003',
      'aracPlaka': '34DEF456',
      'aciklama': 'Arka çamurlukta hafif çizik ve çökme var',
      'talepTarihi': DateTime.now().subtract(const Duration(hours: 8)),
      'ucret': 4200,
      'personelId': 'P001',
      'personelAdi': 'Ahmet Yılmaz',
    },
    {
      'id': 'AR004',
      'baslik': 'Volkswagen Golf 8 Full Paket Expertiz',
      'musteriAdi': 'Fatma Şahin',
      'musteriId': 'M004',
      'aracPlaka': '34GHI789',
      'aciklama': 'Sıfıra yakın araç, detaylı inceleme istiyor',
      'talepTarihi': DateTime.now().subtract(const Duration(hours: 12)),
      'ucret': 3000,
      'personelId': 'P002',
      'personelAdi': 'Mehmet Kaya',
    },
  ];
  
  final List<Map<String, dynamic>> _onayBekleyenRaporlar = [
    {
      'id': 'AR005',
      'baslik': 'Toyota Corolla 2021 Expertiz Raporu',
      'musteriAdi': 'Ali Veli',
      'musteriId': 'M005',
      'aracPlaka': '35JKL012',
      'aciklama': 'Rapor tamamlandı, müşteriye gönderim bekliyor',
      'talepTarihi': DateTime.now().subtract(const Duration(days: 1)),
      'ucret': 2800,
      'personelId': 'P003',
      'personelAdi': 'Ayşe Demir',
    },
    {
      'id': 'AR006',
      'baslik': 'Renault Megane 2019 Değerleme Raporu',
      'musteriAdi': 'Zeynep Korkmaz',
      'musteriId': 'M006',
      'aracPlaka': '34MNO345',
      'aciklama': 'Rapor hazırlanıyor',
      'talepTarihi': DateTime.now().subtract(const Duration(hours: 6)),
      'ucret': 3200,
      'personelId': 'P004',
      'personelAdi': 'Fatma Şahin',
    },
  ];
  
  final List<Map<String, dynamic>> _tamamlananRaporlar = [];

  bool _isLoading = false;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FuturisticTheme.bgPrimary,
      body: Column(
        children: [
          Container(
            color: FuturisticTheme.bgSecondary,
            child: TabBar(
              controller: _tabController,
              labelColor: FuturisticTheme.neon,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.54),
              indicatorColor: FuturisticTheme.neon,
              tabs: const [
                Tab(text: 'Atama Bekleyen'),
                Tab(text: 'İşlemdeki'),
                Tab(text: 'Onay Bekleyen'),
                Tab(text: 'Tamamlanan'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListTab(_atamaBekleyenRaporlar, _buildAtamaBekleyenItem, 'Atama bekleyen rapor bulunamadı'),
                _buildListTab(_islemdekiRaporlar, _buildIslemdekiItem, 'İşlemdeki rapor bulunamadı'),
                _buildListTab(_onayBekleyenRaporlar, _buildOnayBekleyenItem, 'Onay bekleyen rapor bulunamadı'),
                _buildListTab(_tamamlananRaporlar, _buildTamamlananItem, 'Tamamlanan rapor bulunamadı'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _simulateDataFetch();
      }
    });

    _simulateDataFetch();
  }

  Future<void> _simulateDataFetch() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
      _hasError = false;
    });
  }
  
  void _retryLoading() {
     if (!mounted) return;
     _simulateDataFetch();
  }

  Widget _buildListTab(List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) itemBuilder, String emptyMessage) {
    if (_hasError) {
      return CyberErrorWidget(onRetry: _retryLoading);
    }

    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: CyberShimmerLoading(height: 100),
        ),
      );
    }

    if (items.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(items[index]),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CyberRadarScan(size: 150, color: FuturisticTheme.neon),
          const SizedBox(height: 30),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: FuturisticTheme.neon.withValues(alpha: 0.8), blurRadius: 15),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "HENÜZ KAYIT BULUNAMADI",
            style: TextStyle(
              color: FuturisticTheme.neon.withValues(alpha: 0.7),
              fontSize: 12,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w600
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtamaBekleyenItem(Map<String, dynamic> rapor) {
    return _buildCyberCard(
      rapor: rapor,
      leadingIcon: Icons.directions_car,
      statusColor: _getDurumColor(rapor['durum'] ?? 'Beklemede'),
      trailing: IconButton(
        icon: const Icon(Icons.person_add, color: FuturisticTheme.neon),
        onPressed: () => _personelAtamaDialog(rapor),
        tooltip: 'Personel Ata',
      ),
    );
  }

  Widget _buildIslemdekiItem(Map<String, dynamic> rapor) {
    return _buildCyberCard(
      rapor: rapor,
      leadingIcon: Icons.settings_suggest,
      statusColor: _getDurumColor(rapor['durum'] ?? 'İncelemede'),
      trailing: IconButton(
        icon: const Icon(Icons.visibility, color: FuturisticTheme.neon),
        onPressed: () {
          if (!mounted) return;
        },
        tooltip: 'Detay',
      ),
    );
  }

  Widget _buildOnayBekleyenItem(Map<String, dynamic> rapor) {
    return _buildCyberCard(
      rapor: rapor,
      leadingIcon: Icons.verified_user,
      statusColor: Colors.greenAccent,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
            onPressed: () {
              if (!mounted) return;
            },
            tooltip: 'Onayla',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
            onPressed: () {
              if (!mounted) return;
            },
            tooltip: 'Reddet',
          ),
        ],
      ),
    );
  }

  Widget _buildTamamlananItem(Map<String, dynamic> rapor) {
    return _buildCyberCard(
      rapor: rapor,
      leadingIcon: Icons.task_alt,
      statusColor: _getDurumColor(rapor['durum'] ?? 'Tamamlandı'),
      trailing: IconButton(
        icon: const Icon(Icons.visibility, color: FuturisticTheme.neon),
        onPressed: () {
          if (!mounted) return;
        },
        tooltip: 'Detay',
      ),
    );
  }

  Widget _buildCyberCard({
    required Map<String, dynamic> rapor,
    required IconData leadingIcon,
    required Color statusColor,
    required Widget trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: FuturisticTheme.neon.withValues(alpha: 0.1),
      color: FuturisticTheme.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(leadingIcon, color: statusColor),
        ),
        title: Text(
          rapor['baslik']?.toString() ?? '---',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(Icons.pin, 'Plaka: ${rapor['aracPlaka']?.toString() ?? '---'}'),
              _buildInfoRow(Icons.person, 'Müşteri: ${rapor['musteriAdi']?.toString() ?? '---'}'),
              if (rapor.containsKey('personelAdi') && rapor['personelAdi'] != null)
                 _buildInfoRow(Icons.badge, 'Personel: ${rapor['personelAdi']?.toString() ?? '---'}'),
              _buildInfoRow(Icons.info_outline, 'Durum: ${rapor['durum']?.toString() ?? '---'}', color: statusColor),
            ],
          ),
        ),
        trailing: trailing,
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDurumColor(String durum) {
    switch (durum) {
      case 'Beklemede':
      case 'İnceleme Bekliyor':
      case 'Onay Bekliyor': return Colors.orange;
      case 'İncelemede':
      case 'Düzeltme Gerekli': return Colors.blue;
      case 'Personele Atandı': return Colors.purple;
      case 'Hazır':
      case 'Gönderim Bekliyor': return Colors.green;
      case 'Gönderildi': return Colors.teal;
      case 'Tamamlandı':
      case 'Onaylandı':
      case 'Arşivlendi': return Colors.green;
      case 'Reddedildi': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _personelAtamaDialog(Map<String, dynamic> rapor) {
    showDialog(
      context: context,
      builder: (context) => _PersonelAtamaDialog(
        rapor: rapor,
        onPersonelAta: (personelId) {
          _personelAta(rapor, personelId);
        },
      ),
    );
  }

  Future<void> _personelAta(Map<String, dynamic> rapor, String personelId) async {
    if (!mounted) return;
    
    try {
      final updatedRapor = Map<String, dynamic>.from(rapor);
      updatedRapor['personelId'] = personelId;
      updatedRapor['durum'] = 'Personele Atandı';
      updatedRapor['personelAdi'] = personelId;

      if (!mounted) return;

      setState(() {
        _atamaBekleyenRaporlar.removeWhere((r) => r['id'] == rapor['id']);
        updatedRapor['durum'] = 'İncelemede';
        _islemdekiRaporlar.add(updatedRapor);
      });

      if (!mounted) return;

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rapor['aracPlaka']} için personel atandı'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Personel atama hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Personel atama hatası: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

class _PersonelAtamaDialog extends StatefulWidget {
  final Map<String, dynamic> rapor;
  final Function(String) onPersonelAta;

  const _PersonelAtamaDialog({
    required this.rapor,
    required this.onPersonelAta,
  });

  @override
  State<_PersonelAtamaDialog> createState() => _PersonelAtamaDialogState();
}

class _PersonelAtamaDialogState extends State<_PersonelAtamaDialog> {
  String? _secilenPersonelId;
  List<PersonelModel> _personeller = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _personelleriYukle();
  }

  Future<void> _personelleriYukle() async {
    if (!mounted) return;
    
    try {
      final personelService = PersonelService();
      await personelService.loadPersoneller();
      
      if (!mounted) return;
      
      final filteredPersoneller = await personelService.getFilteredPersoneller();
      
      if (!mounted) return;

      setState(() {
        _personeller = filteredPersoneller.isNotEmpty
            ? filteredPersoneller
            : [
                PersonelModel(
                  id: 'P001',
                  ad: 'Ahmet',
                  soyad: 'Yılmaz',
                  unvan: 'Saha Personeli',
                  ilId: 34,
                  bolgeId: 1,
                  rol: UserRole.fieldStaff,
                  il: 'İstanbul',
                  bolge: 'Marmara',
                  aktif: true,
                ),
                PersonelModel(
                  id: 'P002',
                  ad: 'Mehmet',
                  soyad: 'Kaya',
                  unvan: 'Saha Personeli',
                  ilId: 6,
                  bolgeId: 2,
                  rol: UserRole.fieldStaff,
                  il: 'Ankara',
                  bolge: 'İç Anadolu',
                  aktif: true,
                ),
                PersonelModel(
                  id: 'P003',
                  ad: 'Ayşe',
                  soyad: 'Demir',
                  unvan: 'Uzman Personel',
                  ilId: 34,
                  bolgeId: 1,
                  rol: UserRole.fieldStaff,
                  il: 'İstanbul',
                  bolge: 'Marmara',
                  aktif: true,
                ),
              ];
        _loading = false;
      });
    } catch (e) {
      debugPrint('Personel yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _personelAta() {
    if (!mounted) return;
    
    if (_secilenPersonelId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen listeden bir personel seçin'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    widget.onPersonelAta(_secilenPersonelId!);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Personel Ata: ${widget.rapor['aracPlaka']}'),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Atanacak personeli seçin:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: _secilenPersonelId,
                    onChanged: (value) {
                      setState(() {
                        _secilenPersonelId = value;
                      });
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _personeller.map((personel) => RadioListTile<String>(
                        title: Text('${personel.ad} ${personel.soyad}'),
                        subtitle: Text('${personel.unvan} - ${personel.il}'),
                        value: personel.id,
                        secondary: personel.aktif
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.block, color: Colors.grey),
                      )).toList(),
                    ),
                  ),
                  if (_personeller.isEmpty)
                    const Text('Personel bulunamadı', style: TextStyle(color: Colors.grey)),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _personelAta,
          child: const Text('Ata'),
        ),
      ],
    );
  }
}

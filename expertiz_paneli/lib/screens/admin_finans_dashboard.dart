import 'package:flutter/material.dart';
import '../services/finance_service.dart';
import '../models/finance/finance_model.dart';

class AdminFinansDashboard extends StatefulWidget {
  const AdminFinansDashboard({super.key});

  @override
  State<AdminFinansDashboard> createState() => _AdminFinansDashboardState();
}

class _AdminFinansDashboardState extends State<AdminFinansDashboard> {
  Map<String, dynamic>? _finansalOzet;
  List<Odeme> _odemeler = [];
  List<PersonelHakedis> _hakedisler = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ozet = await FinanceService().getFinansalOzet();
      final odemeler = await FinanceService().getOdemeler();
      final hakedisler = await FinanceService().getHakedisler();

      setState(() {
        _finansalOzet = ozet;
        _odemeler = odemeler;
        _hakedisler = hakedisler;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veriler yüklenirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finans Dashboard'),
        backgroundColor: Colors.blue[800],
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _verileriYukle,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _verileriYukle,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Finansal Özet Kartları
                    _buildFinansalOzetKartlari(),
                    const SizedBox(height: 24),

                    // Grafikler ve İstatistikler
                    _buildGrafiklerVeIstatistikler(),
                    const SizedBox(height: 24),

                    // Son Ödemeler
                    _buildSonOdemeler(),
                    const SizedBox(height: 24),

                    // Personel Hakedişleri
                    _buildPersonelHakedisleri(),
                    const SizedBox(height: 24),

                    // Ödeme Yöntemi Dağılımı
                    _buildOdemeYontemiDagilimi(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFinansalOzetKartlari() {
    if (_finansalOzet == null) return const SizedBox();

    final toplamCiro = (_finansalOzet!['toplamCiro'] as num).toDouble();
    final toplamKomisyon = (_finansalOzet!['toplamKomisyon'] as num).toDouble();
    final netGelir = (_finansalOzet!['netGelir'] as num).toDouble();
    final toplamHakedisBorcu = (_finansalOzet!['toplamHakedisBorcu'] as num).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finansal Özet',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _ozetKarti(
              'Toplam Ciro',
              '${toplamCiro.toStringAsFixed(2)} TL',
              Icons.trending_up,
              Colors.green[600]!,
              '${_finansalOzet!['toplamOdemeSayisi']} işlem',
            ),
            _ozetKarti(
              'Net Gelir',
              '${netGelir.toStringAsFixed(2)} TL',
              Icons.account_balance_wallet,
              Colors.blue[600]!,
              'Komisyon hariç',
            ),
            _ozetKarti(
              'Komisyon',
              '${toplamKomisyon.toStringAsFixed(2)} TL',
              Icons.percent,
              Colors.orange[600]!,
              '%25 oranı',
            ),
            _ozetKarti(
              'Hakediş Borcu',
              '${toplamHakedisBorcu.toStringAsFixed(2)} TL',
              Icons.people,
              Colors.red[600]!,
              '${_finansalOzet!['bekleyenHakedisSayisi']} bekleyen',
            ),
          ],
        ),
      ],
    );
  }

  Widget _ozetKarti(String baslik, String deger, IconData ikon, Color renk, String altBilgi) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(ikon, color: renk, size: 24),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              baslik,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              deger,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: renk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              altBilgi,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrafiklerVeIstatistikler() {
    if (_finansalOzet == null) return const SizedBox();

    final toplamOdemeSayisi = _finansalOzet!['toplamOdemeSayisi'] as int;
    final bekleyenOdemeSayisi = _finansalOzet!['bekleyenOdemeSayisi'] as int;
    final odenenHakedisler = (_finansalOzet!['odenenHakedisler'] as num).toDouble();
    final toplamHakedisBorcu = (_finansalOzet!['toplamHakedisBorcu'] as num).toDouble();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'İstatistikler',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _istatistikKutusu(
                    'Toplam Ödeme',
                    toplamOdemeSayisi.toString(),
                    Icons.payment,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _istatistikKutusu(
                    'Bekleyen Ödeme',
                    bekleyenOdemeSayisi.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _istatistikKutusu(
                    'Ödenen Hakediş',
                    '${odenenHakedisler.toStringAsFixed(2)} TL',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _istatistikKutusu(
                    'Bekleyen Hakediş',
                    '${toplamHakedisBorcu.toStringAsFixed(2)} TL',
                    Icons.hourglass_empty,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _istatistikKutusu(String baslik, String deger, IconData ikon, MaterialColor renk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(ikon, color: renk, size: 32),
          const SizedBox(height: 8),
          Text(
            deger,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: renk,
            ),
          ),
          Text(
            baslik,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSonOdemeler() {
    final sonOdemeler = _odemeler.take(5).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt, color: Colors.blue[800]),
                    const SizedBox(width: 8),
                    Text(
                      'Son Ödemeler',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _tumOdemeleriGoster(),
                  child: Text('Tümünü Gör'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (sonOdemeler.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Henüz ödeme kaydı yok',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...sonOdemeler.map((odeme) => _odemeKarti(odeme)),
          ],
        ),
      ),
    );
  }

  Widget _odemeKarti(Odeme odeme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: odeme.durumRengi.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(odeme.durumIkonu, color: odeme.durumRengi, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    odeme.formatliTutar,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${odeme.olusturmaTarihi.day}/${odeme.olusturmaTarihi.month}/${odeme.olusturmaTarihi.year}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Chip(
              label: Text(odeme.durumText),
              backgroundColor: odeme.durumRengi.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: odeme.durumRengi,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonelHakedisleri() {
    // Personel bazlı hakediş özeti
    final Map<String, double> personelHakedisleri = {};
    for (var hakedis in _hakedisler) {
      if (hakedis.durum == 'bekleniyor') {
        personelHakedisleri[hakedis.personelID] = 
            (personelHakedisleri[hakedis.personelID] ?? 0.0) + hakedis.hakedisTutari;
      }
    }

    if (personelHakedisleri.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: Colors.blue[800]),
                  const SizedBox(width: 8),
                  Text(
                    'Personel Hakedişleri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Henüz bekleyen hakediş yok',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'Personel Hakedişleri',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...personelHakedisleri.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Personel: ${entry.key}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(2)} TL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOdemeYontemiDagilimi() {
    // Ödeme yöntemi dağılımı
    final Map<String, int> odemeYontemleri = {};
    for (var odeme in _odemeler) {
      odemeYontemleri[odeme.odemeYontemi] = 
          (odemeYontemleri[odeme.odemeYontemi] ?? 0) + 1;
    }

    if (odemeYontemleri.isEmpty) {
      return const SizedBox();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Text(
                  'Ödeme Yöntemi Dağılımı',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...odemeYontemleri.entries.map((entry) {
              final yontemAdi = _odemeYontemiAdi(entry.key);
              final yuzde = (entry.value / _odemeler.length * 100).toStringAsFixed(1);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(yontemAdi),
                        Text(
                          '%$yuzde (${entry.value} işlem)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value / _odemeler.length,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _odemeYontemiAdi(String yontem) {
    switch (yontem) {
      case 'kredi_karti':
        return 'Kredi Kartı';
      case 'havale':
        return 'Havale/EFT';
      case 'nakit':
        return 'Nakit';
      default:
        return yontem;
    }
  }

  void _tumOdemeleriGoster() {
    // Tüm ödemeleri gösteren modal
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Ödemeler'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _odemeler.isEmpty
              ? const Center(child: Text('Henüz ödeme kaydı yok'))
              : ListView.builder(
                  itemCount: _odemeler.length,
                  itemBuilder: (context, index) {
                    final odeme = _odemeler[index];
                    return _odemeDetayKarti(odeme);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _odemeDetayKarti(Odeme odeme) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(odeme.durumIkonu, color: odeme.durumRengi),
        title: Text(odeme.formatliTutar),
        subtitle: Text(
          '${odeme.olusturmaTarihi.day}/${odeme.olusturmaTarihi.month}/${odeme.olusturmaTarihi.year}',
        ),
        trailing: Chip(
          label: Text(odeme.durumText),
          backgroundColor: odeme.durumRengi.withValues(alpha: 0.1),
          labelStyle: TextStyle(
            color: odeme.durumRengi,
            fontSize: 12,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detaySatiri('Ödeme ID', odeme.id),
                _detaySatiri('Müşteri ID', odeme.customerID),
                _detaySatiri('Personel ID', odeme.staffID),
                _detaySatiri('Rapor ID', odeme.reportID),
                _detaySatiri('Komisyon', odeme.formatliKomisyon),
                _detaySatiri('Net Tutar', odeme.formatliNet),
                _detaySatiri('Ödeme Yöntemi', _odemeYontemiAdi(odeme.odemeYontemi)),
                if (odeme.referansNo != null)
                  _detaySatiri('Referans No', odeme.referansNo!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detaySatiri(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

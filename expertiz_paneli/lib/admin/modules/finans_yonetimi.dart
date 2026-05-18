import 'package:flutter/material.dart';
import '../../../core/constants/yerimebak_colors.dart';
import '../../../services/finance_service.dart';

/// Finans Yönetimi Modülü
/// Finansal verileri, gelir-gider takibi ve ödemeleri yönetir
class FinansYonetimi extends StatefulWidget {
  const FinansYonetimi({super.key});

  @override
  State<FinansYonetimi> createState() => _FinansYonetimiState();
}

class _FinansYonetimiState extends State<FinansYonetimi> {
  // Finansal Veriler
  double _toplamCiro = 0.0;
  double _kdvTutari = 0.0;
  double _personelPayi = 0.0;
  double _hakedisBorcu = 0.0;
  bool _finansalVerilerYuklendi = false;

  @override
  void initState() {
    super.initState();
    _finansalVerileriYukle();
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finans Yönetimi',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          
          // FINANSAL ÖZET KARTLARI
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: [
              _buildFinansKart(
                'Toplam Ciro',
                _finansalVerilerYuklendi ? '${(_toplamCiro / 1000).toStringAsFixed(1)}K TL' : 'Yükleniyor...',
                Icons.trending_up,
                Colors.teal,
                isDarkMode,
              ),
              _buildFinansKart(
                'KDV (%20)',
                _finansalVerilerYuklendi ? '${(_kdvTutari / 1000).toStringAsFixed(1)}K TL' : 'Yükleniyor...',
                Icons.receipt_long,
                Colors.indigo,
                isDarkMode,
              ),
              _buildFinansKart(
                'Personel Payı (%25)',
                _finansalVerilerYuklendi ? '${(_personelPayi / 1000).toStringAsFixed(1)}K TL' : 'Yükleniyor...',
                Icons.account_balance_wallet,
                Colors.amber,
                isDarkMode,
              ),
              _buildFinansKart(
                'Hakediş Borcu',
                _finansalVerilerYuklendi ? '${_hakedisBorcu.toStringAsFixed(0)} TL' : 'Yükleniyor...',
                Icons.people,
                Colors.red,
                isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // DETAYLI FINANSAL BİLGİLER
          Card(
            elevation: 4,
            color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finansal Detaylar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // GELİR DETAYLARI
                  _buildFinansDetayBolumu(
                    'Gelirler',
                    [
                      _buildFinansSatir('Toplam Ciro', '${_toplamCiro.toStringAsFixed(2)} TL', Icons.attach_money),
                      _buildFinansSatir('Personel Komisyon', '${_personelPayi.toStringAsFixed(2)} TL', Icons.account_balance_wallet),
                      _buildFinansSatir('KDV Tutarı', '${_kdvTutari.toStringAsFixed(2)} TL', Icons.receipt_long),
                    ],
                    Icons.arrow_downward,
                    Colors.green,
                    isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // GİDER DETAYLARI
                  _buildFinansDetayBolumu(
                    'Giderler',
                    [
                      _buildFinansSatir('Personel Ödemeleri', '${_personelPayi.toStringAsFixed(2)} TL', Icons.people),
                      _buildFinansSatir('Hakediş Borcu', '${_hakedisBorcu.toStringAsFixed(2)} TL', Icons.warning),
                    ],
                    Icons.arrow_upward,
                    Colors.red,
                    isDarkMode,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // KAR/ZARAR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: YerimeBakColors.blue.withValues(alpha: isDarkMode ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Net Kar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.grey[800],
                              ),
                            ),
                            Text(
                              '${(_toplamCiro - _personelPayi - _kdvTutari).toStringAsFixed(2)} TL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: (_toplamCiro - _personelPayi - _kdvTutari) >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Toplam Gelir - (Personel Ödemeleri + KDV)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinansKart(String title, String value, IconData icon, Color color, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinansDetayBolumu(String title, List<Widget> items, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items,
        ],
      ),
    );
  }

  Widget _buildFinansSatir(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }
}

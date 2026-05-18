import 'package:flutter/material.dart';
import '../../models/ai/ai_rapor_ozeti_model.dart';

/// AI Analiz Özet Widget
/// Rapor özetini gösteren widget
class AIAnalizOzetWidget extends StatefulWidget {
  final AIRaporOzetiModel raporOzeti;

  const AIAnalizOzetWidget({
    super.key,
    required this.raporOzeti,
  });

  @override
  State<AIAnalizOzetWidget> createState() => _AIAnalizOzetWidgetState();
}

class _AIAnalizOzetWidgetState extends State<AIAnalizOzetWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sonuç Başlığı
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.raporOzeti.sonucRengi.withValues(alpha: 0.1),
                      widget.raporOzeti.sonucRengi.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.raporOzeti.sonucRengi.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.raporOzeti.sonucIkonu,
                        color: widget.raporOzeti.sonucRengi,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Analiz Sonucu',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.raporOzeti.genelSonuc,
                            style: TextStyle(
                              color: widget.raporOzeti.sonucRengi,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Özet Metni
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Özet',
                      style: TextStyle(
                        color: Colors.indigo.shade900,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.raporOzeti.ozetAciklama,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Değer Kartları
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _DegerKarti(
                        baslik: 'Tahmini Değer',
                        deger: widget.raporOzeti.tahminiDegerFormatli,
                        ikon: Icons.account_balance_wallet,
                        renk: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DegerKarti(
                        baslik: 'Değer Kaybı',
                        deger: widget.raporOzeti.degerKaybiFormatli,
                        ikon: Icons.trending_down,
                        renk: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DegerKarti(
                  baslik: '1 Yıllık Projeksiyon',
                  deger: widget.raporOzeti.degerProjeksiyonuFormatli,
                  ikon: Icons.show_chart,
                  renk: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              // Anahtar Bulgular
              if (widget.raporOzeti.anahtarBulgular.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anahtar Bulgular',
                        style: TextStyle(
                          color: Colors.indigo.shade900,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.raporOzeti.anahtarBulgular.map((bulgu) {
                          return Chip(
                            label: Text(
                              bulgu,
                              style: const TextStyle(fontSize: 13),
                            ),
                            backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                            labelStyle: TextStyle(
                              color: Colors.indigo.shade900,
                            ),
                            side: BorderSide(
                              color: Colors.indigo.withValues(alpha: 0.3),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // Onay/Red Önerisi
              if (widget.raporOzeti.onayRedOnerisi.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: widget.raporOzeti.isOnay
                        ? Colors.green.withValues(alpha: 0.05)
                        : widget.raporOzeti.isRed
                            ? Colors.red.withValues(alpha: 0.05)
                            : Colors.orange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.raporOzeti.isOnay
                          ? Colors.green.withValues(alpha: 0.3)
                          : widget.raporOzeti.isRed
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.raporOzeti.isOnay
                            ? Icons.thumb_up
                            : widget.raporOzeti.isRed
                                ? Icons.thumb_down
                                : Icons.warning,
                        color: widget.raporOzeti.isOnay
                            ? Colors.green
                            : widget.raporOzeti.isRed
                                ? Colors.red
                                : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.raporOzeti.onayRedOnerisi,
                          style: TextStyle(
                            color: widget.raporOzeti.isOnay
                                ? Colors.green.shade800
                                : widget.raporOzeti.isRed
                                    ? Colors.red.shade800
                                    : Colors.orange.shade800,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Değer Kartı Widget
class _DegerKarti extends StatelessWidget {
  final String baslik;
  final String deger;
  final IconData ikon;
  final Color renk;

  const _DegerKarti({
    required this.baslik,
    required this.deger,
    required this.ikon,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: renk.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ikon,
            color: renk,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            baslik,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            deger,
            style: TextStyle(
              color: renk,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

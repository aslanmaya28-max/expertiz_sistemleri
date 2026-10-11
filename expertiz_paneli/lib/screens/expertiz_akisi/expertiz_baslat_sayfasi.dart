import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/yerimebak_colors.dart';
import '../../providers/expertiz_provider.dart';
import 'adim1_sayfasi.dart';
import 'adim2_sayfasi.dart';
import 'adim3_sayfasi.dart';
import 'adim4_sayfasi.dart';
import 'adim5_sayfasi.dart';

/// Saha ekspertiz akışı (personel "Görevi Başlat" dedikten sonra açılır).
///
/// 1 Araç & Satıcı → 2 Dış → 3 İç → 4 Boya/Kaporta → 5 Kurumsal → Kaydet ve Gönder
/// Taslak otomatik olarak sunucuya kaydedilir; gönderilen rapor admin
/// panelinde "Onay Bekleyen" listesine düşer.
class ExpertizBaslatSayfasi extends StatefulWidget {
  final String gorevId;
  final String personelId;
  final String personelAdi;
  final String musteriAdi;
  final String aracPlakasi;

  const ExpertizBaslatSayfasi({
    super.key,
    required this.gorevId,
    required this.personelId,
    required this.personelAdi,
    required this.musteriAdi,
    required this.aracPlakasi,
  });

  @override
  State<ExpertizBaslatSayfasi> createState() => _ExpertizBaslatSayfasiState();
}

class _ExpertizBaslatSayfasiState extends State<ExpertizBaslatSayfasi> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _baslat());
  }

  Future<void> _baslat() async {
    await context.read<ExpertizProvider>().startGorev(
          gorevId: widget.gorevId,
          personelId: widget.personelId,
          personelAdi: widget.personelAdi,
          musteriAdi: widget.musteriAdi,
          aracPlakasi: widget.aracPlakasi,
        );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// PageView'i provider'daki adımla senkron tutar (taslak yükleme, özetten adıma gitme)
  void _sayfayiSenkronla(int step) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      final hedef = step - 1;
      if ((_pageController.page ?? 0).round() != hedef) {
        _pageController.animateToPage(hedef, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
      }
    });
  }

  void _eksikleriGoster(ExpertizProvider provider, int step) {
    final eksikler = provider.adimEksikleri(step);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${ExpertizProvider.stepTitles[step - 1]}: ${eksikler.length} eksik',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...eksikler.take(30).map((e) => ListTile(dense: true, leading: const Icon(Icons.error_outline, color: Colors.orange), title: Text(e))),
          ],
        ),
      ),
    );
  }

  Future<void> _gonder(ExpertizProvider provider) async {
    if (!provider.allStepsValid) {
      final ilkEksik = [1, 2, 3, 4, 5].firstWhere((s) => !provider.adimGecerli(s));
      provider.goToStep(ilkEksik);
      _eksikleriGoster(provider, ilkEksik);
      return;
    }
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raporu gönder'),
        content: Text(
          'Dış, iç ve boya/kaporta ekspertizi'
          '${provider.kurumsalZorunlu ? ', kurumsal ekspertiz raporu' : ''} ve '
          '${provider.toplamFotograf} fotoğraf admin onayına gönderilecek.\n\n'
          'Gönderdikten sonra değişiklik yapamazsınız. Emin misiniz?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Kontrol Et')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Kaydet ve Gönder'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;

    final basarili = await provider.completeGorev();
    if (!mounted) return;
    if (basarili) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Rapor kaydedildi ve admin onayına gönderildi 🚀'),
        backgroundColor: YerimeBakColors.green,
        duration: Duration(seconds: 3),
      ));
      Navigator.pop(context, true);
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Gönderilemedi'),
          content: Text(provider.submitError ?? 'Bilinmeyen hata'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    _sayfayiSenkronla(provider.currentStep);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Ekrandan çıkarken bekleyen taslağı hemen kaydet
        if (didPop && provider.duzenlenebilir) provider.taslagiKaydet();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            ExpertizProvider.stepTitles[provider.currentStep - 1],
            style: const TextStyle(color: YerimeBakColors.blue),
          ),
          backgroundColor: Colors.white,
          foregroundColor: YerimeBakColors.blue,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: _TaslakDurumu(provider: provider)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '%${(provider.completionPercentage * 100).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: YerimeBakColors.blue),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: provider.completionPercentage,
              backgroundColor: YerimeBakColors.lightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(YerimeBakColors.blue),
            ),
          ),
        ),
        body: _govde(provider),
      ),
    );
  }

  Widget _govde(ExpertizProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: YerimeBakColors.red),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _baslat, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        _GorevBilgisi(provider: provider),
        if (provider.redNedeni != null && provider.duzenlenebilir)
          MaterialBanner(
            backgroundColor: Colors.red.withValues(alpha: .08),
            leading: const Icon(Icons.assignment_return, color: Colors.red),
            content: Text('Admin düzeltme istedi: ${provider.redNedeni}'),
            actions: const [SizedBox.shrink()],
          ),
        if (!provider.duzenlenebilir)
          MaterialBanner(
            backgroundColor: Colors.blue.withValues(alpha: .08),
            leading: const Icon(Icons.lock_outline, color: Colors.blue),
            content: const Text('Bu rapor gönderildi; admin onayı bekleniyor. Sadece görüntüleme modundasınız.'),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              Adim1Sayfasi(),
              Adim2Sayfasi(),
              Adim3Sayfasi(),
              Adim4Sayfasi(),
              Adim5Sayfasi(),
            ],
          ),
        ),
        _AltNavigasyon(
          provider: provider,
          onEksikler: () => _eksikleriGoster(provider, provider.currentStep),
          onGonder: () => _gonder(provider),
        ),
      ],
    );
  }
}

class _TaslakDurumu extends StatelessWidget {
  final ExpertizProvider provider;
  const _TaslakDurumu({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.duzenlenebilir) {
      return const Text('Gönderildi', style: TextStyle(fontSize: 12, color: Colors.blue));
    }
    if (provider.taslakKaydediliyor) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 6),
          Text('Kaydediliyor', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
    }
    if (provider.taslakHatasi != null) {
      return Tooltip(
        message: provider.taslakHatasi!,
        child: TextButton.icon(
          onPressed: provider.taslagiKaydet,
          icon: const Icon(Icons.cloud_off, size: 16, color: Colors.red),
          label: const Text('Kaydedilemedi', style: TextStyle(fontSize: 12, color: Colors.red)),
        ),
      );
    }
    final zaman = provider.taslakKayitZamani;
    return Text(
      zaman == null ? '' : 'Kaydedildi ${DateFormat('HH:mm').format(zaman.toLocal())}',
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }
}

class _GorevBilgisi extends StatelessWidget {
  final ExpertizProvider provider;
  const _GorevBilgisi({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: YerimeBakColors.lightGray,
      child: Wrap(
        spacing: 20,
        runSpacing: 4,
        children: [
          _bilgi(Icons.directions_car, provider.adim1Model?.plaka.isNotEmpty == true ? provider.adim1Model!.plaka : (provider.aracPlakasi ?? '-')),
          _bilgi(Icons.person, 'Müşteri: ${provider.musteriAdi ?? '-'}'),
          _bilgi(Icons.badge, 'Personel: ${provider.personelAdi ?? '-'}'),
          if (provider.kurumsalZorunlu) _bilgi(Icons.business, 'Kurumsal: ${provider.kurumsalFirma}'),
        ],
      ),
    );
  }

  Widget _bilgi(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
      ],
    );
  }
}

class _AltNavigasyon extends StatelessWidget {
  final ExpertizProvider provider;
  final VoidCallback onEksikler;
  final VoidCallback onGonder;

  const _AltNavigasyon({required this.provider, required this.onEksikler, required this.onGonder});

  @override
  Widget build(BuildContext context) {
    final step = provider.currentStep;
    final gecerli = provider.currentStepValid;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final s = index + 1;
                final aktif = s == step;
                final tamam = provider.adimGecerli(s);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => provider.goToStep(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: aktif
                            ? YerimeBakColors.blue
                            : tamam
                                ? YerimeBakColors.green.withValues(alpha: .15)
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${ExpertizProvider.stepIcons[index]} $s',
                        style: TextStyle(
                          color: aktif ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: step > 1 ? provider.previousStep : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Geri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: step < 5
                      ? FilledButton.icon(
                          onPressed: gecerli ? provider.nextStep : onEksikler,
                          style: FilledButton.styleFrom(
                            backgroundColor: gecerli ? YerimeBakColors.blue : Colors.grey.shade500,
                          ),
                          icon: Icon(gecerli ? Icons.arrow_forward : Icons.checklist),
                          label: Text(gecerli ? 'İleri' : 'Eksikleri Gör'),
                        )
                      : FilledButton.icon(
                          onPressed: !provider.duzenlenebilir || provider.isSubmitting ? null : onGonder,
                          style: FilledButton.styleFrom(backgroundColor: YerimeBakColors.green),
                          icon: provider.isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send),
                          label: const Text('KAYDET VE GÖNDER'),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

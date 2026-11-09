import 'package:yerimebak_sistemleri/bilesenler/yb_iskelet.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/expertiz_provider.dart';
import 'adim1_sayfasi.dart';
import 'adim2_sayfasi.dart';
import 'adim3_sayfasi.dart';
import 'adim4_sayfasi.dart';
import 'adim5_sayfasi.dart';
import 'saha_raporu_temasi.dart';

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
        _pageController.animateToPage(hedef,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut);
      }
    });
  }

  void _eksikleriGoster(
      BuildContext reportContext, ExpertizProvider provider, int step) {
    final eksikler = provider.adimEksikleri(step);
    showModalBottomSheet<void>(
      context: reportContext,
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
            ...eksikler.take(30).map((e) => ListTile(
                dense: true,
                leading: Icon(LucideIcons.circleAlert, color: context.renkler.uyari),
                title: Text(e))),
          ],
        ),
      ),
    );
  }

  Future<void> _gonder(
      BuildContext reportContext, ExpertizProvider provider) async {
    if (!provider.allStepsValid) {
      final ilkEksik =
          [1, 2, 3, 4, 5].firstWhere((s) => !provider.adimGecerli(s));
      provider.goToStep(ilkEksik);
      _eksikleriGoster(reportContext, provider, ilkEksik);
      return;
    }
    final onay = await showDialog<bool>(
      context: reportContext,
      builder: (ctx) => AlertDialog(
        title: const Text('Raporu gönder'),
        content: Text(
          'Dış, iç ve boya/kaporta ekspertizi'
          '${provider.kurumsalZorunlu ? ', kurumsal ekspertiz raporu' : ''} ve '
          '${provider.toplamFotograf} fotoğraf admin onayına gönderilecek.\n\n'
          'Gönderdikten sonra değişiklik yapamazsınız. Emin misiniz?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kontrol Et')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(LucideIcons.send),
            label: const Text('Kaydet ve Gönder'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted || !reportContext.mounted) return;

    final basarili = await provider.completeGorev();
    if (!mounted || !reportContext.mounted) return;
    if (basarili) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Rapor kaydedildi ve admin onayına gönderildi'),
        backgroundColor: context.renkler.birincilMetin,
        duration: Duration(seconds: 3),
      ));
      Navigator.pop(context, true);
    } else {
      await showDialog<void>(
        context: reportContext,
        builder: (ctx) => AlertDialog(
          title: const Text('Gönderilemedi'),
          content: Text(provider.submitError ?? 'Bilinmeyen hata'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    _sayfayiSenkronla(provider.currentStep);

    return Theme(
      data: SahaRaporuTemasi.data,
      child: Builder(
          builder: (reportContext) => PopScope(
                onPopInvokedWithResult: (didPop, _) {
                  // Ekrandan çıkarken bekleyen taslağı hemen kaydet
                  if (didPop && provider.duzenlenebilir) {
                    provider.taslagiKaydet();
                  }
                },
                child: Scaffold(
                  appBar: AppBar(
                    title: Text(
                      ExpertizProvider.stepTitles[provider.currentStep - 1],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: reportContext.renkler.birincil, fontSize: 18),
                    ),
                    backgroundColor: reportContext.renkler.yuzey,
                    foregroundColor: reportContext.renkler.birincil,
                    elevation: 0,
                    actions: [
                      if (MediaQuery.sizeOf(reportContext).width >= 600)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child:
                              Center(child: _TaslakDurumu(provider: provider)),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Text(
                            '%${(provider.completionPercentage * 100).toStringAsFixed(0)}',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: reportContext.renkler.birincil),
                          ),
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(4),
                      child: LinearProgressIndicator(
                        value: provider.completionPercentage,
                        backgroundColor: reportContext.renkler.yuzeyIkincil,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            reportContext.renkler.birincil),
                      ),
                    ),
                  ),
                  body: _govde(provider, reportContext),
                ),
              )),
    );
  }

  Widget _govde(ExpertizProvider provider, BuildContext reportContext) {
    if (provider.isLoading) {
      return const Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [YbIskelet(height: 24), SizedBox(height: 16), YbIskelet(height: 120)]));
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.cloudOff, size: 56, color: context.renkler.tehlike),
              const SizedBox(height: 12),
              Text(provider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: _baslat,
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Tekrar Dene')),
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
            backgroundColor: context.renkler.tehlike.withValues(alpha: .08),
            leading: Icon(LucideIcons.undo2, color: context.renkler.tehlike),
            content: Text('Admin düzeltme istedi: ${provider.redNedeni}'),
            actions: const [SizedBox.shrink()],
          ),
        if (!provider.duzenlenebilir)
          MaterialBanner(
            backgroundColor: context.renkler.birincil.withValues(alpha: .08),
            leading: Icon(LucideIcons.lockKeyhole, color: context.renkler.birincil),
            content: const Text(
                'Bu rapor gönderildi; admin onayı bekleniyor. Sadece görüntüleme modundasınız.'),
            actions: const [SizedBox.shrink()],
          ),
        Expanded(
          child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
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
                  ))),
        ),
        _AltNavigasyon(
          provider: provider,
          onEksikler: () =>
              _eksikleriGoster(reportContext, provider, provider.currentStep),
          onGonder: () => _gonder(reportContext, provider),
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
      return Text('Gönderildi',
          style: TextStyle(fontSize: 12, color: context.renkler.birincil));
    }
    if (provider.taslakKaydediliyor) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 6),
          Text('Kaydediliyor',
              style: TextStyle(fontSize: 12, color: context.renkler.metinIkincil)),
        ],
      );
    }
    if (provider.taslakHatasi != null) {
      return Tooltip(
        message: provider.taslakHatasi!,
        child: TextButton.icon(
          onPressed: provider.taslagiKaydet,
          icon: Icon(LucideIcons.cloudOff, size: 16, color: context.renkler.tehlike),
          label: Text('Kaydedilemedi',
              style: TextStyle(fontSize: 12, color: context.renkler.tehlike)),
        ),
      );
    }
    final zaman = provider.taslakKayitZamani;
    return Text(
      zaman == null
          ? ''
          : 'Kaydedildi ${DateFormat('HH:mm').format(zaman.toLocal())}',
      style: TextStyle(fontSize: 12, color: context.renkler.metinIkincil),
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
      color: context.renkler.yuzeyIkincil,
      child: Wrap(
        spacing: 20,
        runSpacing: 4,
        children: [
          _bilgi(context, 
              LucideIcons.car,
              provider.adim1Model?.plaka.isNotEmpty == true
                  ? provider.adim1Model!.plaka
                  : (provider.aracPlakasi ?? '-')),
          _bilgi(context, LucideIcons.userRound, 'Müşteri: ${provider.musteriAdi ?? '-'}'),
          _bilgi(context, LucideIcons.idCard, 'Personel: ${provider.personelAdi ?? '-'}'),
          if (provider.kurumsalZorunlu)
            _bilgi(context, LucideIcons.building2, 'Kurumsal: ${provider.kurumsalFirma}'),
          if (MediaQuery.sizeOf(context).width < 600)
            _TaslakDurumu(provider: provider),
        ],
      ),
    );
  }

  Widget _bilgi(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.renkler.metinIkincil),
        const SizedBox(width: 4),
        Flexible(
            child: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: context.renkler.metinIkincil))),
      ],
    );
  }
}

class _AltNavigasyon extends StatelessWidget {
  final ExpertizProvider provider;
  final VoidCallback onEksikler;
  final VoidCallback onGonder;

  const _AltNavigasyon(
      {required this.provider,
      required this.onEksikler,
      required this.onGonder});

  @override
  Widget build(BuildContext context) {
    final step = provider.currentStep;
    final gecerli = provider.currentStepValid;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: context.renkler.yuzey,
          border: Border(top: BorderSide(color: context.renkler.kenarlik)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final s = index + 1;
                        final aktif = s == step;
                        final tamam = provider.adimGecerli(s);
                        return Expanded(
                            child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => provider.goToStep(s),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 44),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 6),
                              decoration: BoxDecoration(
                                color: aktif
                                    ? context.renkler.birincil
                                    : tamam
                                        ? context.renkler.birincilMetin
                                            .withValues(alpha: .15)
                                        : context.renkler.yuzeyIkincil,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$s',
                                style: TextStyle(
                                  color: aktif ? context.renkler.birincilUstu : context.renkler.metin,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ));
                      }),
                    ))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: step > 1 ? provider.previousStep : null,
                    icon: const Icon(LucideIcons.arrowLeft),
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
                            backgroundColor: gecerli
                                ? context.renkler.birincil
                                : context.renkler.uyariYuzey,
                            foregroundColor: gecerli
                                ? context.renkler.birincilUstu
                                : context.renkler.uyari,
                          ),
                          icon: Icon(
                              gecerli ? LucideIcons.arrowRight : LucideIcons.listChecks),
                          label: Text(gecerli ? 'İleri' : 'Eksikleri Gör'),
                        )
                      : FilledButton.icon(
                          onPressed:
                              !provider.duzenlenebilir || provider.isSubmitting
                                  ? null
                                  : onGonder,
                          style: FilledButton.styleFrom(
                              backgroundColor: context.renkler.birincilMetin,
                              foregroundColor: context.renkler.birincilUstu),
                          icon: provider.isSubmitting
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: context.renkler.birincilUstu),
                                )
                              : const Icon(LucideIcons.send),
                          label: const Text('Kaydet ve Gönder',
                              textAlign: TextAlign.center),
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

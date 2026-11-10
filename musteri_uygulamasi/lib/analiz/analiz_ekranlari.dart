import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../api/api_client.dart';
import '../api/providers.dart';
import '../bilesenler/ortak.dart';
import '../bilesenler/kaporta_semasi.dart';
import '../bilesenler/ana_buton.dart';
import '../bilesenler/ikincil_buton.dart';
import 'package:image_picker/image_picker.dart';
import '../bilesenler/kart.dart';
import '../tema/yazi.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import 'analiz_api.dart';
import 'analiz_durumu.dart';
import 'arac_formu.dart';
import 'ilan_metni.dart';

// ---------------------------------------------------------------------------
// 1) Link girişi
// ---------------------------------------------------------------------------

class AnalizBaslatEkrani extends StatelessWidget {
  const AnalizBaslatEkrani({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni araç analizi')),
    body: const SingleChildScrollView(
      child: PageBody(child: Kart(child: IlanLinkKutusu())),
    ),
  );
}

class IlanLinkKutusu extends ConsumerStatefulWidget {
  final bool sade;
  const IlanLinkKutusu({super.key, this.sade = false});
  @override
  ConsumerState<IlanLinkKutusu> createState() => _AnalizBaslatEkraniState();
}

class _AnalizBaslatEkraniState extends ConsumerState<IlanLinkKutusu> {
  final link = TextEditingController();
  String? hata;

  @override
  void dispose() {
    link.dispose();
    super.dispose();
  }

  Future<void> yapistir() async {
    final pano = await Clipboard.getData(Clipboard.kTextPlain);
    final metin = pano?.text ?? '';
    final uri = paylasimdanLink(metin);
    setState(() {
      link.text = uri?.toString() ?? metin.trim();
      hata = null;
    });
  }

  void oku() {
    final uri = paylasimdanLink(link.text);
    if (uri == null) {
      setState(
        () =>
            hata = 'Geçerli bir ilan linki yapıştırın (https://… ile başlar).',
      );
      return;
    }
    context.push(
      '/analiz/oku?link=${Uri.encodeQueryComponent(uri.toString())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.sade) ...[
              const Text('İlan linkini yapıştırın', style: Yazilar.bolumBaslik),
              const SizedBox(height: Olcu.s12),
            ],
            Text(
              widget.sade
                  ? 'İlan linkini yapıştırın; bilgileri okuyalım.'
                  : 'Araç bilgilerini ilandan biz okuyalım; siz yalnız kontrol edin.',
              style: TextStyle(color: r.metinIkincil),
            ),
            const SizedBox(height: Olcu.s16),
            TextField(
              controller: link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'İlan linki',
                hintText: 'sahibinden.com veya arabam.com',
                errorText: hata,
                suffixIcon: TextButton(
                  onPressed: yapistir,
                  child: const Text('Yapıştır'),
                ),
              ),
              onSubmitted: (_) => oku(),
            ),
            const SizedBox(height: Olcu.s16),
            AnaButon('İlanı oku', () async => oku(), icon: LucideIcons.search),
            const SizedBox(height: Olcu.s12),
            Text(
              'İlan uygulamasında Paylaş → YerimeBak ile de gönderebilirsiniz.',
              style: TextStyle(color: r.metinIkincil),
            ),
            const SizedBox(height: Olcu.s16),
            const EkranGoruntusuKutusu(),
          ],
        ),
        TextButton(
          onPressed: () {
            ref.read(analizTaslagiProvider.notifier).state = AnalizTaslagi(
              AracFormu(),
            );
            context.push('/analiz/form');
          },
          // İlanı olmayan ya da kendi aracını değerletmek isteyen müşteri için (11.11.2026).
          child: const Text('İlan yok mu? Bilgileri elle girin'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2) İlan okunuyor: önce sunucu, sonra görünmeyen WebView; doğrulama gerekirse sayfa gösterilir
// ---------------------------------------------------------------------------

enum _Asama { aciliyor, okunuyor, dolduruluyor }

class IlanOkunuyorEkrani extends ConsumerStatefulWidget {
  final String link;
  const IlanOkunuyorEkrani(this.link, {super.key});
  @override
  ConsumerState<IlanOkunuyorEkrani> createState() => _IlanOkunuyorEkraniState();
}

class _IlanOkunuyorEkraniState extends ConsumerState<IlanOkunuyorEkrani> {
  static const _sayfayiGosterme = Duration(seconds: 8),
      _vazgec = Duration(seconds: 75);
  WebViewController? web;
  Timer? yoklama;
  final sure = Stopwatch();
  _Asama asama = _Asama.aciliyor;
  bool sayfaGorunur = false, bitti = false;
  String? hata;

  Uri get uri => paylasimdanLink(widget.link)!;

  @override
  void initState() {
    super.initState();
    unawaited(_baslat());
  }

  @override
  void dispose() {
    yoklama?.cancel();
    super.dispose();
  }

  Future<void> _baslat() async {
    final repo = ref.read(analizRepositoryProvider);
    if (!sahibindenMi(uri)) {
      try {
        final od = await repo.linktenOku(uri.toString());
        if (od.yeterli) return _tamam(od);
      } on ApiFailure catch (e) {
        if (e.status == 429) return _hata(e.message);
        // Sunucu okuyamadıysa telefonda açıp okumaya geçilir.
      }
    }
    if (!mounted) return;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) {
            final s = Uri.tryParse(r.url)?.scheme;
            // Uygulama açma (intent://, sahibinden://) ve dosya adresleri engellenir; yalnız web sayfası.
            return s == 'https' || s == 'http'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageFinished: (_) {
            if (mounted && asama == _Asama.aciliyor) {
              setState(() => asama = _Asama.okunuyor);
            }
          },
        ),
      )
      ..loadRequest(uri);
    setState(() => web = c);
    sure.start();
    yoklama = Timer.periodic(const Duration(seconds: 1), (_) => _yokla());
  }

  Future<void> _yokla() async {
    final c = web;
    if (c == null || bitti) return;
    String metin;
    try {
      metin = jsSonucunuCoz(
        await c.runJavaScriptReturningResult(
          'document.body ? document.body.innerText : ""',
        ),
      );
    } catch (_) {
      return; // Sayfa geçişi sırasında okunamaz; sonraki turda tekrar denenir.
    }
    if (!mounted || bitti) return;
    switch (sayfaDurumu(metin)) {
      case SayfaDurumu.ilanHazir:
        bitti = true;
        yoklama?.cancel();
        setState(() {
          asama = _Asama.dolduruluyor;
          sayfaGorunur = false;
        });
        await _metniGonder(metin);
      case SayfaDurumu.dogrulamaGerekli:
        if (!sayfaGorunur) setState(() => sayfaGorunur = true);
      case SayfaDurumu.yukleniyor:
        if (!sayfaGorunur && sure.elapsed > _sayfayiGosterme) {
          setState(() => sayfaGorunur = true);
        }
        // Sayfa müşteriye açıkken (çerez onayı, doğrulama, başka ilana geçiş) süre sınırı işlemez.
        if (!sayfaGorunur && sure.elapsed > _vazgec) {
          bitti = true;
          yoklama?.cancel();
          _hata(
            'İlan okunamadı. İlan metnini kopyalayıp yapıştırarak devam edebilirsiniz.',
          );
        }
    }
  }

  Future<void> _metniGonder(String metin) async {
    try {
      final od = await ref
          .read(analizRepositoryProvider)
          .metindenOku(ilanMetniniKirp(metin));
      if (od.dogrulananSayisi == 0 && !od.yeterli) {
        return _hata(
          'İlandan bilgi okunamadı. İlanın ekran görüntüsünü yükleyebilir ya da bilgileri elle girebilirsiniz.',
        );
      }
      _tamam(od);
    } on ApiFailure catch (e) {
      _hata(e.message);
    }
  }

  void _tamam(OnDoldurma od) {
    if (!mounted) return;
    ref.read(analizTaslagiProvider.notifier).state = AnalizTaslagi(
      od.forma(uri.toString()),
    );
    context.pushReplacement('/analiz/form');
  }

  void _hata(String mesaj) {
    if (!mounted) return;
    setState(() {
      hata = mesaj;
      sayfaGorunur = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(sayfaGorunur ? 'İlanı doğrulayın' : 'İlan okunuyor'),
      ),
      body: Stack(
        children: [
          if (web != null)
            Positioned.fill(
              child: Column(
                children: [
                  Expanded(child: WebViewWidget(controller: web!)),
                  if (sayfaGorunur && hata == null)
                    Material(
                      color: r.yuzey,
                      elevation: Olcu.yukselti,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Olcu.sayfa,
                            Olcu.s12,
                            Olcu.sayfa,
                            Olcu.s4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sayfa bir onay ya da doğrulama istiyorsa tamamlayın. İlan sayfası açılınca okuma kendiliğinden başlar.',
                              ),
                              const SizedBox(height: Olcu.s8),
                              EkranGoruntusuDugmesi(
                                link: uri.toString(),
                                yerineGec: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (!sayfaGorunur)
            Positioned.fill(
              child: ColoredBox(
                color: r.zemin,
                child: ListView(
                  padding: const EdgeInsets.all(Olcu.metinSayfa),
                  children: [
                    Text(uri.host, style: TextStyle(color: r.metinIkincil)),
                    const SizedBox(height: Olcu.s12),
                    if (hata == null) ...[
                      Text(
                        'Birkaç saniye sürer. Bilgiler hazır olunca kontrol edip analizi başlatacaksınız.',
                        style: TextStyle(color: r.metinIkincil),
                      ),
                      const SizedBox(height: Olcu.s20),
                      AsamaListesi(const [
                        'İlan açıldı',
                        'Araç bilgileri okunuyor',
                        'Form dolduruluyor',
                      ], aktif: asama.index),
                    ] else
                      Panel('İlan okunamadı', [
                        Text(hata!),
                        const SizedBox(height: Olcu.s12),
                        EkranGoruntusuDugmesi(
                          link: uri.toString(),
                          yerineGec: true,
                        ),
                        const SizedBox(height: Olcu.s8),
                        TextButton(
                          onPressed: () {
                            ref.read(analizTaslagiProvider.notifier).state =
                                AnalizTaslagi(AracFormu(link: uri.toString()));
                            context.pushReplacement('/analiz/form');
                          },
                          child: const Text('Bilgileri elle girin'),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Numaralı aşamalar: tamamlanan ✓, aktif vurgulu, gelecek sönük (bekleme ekranlarında ortak).
class AsamaListesi extends StatelessWidget {
  final List<String> asamalar;
  final int aktif;
  const AsamaListesi(this.asamalar, {super.key, required this.aktif});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Semantics(
      liveRegion: true,
      label: asamalar[aktif.clamp(0, asamalar.length - 1)],
      child: Card(
        child: Column(
          children: [
            for (var i = 0; i < asamalar.length; i++)
              ListTile(
                leading: i < aktif
                    ? Icon(LucideIcons.circleCheck, color: r.birincil)
                    : i == aktif
                    ? SizedBox(
                        width: Olcu.ikon,
                        height: Olcu.ikon,
                        child: CircularProgressIndicator(
                          strokeWidth: Olcu.yuklemeKenar,
                          color: r.birincil,
                        ),
                      )
                    : Icon(LucideIcons.circle, color: r.girdiKenarlik),
                title: Text(
                  asamalar[i],
                  style: TextStyle(
                    fontWeight: i == aktif ? FontWeight.w600 : FontWeight.w400,
                    color: i > aktif ? r.metinIkincil : r.metin,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Ekran görüntüsünden doldurma (ilan metni yapıştırma 11.11.2026'da kaldırıldı)
// ---------------------------------------------------------------------------

/// Telefonda ilan metni kopyalanamıyor (Sahibinden): ilanın fiyat ve özellikler kısmının 1–4 ekran
/// görüntüsü yüklenir, bilgiler sunucuda okunup forma dolar (sitedeki "Ekran görüntüsü yükle", 11.11.2026).
class EkranGoruntusuKutusu extends StatelessWidget {
  const EkranGoruntusuKutusu({super.key});
  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return Container(
      padding: const EdgeInsets.all(Olcu.s12),
      decoration: BoxDecoration(
        color: r.birincilYuzey,
        borderRadius: BorderRadius.circular(Olcu.s12),
        border: Border.all(color: r.birincil.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'İlan metni kopyalanmıyor mu?',
            style: Yazilar.bolumBaslik,
          ),
          const SizedBox(height: Olcu.s4),
          Text(
            'İlanın fiyat ve özellikler kısmının ekran görüntüsünü alın (1–4 adet), buradan yükleyin; bilgileri biz okuyalım.',
            style: TextStyle(color: r.metinIkincil),
          ),
          const SizedBox(height: Olcu.s12),
          const EkranGoruntusuDugmesi(),
        ],
      ),
    );
  }
}

class EkranGoruntusuDugmesi extends ConsumerWidget {
  final String link;
  final bool yerineGec;
  const EkranGoruntusuDugmesi({
    super.key,
    this.link = '',
    this.yerineGec = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => IkincilButon(
    'Ekran görüntüsü yükle',
    () async {
      final secilen = await ImagePicker().pickMultiImage(
        limit: 4,
        maxWidth: 2000,
        maxHeight: 4000,
        imageQuality: 90,
      );
      if (secilen.isEmpty) return;
      if (secilen.length > 4) {
        throw const ApiFailure('En fazla 4 ekran görüntüsü seçin.');
      }
      final dosyalar = [
        for (final x in secilen)
          DosyaParcasi('files', x.name, await x.readAsBytes()),
      ];
      final od = await ref.read(analizRepositoryProvider).ekrandanOku(dosyalar);
      ref.read(analizTaslagiProvider.notifier).state = AnalizTaslagi(
        od.forma(link),
      );
      if (!context.mounted) return;
      if (yerineGec) {
        context.pushReplacement('/analiz/form');
      } else {
        context.push('/analiz/form');
      }
    },
    icon: LucideIcons.image,
  );
}

// ---------------------------------------------------------------------------
// 4) Araç bilgileri formu
// ---------------------------------------------------------------------------

class AracFormuEkrani extends ConsumerStatefulWidget {
  const AracFormuEkrani({super.key});
  @override
  ConsumerState<AracFormuEkrani> createState() => _AracFormuEkraniState();
}

class _AracFormuEkraniState extends ConsumerState<AracFormuEkrani> {
  late final AnalizTaslagi taslak =
      ref.read(analizTaslagiProvider) ?? AnalizTaslagi(AracFormu());
  late final AracFormu f = taslak.form;
  late final c = {
    'marka': TextEditingController(text: f.marka),
    'model': TextEditingController(text: f.model),
    'paket': TextEditingController(text: f.paket),
    'yil': TextEditingController(text: f.yil),
    'km': TextEditingController(text: binlikNokta(f.km)),
    'fiyat': TextEditingController(text: binlikNokta(f.fiyat)),
    'hp': TextEditingController(text: f.hp),
    'tramer': TextEditingController(text: binlikNokta(f.tramer)),
  };
  String? hata;

  @override
  void initState() {
    super.initState();
    // Taslak her ekran açılışında provider'da kalır; kredi yükleyip dönen müşteri formunu kaybetmez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analizTaslagiProvider.notifier).state = taslak;
    });
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  void _oku() {
    f
      ..marka = c['marka']!.text.trim()
      ..model = c['model']!.text.trim()
      ..paket = c['paket']!.text.trim()
      ..yil = sadeceRakam(c['yil']!.text, enFazlaHane: 4)
      ..km = sadeceRakam(c['km']!.text)
      ..fiyat = sadeceRakam(c['fiyat']!.text)
      ..hp = sadeceRakam(c['hp']!.text, enFazlaHane: 4)
      ..tramer = sadeceRakam(c['tramer']!.text);
  }

  Future<void> _baslat() async {
    _oku();
    final h = f.hata;
    if (h != null) {
      setState(() => hata = h);
      return;
    }
    setState(() => hata = null);
    final repo = ref.read(analizRepositoryProvider);
    try {
      final secenekler = await repo.kasaSecenekleri(f.marka, f.model, f.yil);
      if (secenekler.isNotEmpty && mounted) {
        final secim = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Olcu.metinSayfa,
                    0,
                    Olcu.metinSayfa,
                    Olcu.s12,
                  ),
                  child: Text(
                    '${f.yil} model ${f.marka} ${f.model} iki farklı kasada satıldı. İlandaki araç hangisi?',
                  ),
                ),
                for (final s in secenekler)
                  ListTile(
                    title: Text(s.ad),
                    onTap: () => Navigator.pop(ctx, s.kod),
                  ),
                ListTile(
                  title: const Text('Bilmiyorum'),
                  onTap: () => Navigator.pop(ctx, ''),
                ),
              ],
            ),
          ),
        );
        if (secim == null) return;
        f.kasa = secim.isEmpty ? null : secim;
      } else {
        f.kasa = null;
      }
    } on ApiFailure {
      f.kasa = null; // Kasa sorusu yardımcıdır; alınamazsa analiz yine yapılır.
    }
    final bakiye = await ref.read(balanceProvider.future).catchError((_) => 1);
    if (!mounted) return;
    if (bakiye < 1) {
      final git = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Krediniz yok'),
          content: const Text(
            'Analiz için 1 kredi gerekir. Kredi yükleyip bu forma geri dönebilirsiniz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kredi yükle'),
            ),
          ],
        ),
      );
      if (git == true && mounted) context.push('/kredi');
      return;
    }
    ref.read(analizTaslagiProvider.notifier).state = taslak;
    context.push('/analiz/bekle');
  }

  Widget _alan(
    String anahtar,
    String etiket, {
    TextInputType? klavye,
    String? sonEk,
    String? ipucu,
  }) {
    final r = YbRenkler.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Olcu.s12),
      child: TextField(
        controller: c[anahtar],
        keyboardType: klavye,
        decoration: InputDecoration(
          labelText: etiket,
          hintText: ipucu,
          suffixText: sonEk,
          helperText: f.ilandanOkunan.contains(anahtar)
              ? 'İlandan okundu · kontrol edin'
              : null,
          helperStyle: TextStyle(color: r.birincilMetin),
        ),
      ),
    );
  }

  Widget _secim(
    String etiket,
    String deger,
    List<String> secenekler,
    void Function(String) degisti,
    String anahtar,
  ) {
    final r = YbRenkler.of(context);
    final liste = [
      if (deger.isNotEmpty && !secenekler.contains(deger)) deger,
      ...secenekler,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Olcu.s12),
      child: DropdownButtonFormField<String>(
        initialValue: deger.isEmpty ? null : deger,
        decoration: InputDecoration(
          labelText: etiket,
          helperText: f.ilandanOkunan.contains(anahtar)
              ? 'İlandan okundu · kontrol edin'
              : null,
          helperStyle: TextStyle(color: r.birincilMetin),
        ),
        items: [
          for (final s in liste) DropdownMenuItem(value: s, child: Text(s)),
        ],
        onChanged: (v) => setState(() => degisti(v ?? '')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final parcalar = ref.watch(parcalarProvider);
    final bakiye = ref.watch(balanceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Araç bilgileri')),
      body: ListView(
        padding: const EdgeInsets.all(Olcu.sayfa),
        children: [
          if (f.ilandanOkunan.isNotEmpty)
            Card(
              color: r.birincilYuzey,
              child: ListTile(
                leading: Icon(LucideIcons.circleCheck, color: r.birincilMetin),
                title: Text(
                  'İlandan ${f.ilandanOkunan.length} bilgi okundu. Kontrol edin, eksikleri tamamlayın.',
                  style: TextStyle(color: r.metin),
                ),
              ),
            ),
          if (hata != null)
            Card(
              color: r.tehlikeYuzey,
              child: ListTile(
                title: Text(hata!, style: TextStyle(color: r.tehlike)),
              ),
            ),
          Panel('Araç', [
            KatalogAlani(
              etiket: 'Marka',
              denetleyici: c['marka']!,
              secenekler: (sorgu) => katalogAra(markalar, sorgu, sinir: 8),
              ilandan: f.ilandanOkunan.contains('marka'),
            ),
            const SizedBox(height: Olcu.s12),
            KatalogAlani(
              etiket: 'Model',
              denetleyici: c['model']!,
              secenekler: (sorgu) =>
                  katalogAra(modelleri(c['marka']!.text), sorgu, sinir: 8),
              ilandan: f.ilandanOkunan.contains('model'),
            ),
            const SizedBox(height: Olcu.s12),
            _alan(
              'paket',
              'Paket / motor',
              ipucu: 'Örn. 1.6 T-GDI Intelligent',
            ),
            _alan('yil', 'Model yılı', klavye: TextInputType.number),
            _alan('km', 'Kilometre', klavye: TextInputType.number, sonEk: 'km'),
            _secim(
              'Yakıt',
              f.yakit,
              const ['Benzin', 'Dizel', 'Hibrit', 'Elektrik', 'LPG'],
              (v) => f.yakit = v,
              'yakit',
            ),
            _secim(
              'Vites',
              f.vites,
              const ['Otomatik', 'Manuel', 'Yarı Otomatik'],
              (v) => f.vites = v,
              'vites',
            ),
            _alan(
              'hp',
              'Motor gücü (hp)',
              klavye: TextInputType.number,
              ipucu: 'İsteğe bağlı',
            ),
          ]),
          Panel('Fiyat ve hasar kaydı', [
            _alan(
              'fiyat',
              'İlan fiyatı',
              klavye: TextInputType.number,
              sonEk: 'TL',
            ),
            _alan(
              'tramer',
              'Tramer (hasar kaydı) toplamı',
              klavye: TextInputType.number,
              sonEk: 'TL',
              ipucu: 'Kayıt yoksa 0; ilanda yazmıyorsa boş',
            ),
          ]),
          Panel('Boya ve değişen', [
            Text(
              'Satıcının beyanını girin. İşaretlemediğiniz parçalar orijinal sayılır.',
              style: TextStyle(color: r.metinIkincil),
            ),
            const SizedBox(height: Olcu.s8),
            parcalar.when(
              loading: () => const LoadingView(),
              error: (e, _) =>
                  FailureView(e, () => ref.invalidate(parcalarProvider)),
              data: (liste) => KaportaSemasi(
                degerler: f.parcalar,
                onChanged: (next) => setState(() {
                  f.parcalar.clear();
                  f.parcalar.addAll(
                    Map.fromEntries(
                      next.entries.where((e) => e.value != 'orijinal'),
                    ),
                  );
                }),
              ),
            ),
          ]),
          const SizedBox(height: Olcu.s28 * 3),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Olcu.sayfa,
            Olcu.s8,
            Olcu.sayfa,
            Olcu.s12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bakiye.maybeWhen(
                  data: (b) => '1 kredi kullanılacak · Bakiyeniz $b kredi',
                  orElse: () => '1 kredi kullanılacak',
                ),
                style: TextStyle(color: r.metinIkincil),
              ),
              const SizedBox(height: Olcu.s8),
              SizedBox(
                width: double.infinity,
                height: Olcu.anaButon,
                child: ActionButton('Analizi başlat', _baslat),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Katalogdan öneren metin alanı; katalogda olmayan değer de yazıldığı gibi kabul edilir.
class KatalogAlani extends StatefulWidget {
  final String etiket;
  final TextEditingController denetleyici;
  final List<String> Function(String sorgu) secenekler;
  final bool ilandan;
  const KatalogAlani({
    super.key,
    required this.etiket,
    required this.denetleyici,
    required this.secenekler,
    this.ilandan = false,
  });
  @override
  State<KatalogAlani> createState() => _KatalogAlaniState();
}

class _KatalogAlaniState extends State<KatalogAlani> {
  final odak = FocusNode();
  @override
  void dispose() {
    odak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    return RawAutocomplete<String>(
      textEditingController: widget.denetleyici,
      focusNode: odak,
      optionsBuilder: (v) =>
          v.text.trim().isEmpty ? const <String>[] : widget.secenekler(v.text),
      fieldViewBuilder: (ctx, ctrl, odakNoktasi, gonder) => TextField(
        controller: ctrl,
        focusNode: odakNoktasi,
        onSubmitted: (_) => gonder(),
        decoration: InputDecoration(
          labelText: widget.etiket,
          helperText: widget.ilandan ? 'İlandan okundu · kontrol edin' : null,
          helperStyle: TextStyle(color: r.birincilMetin),
        ),
      ),
      optionsViewBuilder: (ctx, sec, secenekler) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: Olcu.menuYukselti,
          color: r.yuzey,
          borderRadius: BorderRadius.circular(Olcu.butonKose),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: Olcu.oneriAzamiYukseklik,
              maxWidth: Olcu.azamiIcerik - 2 * Olcu.sayfa,
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final s in secenekler)
                  ListTile(title: Text(s), onTap: () => sec(s)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5) Analiz bekleme
// ---------------------------------------------------------------------------

class AnalizBeklemeEkrani extends ConsumerStatefulWidget {
  const AnalizBeklemeEkrani({super.key});
  @override
  ConsumerState<AnalizBeklemeEkrani> createState() =>
      _AnalizBeklemeEkraniState();
}

class _AnalizBeklemeEkraniState extends ConsumerState<AnalizBeklemeEkrani> {
  static const _asamalar = [
    'Benzer ilanlar aranıyor',
    'Modelin bilinen sorunları araştırılıyor',
    'Rapor hazırlanıyor',
  ];
  static const _saniyeler = [0, 12, 35];
  final sure = Stopwatch();
  Timer? saat;
  Object? hata;
  late final AnalizTaslagi? taslak = ref.read(analizTaslagiProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_calistir());
  }

  @override
  void dispose() {
    saat?.cancel();
    super.dispose();
  }

  int get _aktif {
    final s = sure.elapsed.inSeconds;
    var a = 0;
    for (var i = 0; i < _saniyeler.length; i++) {
      if (s >= _saniyeler[i]) a = i;
    }
    return a;
  }

  Future<void> _calistir() async {
    final t = taslak;
    if (t == null) {
      setState(
        () => hata = const ApiFailure(
          'Analiz bilgileri bulunamadı. Formu yeniden doldurun.',
        ),
      );
      return;
    }
    setState(() => hata = null);
    sure
      ..reset()
      ..start();
    saat?.cancel();
    saat = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    try {
      final sonuc = await ref
          .read(analizRepositoryProvider)
          .analizEt(t.form, t.istekNo);
      saat?.cancel();
      ref.invalidate(balanceProvider);
      ref.invalidate(recentReportsProvider);
      ref.read(analizTaslagiProvider.notifier).state = null;
      if (mounted) {
        context.go('/raporlar/${Uri.encodeComponent(sonuc.raporId)}');
      }
    } catch (e) {
      saat?.cancel();
      if (mounted) setState(() => hata = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final f = taslak?.form;
    final e = hata;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor hazırlanıyor'),
        automaticallyImplyLeading: e != null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Olcu.metinSayfa),
        children: [
          if (f != null)
            Text(
              '${f.yil} ${f.marka} ${f.model} · ${binlikNokta(f.fiyat)} TL',
              style: TextStyle(color: r.metinIkincil),
            ),
          const SizedBox(height: Olcu.s16),
          if (e == null) ...[
            const Text('Genellikle 1 dakikadan kısa sürer.'),
            const SizedBox(height: Olcu.s20),
            AsamaListesi(_asamalar, aktif: _aktif),
            const SizedBox(height: Olcu.s16),
            Text(
              'Uygulamadan çıksanız da rapor hazırlanır ve Raporlarım bölümüne kaydedilir. Bağlantı koparsa krediniz iki kez düşmez.',
              style: TextStyle(color: r.metinIkincil),
            ),
          ] else if (e is InsufficientCredits)
            Panel('Krediniz yetersiz', [
              const Text(
                'Analiz için 1 kredi gerekir. Kredi yükledikten sonra formunuz kaybolmadan devam edebilirsiniz.',
              ),
              const SizedBox(height: Olcu.s12),
              FilledButton(
                onPressed: () => context.go('/kredi'),
                child: const Text('Kredi yükle'),
              ),
            ])
          else
            Panel('Rapor tamamlanamadı', [
              Text(e.toString()),
              const SizedBox(height: Olcu.s12),
              FilledButton(
                onPressed: _calistir,
                child: const Text('Tekrar dene'),
              ),
              TextButton(
                onPressed: () => context.go('/raporlar'),
                child: const Text('Raporlarım'),
              ),
            ]),
        ],
      ),
    );
  }
}

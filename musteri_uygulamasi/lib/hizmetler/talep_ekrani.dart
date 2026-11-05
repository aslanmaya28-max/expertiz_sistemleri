import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/models.dart';
import '../api/providers.dart';
import '../analiz/analiz_durumu.dart';
import '../analiz/arac_formu.dart';
import '../bilesenler/ana_buton.dart';
import '../bilesenler/ikincil_buton.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';
import 'hizmet_api.dart';
import 'hizmet_tanitim.dart';

class EkspertizTalepEkrani extends ConsumerStatefulWidget {
  final Json? arac;
  const EkspertizTalepEkrani({super.key, this.arac});
  @override
  ConsumerState<EkspertizTalepEkrani> createState() => _TalepState();
}

class _TalepState extends ConsumerState<EkspertizTalepEkrani> {
  final form = GlobalKey<FormState>();
  final c = {
    for (final key in [
      'marka',
      'model',
      'paket',
      'yil',
      'km',
      'fiyat',
      'link',
      'plaka',
      'adres',
      'zaman',
      'not',
    ])
      key: TextEditingController(),
  };
  int adim = 0;
  String? firma, paket, ilce;
  bool sozlesme = false;
  @override
  void initState() {
    super.initState();
    final a = widget.arac ?? {};
    for (final e in const {
      'marka': 'marka',
      'model': 'model',
      'paket': 'paket',
      'yil': 'yil',
      'km': 'km',
      'fiyat': 'ilanFiyati',
      'link': 'ilanUrl',
      'plaka': 'plaka',
    }.entries) {
      final value = a[e.value];
      c[e.key]!.text =
          value is num && value.isFinite && value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : text(value);
    }
  }

  @override
  void dispose() {
    for (final value in c.values) {
      value.dispose();
    }
    super.dispose();
  }

  Widget _alan(
    String key,
    String label, {
    bool zorunlu = true,
    bool sayi = false,
    int sinir = 120,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Olcu.s16),
    child: TextFormField(
      controller: c[key],
      keyboardType: sayi ? TextInputType.number : TextInputType.text,
      inputFormatters: sayi ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (zorunlu && (v == null || v.trim().isEmpty)) {
          return '$label alanını doldurun.';
        }
        if (key == 'link' && (v?.trim().isNotEmpty ?? false)) {
          final uri = Uri.tryParse(v!.trim());
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              !uri.hasAuthority ||
              uri.userInfo.isNotEmpty) {
            return 'Geçerli bir ilan bağlantısı girin.';
          }
        }
        if ((v?.length ?? 0) > sinir) return 'En fazla $sinir karakter girin.';
        return null;
      },
    ),
  );
  Future<void> _ilandanOku() async {
    final uri = Uri.tryParse(c['link']!.text.trim());
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        !uri.hasAuthority) {
      throw StateError('Geçerli bir ilan bağlantısı girin.');
    }
    final od = await ref
        .read(analizRepositoryProvider)
        .linktenOku(uri.toString());
    if (!mounted) return;
    final f = od.forma(uri.toString());
    for (final e in {
      'marka': f.marka,
      'model': f.model,
      'paket': f.paket,
      'yil': f.yil,
      'km': f.km,
      'fiyat': f.fiyat,
    }.entries) {
      if (e.value.isNotEmpty) c[e.key]!.text = e.value;
    }
    showMessage(
      context,
      'Okunan araç bilgilerini kontrol edin; eksikleri tamamlayın.',
    );
    setState(() {});
  }

  Json _govde(String firmId, String packageId) => {
    'firm_id': firmId,
    'package_id': packageId,
    'city': 'İstanbul',
    'district': ilce,
    'listing_url': c['link']!.text.trim(),
    'plate': c['plaka']!.text.trim(),
    'vehicle': {
      'brand': c['marka']!.text.trim(),
      'model': c['model']!.text.trim(),
      'package': c['paket']!.text.trim(),
      if (int.tryParse(c['yil']!.text) != null)
        'year': int.parse(c['yil']!.text),
      if (int.tryParse(c['km']!.text) != null) 'km': int.parse(c['km']!.text),
      if (int.tryParse(c['fiyat']!.text) != null)
        'price': int.parse(c['fiyat']!.text),
    },
    'note':
        'Adres: ${c['adres']!.text.trim()}\nUygun zaman: ${c['zaman']!.text.trim()}\nNot: ${c['not']!.text.trim()}',
    'contract_accepted': sozlesme,
  };
  Future<void> _ilerle(String firmId, String packageId, Json? teklif) async {
    if (!form.currentState!.validate()) return;
    if (teklif == null) {
      throw StateError('Güncel fiyat özeti yüklenmeden devam edemezsiniz.');
    }
    if (adim == 1) {
      final h = formHatasi(
        yil: c['yil']!.text,
        km: c['km']!.text,
        fiyat: c['fiyat']!.text,
      );
      if (h != null) throw StateError(h);
    }
    if (adim < 2) {
      setState(() => adim++);
      return;
    }
    if (!sozlesme) {
      throw StateError(
        'Ön Bilgilendirme Formu ve Mesafeli Satış Sözleşmesi onayı gerekiyor.',
      );
    }
    final body = _govde(firmId, packageId);
    if (text(body['note']).length > 1000) {
      throw StateError(
        'Adres, uygun zaman ve not toplamı en fazla 1000 karakter olmalı.',
      );
    }
    final checkout = await ref.read(hizmetRepositoryProvider).talep(body);
    if (!mounted) return;
    final id = text(checkout['order_id']);
    ref.invalidate(hizmetTaleplerProvider);
    if (id.isEmpty) {
      throw StateError(
        'Ödeme bilgisi okunamadı. Yeni talep göndermeden önce Taleplerim bölümünü kontrol edin.',
      );
    }
    context.go('/ekspertiz/odeme/${Uri.encodeComponent(id)}', extra: checkout);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(configProvider).valueOrNull?.expertizEnabled != true) {
      return YerindeIncelemeEkrani(arac: widget.arac);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Yerinde ekspertiz talebi')),
      body: SingleChildScrollView(
        child: PageBody(
          child: ref
              .watch(hizmetKatalogProvider)
              .when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    FailureView(e, () => ref.invalidate(hizmetKatalogProvider)),
                data: (data) {
                  final firmalar = objects(
                    data['firms'],
                  ).where((f) => objects(f['packages']).isNotEmpty).toList();
                  if (firmalar.isEmpty) {
                    return const Panel('Paketler hazırlanıyor', [
                      Text(
                        'Şu an sunulabilen firma paketi yok. Biraz sonra yeniden kontrol edin.',
                      ),
                    ]);
                  }
                  final firm = firmalar.firstWhere(
                        (f) => f['id'] == firma,
                        orElse: () => firmalar.first,
                      ),
                      packages = objects(firm['packages']);
                  final pack = packages.firstWhere(
                    (p) => p['id'] == paket,
                    orElse: () => packages.first,
                  );
                  final firmId = text(firm['id']), packId = text(pack['id']);
                  final fiyat = ref.watch(
                    hizmetTeklifProvider((firmId, packId)),
                  );
                  final teklif = fiyat.valueOrNull;
                  return Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Adım ${adim + 1} / 3 · ${['Firma ve paket', 'Araç ve randevu', 'Onay ve ödeme'][adim]}',
                          style: Yazilar.etiket,
                        ),
                        const SizedBox(height: Olcu.s16),
                        if (adim == 0)
                          Panel('Hangi firmada inceletmek istersiniz?', [
                            const Text(
                              'Anlaşmalı kurumsal ekspertiz firması aracı inceler; satıcıyla randevuyu biz ayarlarız.',
                            ),
                            const SizedBox(height: Olcu.s16),
                            DropdownButtonFormField<String>(
                              key: ValueKey('firma-$firmId'),
                              initialValue: firmId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Ekspertiz firması',
                              ),
                              items: [
                                for (final f in firmalar)
                                  DropdownMenuItem(
                                    value: text(f['id']),
                                    child: Text(text(f['name'])),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                firma = v;
                                paket = null;
                              }),
                            ),
                            const SizedBox(height: Olcu.s16),
                            DropdownButtonFormField<String>(
                              key: ValueKey('paket-$firmId-$packId'),
                              initialValue: packId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Firma paketi',
                              ),
                              items: [
                                for (final p in packages)
                                  DropdownMenuItem(
                                    value: text(p['id']),
                                    child: Text(
                                      '${text(p['name'])} · ${hizmetPara(p['price'])}',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => paket = v),
                            ),
                            const SizedBox(height: Olcu.s12),
                            BulletList(strings(pack['features'])),
                          ]),
                        if (adim == 1) ...[
                          Panel('Araç bilgileri', [
                            _alan(
                              'link',
                              'İlan bağlantısı',
                              zorunlu: false,
                              sinir: 500,
                            ),
                            IkincilButon(
                              'İlandan bilgileri getir',
                              _ilandanOku,
                            ),
                            const SizedBox(height: Olcu.s16),
                            _alan('marka', 'Marka'),
                            _alan('model', 'Model'),
                            _alan('paket', 'Paket / motor', zorunlu: false),
                            _alan('yil', 'Model yılı', sayi: true, sinir: 4),
                            _alan('km', 'Kilometre', sayi: true, sinir: 9),
                            _alan(
                              'fiyat',
                              'İlan fiyatı (TL)',
                              sayi: true,
                              sinir: 12,
                            ),
                            _alan('plaka', 'Plaka', zorunlu: false, sinir: 20),
                          ]),
                          Panel('Adres ve uygun zaman', [
                            const ValueLine('Pilot il', 'İstanbul'),
                            DropdownButtonFormField<String>(
                              initialValue: ilce,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'İlçe',
                              ),
                              items: [
                                for (final value in istanbulIlceleri)
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              onChanged: (v) => setState(() => ilce = v),
                              validator: (v) =>
                                  v == null ? 'İlçeyi seçin.' : null,
                            ),
                            const SizedBox(height: Olcu.s16),
                            _alan(
                              'adres',
                              'Aracın bulunduğu açık adres',
                              sinir: 400,
                            ),
                            _alan(
                              'zaman',
                              'Uygun gün ve saat aralığı',
                              sinir: 120,
                            ),
                            _alan('not', 'Ek not', zorunlu: false, sinir: 400),
                            const Text(
                              'Uygun zaman tercihiniz randevu onayı değildir. Satıcıyla görüşerek randevuyu netleştiririz.',
                            ),
                          ]),
                        ],
                        if (adim == 2)
                          Panel('Talebinizi kontrol edin', [
                            ValueLine(
                              'Araç',
                              '${c['marka']!.text} ${c['model']!.text} ${c['yil']!.text}',
                            ),
                            ValueLine(
                              'Konum',
                              'İstanbul / $ilce\n${c['adres']!.text}',
                            ),
                            ValueLine('Uygun zaman', c['zaman']!.text),
                            ValueLine(
                              'Firma ve paket',
                              '${firm['name']} / ${pack['name']}',
                            ),
                            const Text(
                              'Tahsilat YerimeBak tarafından tek yerden yapılır. Bu fiziksel hizmetin ödemesi PayTR ile alınır; Google Play kredisi kullanılmaz.',
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: sozlesme,
                              onChanged: (v) =>
                                  setState(() => sozlesme = v ?? false),
                              title: const Text(
                                'Ön Bilgilendirme Formu ve Mesafeli Satış Sözleşmesi’ni okudum, kabul ediyorum.',
                              ),
                            ),
                            for (final e in const {
                              'Ön Bilgilendirme Formu': 'mesafeli-satis',
                              'Mesafeli Satış Sözleşmesi': 'mesafeli-satis',
                            }.entries)
                              TextButton(
                                onPressed: () => ref
                                    .read(platformProvider)
                                    .openLink(
                                      'https://www.yerimebak.com.tr/${e.value}',
                                    ),
                                child: Text(e.key),
                              ),
                          ]),
                        fiyat.when(
                          data: (q) => Panel('Güncel fiyat özeti', [
                            HizmetFiyati(q, toplam: true),
                          ]),
                          error: (e, _) => FailureView(
                            e,
                            () => ref.invalidate(
                              hizmetTeklifProvider((firmId, packId)),
                            ),
                          ),
                          loading: () => const LoadingView(),
                        ),
                        AnaButon(
                          adim == 2 ? 'Ödemeye geç' : 'Devam et',
                          teklif == null || (adim == 2 && !sozlesme)
                              ? null
                              : () => _ilerle(firmId, packId, teklif),
                        ),
                        if (adim > 0) ...[
                          const SizedBox(height: Olcu.s12),
                          IkincilButon(
                            'Önceki adım',
                            () async => setState(() => adim--),
                          ),
                        ],
                        TextButton(
                          onPressed: () => context.push('/talepler'),
                          child: const Text('Taleplerim'),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/models.dart';
import '../api/api_client.dart';
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
import 'randevu.dart';

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
      'ilce',
      'satici_adi',
      'satici_telefon',
      'not',
    ])
      key: TextEditingController(),
  };
  int adim = 0;
  String? firma, paket, il;
  final hatalar = <String, String>{};
  bool bulunamama = false, odemesiz = false;
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
      key: ValueKey('talep-$key'),
      controller: c[key],
      forceErrorText: hatalar[key],
      onChanged: (_) => setState(() => hatalar.remove(key)),
      keyboardType: sayi
          ? TextInputType.number
          : key == 'satici_telefon'
          ? TextInputType.phone
          : TextInputType.text,
      inputFormatters: sayi ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label, errorMaxLines: 3),
      validator: (v) {
        if (zorunlu && (v == null || v.trim().isEmpty)) {
          return '$label alanını doldurun.';
        }
        if (key == 'adres' && (v?.trim().length ?? 0) < 10) {
          return 'Açık adres / buluşma noktası 10–300 karakter olmalı.';
        }
        if (key == 'satici_telefon') return saticiTelefonHatasi(v ?? '');
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
    'city': il,
    'district': c['ilce']!.text.trim(),
    'appointment_at': c['zaman']!.text,
    'address': c['adres']!.text.trim(),
    'seller_name': c['satici_adi']!.text.trim(),
    'seller_phone': c['satici_telefon']!.text.trim(),
    'not_found_accepted': bulunamama,
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
    'note': c['not']!.text.trim(),
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
    if (!bulunamama) {
      setState(
        () => hatalar['bulunamama'] =
            talepHataMetinleri['bulunamama_onayi_gerekli']!,
      );
      return;
    }
    if (!sozlesme) {
      throw StateError(
        'Ön Bilgilendirme Formu ve Mesafeli Satış Sözleşmesi onayı gerekiyor.',
      );
    }
    final body = _govde(firmId, packageId);
    Json checkout;
    try {
      checkout = await ref
          .read(hizmetRepositoryProvider)
          .talep(body, odemesiz: odemesiz);
    } on ApiFailure catch (e) {
      final alan = talepHataAlanlari[e.code];
      if (alan == null) rethrow;
      if (!mounted) return;
      setState(() {
        hatalar[alan] = talepHataMetinleri[e.code]!;
        adim = alan == 'bulunamama' ? 2 : 1;
      });
      return;
    }
    if (!mounted) return;
    if (odemesiz) {
      ref.invalidate(hizmetTaleplerProvider);
      context.go('/talepler');
      return;
    }
    final id = text(checkout['order_id']);
    ref.invalidate(hizmetTaleplerProvider);
    if (id.isEmpty) {
      throw StateError(
        'Ödeme bilgisi okunamadı. Yeni talep göndermeden önce Taleplerim bölümünü kontrol edin.',
      );
    }
    context.go('/ekspertiz/odeme/${Uri.encodeComponent(id)}', extra: checkout);
  }

  Future<void> _randevuSec() async {
    final simdi = ref.read(randevuSimdiProvider)();
    final ilk = ilkRandevu(simdi);
    final son = istanbulSaati(simdi).add(const Duration(days: 30));
    final eski = randevuOku(c['zaman']!.text);
    final baslangic = eski != null && !eski.isBefore(ilk) && !eski.isAfter(son)
        ? eski
        : ilk;
    final gun = await showDatePicker(
      context: context,
      initialDate: DateTime(baslangic.year, baslangic.month, baslangic.day),
      firstDate: DateTime(ilk.year, ilk.month, ilk.day),
      lastDate: DateTime(son.year, son.month, son.day),
      helpText: 'Randevu günü · İstanbul saati',
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: baslangic.hour, minute: baslangic.minute),
      helpText: 'Randevu saati · İstanbul',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (saat == null || !mounted) return;
    setState(() {
      c['zaman']!.text = randevuDegeri(
        DateTime.utc(gun.year, gun.month, gun.day, saat.hour, saat.minute),
      );
      hatalar.remove('zaman');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bolge = ref.watch(hizmetBolgesiProvider);
    if (bolge.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yerinde ekspertiz talebi')),
        body: const PageBody(child: LoadingView()),
      );
    }
    if (bolge.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yerinde ekspertiz talebi')),
        body: PageBody(
          child: FailureView(
            bolge.error!,
            () => ref.invalidate(hizmetBolgesiProvider),
          ),
        ),
      );
    }
    if (!ref.watch(ekspertizAcikProvider)) {
      return YerindeIncelemeEkrani(arac: widget.arac);
    }
    final iller = bolge.requireValue.iller;
    il ??= iller.firstWhere((i) => i.talepAcabilir).il;
    final ilAcik = iller.any((i) => i.il == il && i.talepAcabilir);
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
                            const Text(randevuAciklamasi),
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
                          Panel('Randevu ve iletişim', [
                            const Text(randevuAciklamasi),
                            const SizedBox(height: Olcu.s16),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('talep-il'),
                              initialValue: il,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'İl',
                                errorText: hatalar['il'],
                              ),
                              items: [
                                for (final value in iller)
                                  DropdownMenuItem(
                                    value: value.il,
                                    enabled: value.talepAcabilir,
                                    child: Text(value.etiket),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                il = v;
                                hatalar.remove('il');
                              }),
                              validator: (v) =>
                                  iller.any((i) => i.il == v && i.talepAcabilir)
                                  ? null
                                  : 'Bu ilde henüz hizmet yok.',
                            ),
                            const SizedBox(height: Olcu.s16),
                            _alan('ilce', 'İlçe', sinir: 80),
                            _alan(
                              'adres',
                              'Açık adres / buluşma noktası',
                              sinir: 300,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: Olcu.s16),
                              child: TextFormField(
                                key: const ValueKey('talep-zaman'),
                                controller: c['zaman'],
                                readOnly: true,
                                forceErrorText: hatalar['zaman'],
                                decoration: const InputDecoration(
                                  labelText:
                                      'Randevu tarihi ve saati (İstanbul)',
                                  errorMaxLines: 3,
                                  helperText:
                                      'En erken 2 saat sonra, en geç 30 gün içinde.',
                                  helperMaxLines: 2,
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                onTap: _randevuSec,
                                validator: (v) => randevuHatasi(
                                  v ?? '',
                                  ref.read(randevuSimdiProvider)(),
                                ),
                              ),
                            ),
                            _alan(
                              'satici_adi',
                              'Satıcı adı (isteğe bağlı)',
                              zorunlu: false,
                              sinir: 80,
                            ),
                            _alan(
                              'satici_telefon',
                              'Satıcı telefonu',
                              sinir: 24,
                            ),
                            _alan(
                              'not',
                              'Özel talep / not',
                              zorunlu: false,
                              sinir: 1000,
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
                              '$il / ${c['ilce']!.text}\n${c['adres']!.text}',
                            ),
                            ValueLine(
                              'Randevu',
                              randevuMetni(c['zaman']!.text),
                            ),
                            ValueLine(
                              'Firma ve paket',
                              '${firm['name']} / ${pack['name']}',
                            ),
                            ValueLine(
                              'Satıcı',
                              '${c['satici_adi']!.text} ${c['satici_telefon']!.text}'
                                  .trim(),
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
                            CheckboxListTile(
                              key: const ValueKey('bulunamama-onayi'),
                              contentPadding: EdgeInsets.zero,
                              value: bulunamama,
                              onChanged: (v) => setState(() {
                                bulunamama = v ?? false;
                                hatalar.remove('bulunamama');
                              }),
                              title: const Text(bulunamamaOnayi),
                            ),
                            if (hatalar['bulunamama'] != null)
                              Text(
                                hatalar['bulunamama']!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            if (bolge.requireValue.tester)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Ödemesiz test talebi'),
                                value: odemesiz,
                                onChanged: (v) => setState(() => odemesiz = v),
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
                        if (!ilAcik) const Text('Bu ilde henüz hizmet yok'),
                        AnaButon(
                          adim == 2
                              ? (odemesiz
                                    ? 'Test talebi oluştur'
                                    : 'Ödemeye geç')
                              : 'Devam et',
                          teklif == null ||
                                  !ilAcik ||
                                  (adim == 2 && (!sozlesme || !bulunamama))
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

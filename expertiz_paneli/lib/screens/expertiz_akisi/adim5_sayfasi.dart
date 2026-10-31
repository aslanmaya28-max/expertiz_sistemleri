import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/constants/yerimebak_colors.dart';
import '../../models/expertiz/kontrol_listesi.dart';
import '../../models/expertiz/rapor_medya.dart';
import '../../providers/expertiz_provider.dart';
import 'widgets/kontrol_listesi_widget.dart';

/// Adım 5: Kurumsal Ekspertiz ve Gönderim Özeti
///
/// Müşteri anlaşmalı bir ekspertiz firmasının paketini seçtiyse, firmanın
/// hazırladığı rapor (PDF veya fotoğraf) bu adımda dosyaya eklenir ve rapor
/// numarası girilir. Ardından "Kaydet ve Gönder" ile tüm dosya admin
/// paneline düşer.
class Adim5Sayfasi extends StatelessWidget {
  const Adim5Sayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final model = provider.adim5Model;
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final duzenlenebilir = provider.duzenlenebilir;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdimEksikleriKarti(eksikler: provider.adimEksikleri(5)),
        const SizedBox(height: 12),
        const _KurumsalRaporKarti(),
        const SizedBox(height: 16),
        _BelgeKontrolu(duzenlenebilir: duzenlenebilir),
        const SizedBox(height: 16),
        _MekanikOzet(duzenlenebilir: duzenlenebilir),
        const SizedBox(height: 16),
        _PersonelDegerlendirmesi(duzenlenebilir: duzenlenebilir),
        const SizedBox(height: 16),
        const _GonderimOzeti(),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _KurumsalRaporKarti extends StatefulWidget {
  const _KurumsalRaporKarti();

  @override
  State<_KurumsalRaporKarti> createState() => _KurumsalRaporKartiState();
}

class _KurumsalRaporKartiState extends State<_KurumsalRaporKarti> {
  late final TextEditingController _raporNo;
  late final TextEditingController _ozet;

  @override
  void initState() {
    super.initState();
    final model = context.read<ExpertizProvider>().adim5Model;
    _raporNo = TextEditingController(text: model?.kurumsalRaporNo ?? '');
    _ozet = TextEditingController(text: model?.kurumsalSonucOzeti ?? '');
  }

  @override
  void dispose() {
    _raporNo.dispose();
    _ozet.dispose();
    super.dispose();
  }

  Future<void> _yukle(List<int> bytes, String ad) async {
    final provider = context.read<ExpertizProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.kurumsalRaporYukle(bytes: bytes, dosyaAdi: ad);
      messenger.showSnackBar(const SnackBar(
        content: Text('Kurumsal rapor dosyaya eklendi'),
        backgroundColor: YerimeBakColors.green,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Yüklenemedi: $e'),
          backgroundColor: YerimeBakColors.red));
    }
  }

  Future<void> _dosyaSec() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Dosya okunamadı')));
      return;
    }
    await _yukle(bytes, file.name);
  }

  Future<void> _fotografCek() async {
    final foto = await ImagePicker().pickImage(
        source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
    if (foto == null) return;
    await _yukle(await foto.readAsBytes(),
        foto.name.isNotEmpty ? foto.name : 'kurumsal_rapor.jpg');
  }

  Future<void> _ac(RaporMedya medya) async {
    final provider = context.read<ExpertizProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (medya.resimMi) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
            child: InteractiveViewer(
                child: Image.network(provider.medyaUrl(medya)))),
      );
      return;
    }
    try {
      final bytes = await provider.api.downloadBytes(medya.url);
      await Printing.layoutPdf(
          onLayout: (_) async => Uint8List.fromList(bytes),
          name: medya.dosyaAdi ?? 'rapor.pdf');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Dosya açılamadı: $e')));
    }
  }

  Future<void> _tarihSec() async {
    final provider = context.read<ExpertizProvider>();
    final secilen = await showDatePicker(
      context: context,
      initialDate: provider.adim5Model?.kurumsalRaporTarihi ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
    );
    if (secilen != null) {
      provider.updateAdim5(
          provider.adim5Model!.copyWith(kurumsalRaporTarihi: secilen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final model = provider.adim5Model!;
    final raporlar = provider.kurumsalRaporlar;
    final zorunlu = provider.kurumsalZorunlu;
    final duzenlenebilir = provider.duzenlenebilir;
    final yukleniyor =
        provider.yukleniyor(ExpertizProvider.bolumKurumsal, 'rapor');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: zorunlu && raporlar.isEmpty
                ? Colors.red
                : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏢 Kurumsal Ekspertiz Raporu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (zorunlu) ...[
              Text(
                'Müşteri kurumsal ekspertiz talep etti: ${provider.kurumsalFirma.isEmpty ? 'Anlaşmalı firma' : provider.kurumsalFirma}'
                '${provider.kurumsalPaket.isEmpty ? '' : ' – ${provider.kurumsalPaket}'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Firmanın hazırladığı raporu (PDF veya fotoğraf) dosyaya ekleyin. Rapor eklenmeden gönderilemez.',
                style: TextStyle(fontSize: 12),
              ),
            ] else
              const Text(
                'Bu talepte kurumsal ekspertiz paketi yok. İsterseniz ek belge ekleyebilirsiniz.',
                style: TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 12),
            for (final medya in raporlar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(medya.pdfMi ? Icons.picture_as_pdf : Icons.image,
                    color: Colors.redAccent),
                title: Text(medya.dosyaAdi ?? 'Kurumsal rapor'),
                subtitle: Text(
                  medya.olusturulma == null
                      ? ''
                      : DateFormat('dd.MM.yyyy HH:mm')
                          .format(medya.olusturulma!.toLocal()),
                ),
                onTap: () => _ac(medya),
                trailing: duzenlenebilir
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await provider.medyaSil(medya);
                          } catch (e) {
                            messenger.showSnackBar(
                                SnackBar(content: Text('Silinemedi: $e')));
                          }
                        },
                      )
                    : null,
              ),
            if (duzenlenebilir)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: yukleniyor ? null : _dosyaSec,
                    icon: yukleniyor
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_file),
                    label: const Text('PDF / Dosya Ekle'),
                  ),
                  OutlinedButton.icon(
                    onPressed: yukleniyor ? null : _fotografCek,
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Kağıt Raporu Fotoğrafla'),
                  ),
                ],
              ),
            if (zorunlu) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _raporNo,
                enabled: duzenlenebilir,
                decoration: const InputDecoration(
                    labelText: 'Kurumsal rapor numarası *',
                    border: OutlineInputBorder()),
                onChanged: (v) => provider.updateAdim5(
                    provider.adim5Model!.copyWith(kurumsalRaporNo: v.trim())),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: duzenlenebilir ? _tarihSec : null,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Rapor tarihi', border: OutlineInputBorder()),
                  child: Text(
                    model.kurumsalRaporTarihi == null
                        ? 'Seçilmedi'
                        : DateFormat('dd.MM.yyyy')
                            .format(model.kurumsalRaporTarihi!),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ozet,
                enabled: duzenlenebilir,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Firma raporunun sonuç özeti',
                  hintText:
                      'Ör. motor ve şanzıman sorunsuz, ön sol çamurluk boyalı...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => provider.updateAdim5(
                    provider.adim5Model!.copyWith(kurumsalSonucOzeti: v)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BelgeKontrolu extends StatelessWidget {
  final bool duzenlenebilir;
  const _BelgeKontrolu({required this.duzenlenebilir});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final m = provider.adim5Model!;
    Widget satir(String baslik, bool? deger, void Function(bool) onChanged) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(baslik),
        subtitle: Text(
            deger == null ? 'Kontrol edilmedi' : (deger ? 'Mevcut' : 'Yok')),
        value: deger ?? false,
        onChanged: duzenlenebilir ? onChanged : null,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📁 Belge Kontrolü',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            satir('Ruhsat', m.ruhsatDosyasiVar,
                (v) => provider.updateAdim5(m.copyWith(ruhsatDosyasiVar: v))),
            satir('Bakım defteri / servis kayıtları', m.bakimDefteriVar,
                (v) => provider.updateAdim5(m.copyWith(bakimDefteriVar: v))),
            satir('Sigorta / kasko poliçesi', m.sigortaPolicesiVar,
                (v) => provider.updateAdim5(m.copyWith(sigortaPolicesiVar: v))),
            satir('Muayene belgesi', m.muayeneBelgesiVar,
                (v) => provider.updateAdim5(m.copyWith(muayeneBelgesiVar: v))),
          ],
        ),
      ),
    );
  }
}

/// Kurumsal rapordan veya sürüş testinden mekanik özet (opsiyonel)
class _MekanikOzet extends StatelessWidget {
  final bool duzenlenebilir;
  const _MekanikOzet({required this.duzenlenebilir});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final m = provider.adim5Model!;
    final satirlar = <(String, String?, void Function(String?))>[
      (
        'Motor',
        m.motorDurumu,
        (v) =>
            provider.updateAdim5(provider.adim5Model!.copyWith(motorDurumu: v))
      ),
      (
        'Şanzıman',
        m.sanzimanDurumu,
        (v) => provider
            .updateAdim5(provider.adim5Model!.copyWith(sanzimanDurumu: v))
      ),
      (
        'Fren sistemi',
        m.frenSistemi,
        (v) =>
            provider.updateAdim5(provider.adim5Model!.copyWith(frenSistemi: v))
      ),
      (
        'Direksiyon / yürüyen',
        m.direksiyonSistemi,
        (v) => provider
            .updateAdim5(provider.adim5Model!.copyWith(direksiyonSistemi: v))
      ),
      (
        'Elektrik / OBD',
        m.elektrikSistemi,
        (v) => provider
            .updateAdim5(provider.adim5Model!.copyWith(elektrikSistemi: v))
      ),
    ];
    const secenekler = [
      KontrolDurumu.iyi,
      KontrolDurumu.orta,
      KontrolDurumu.sorunlu,
      KontrolDurumu.kotu
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚙️ Mekanik Özet (opsiyonel)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Kurumsal rapordaki veya test sürüşündeki sonuçlar.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            for (final (baslik, deger, onChanged) in satirlar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: LayoutBuilder(builder: (context, constraints) {
                  final choices = Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: secenekler.map((s) {
                      final secili = deger == s;
                      return ChoiceChip(
                        label: Text(KontrolDurumu.etiket(s)),
                        selected: secili,
                        selectedColor:
                            KontrolDurumu.renk(s).withValues(alpha: .25),
                        onSelected: duzenlenebilir
                            ? (_) => onChanged(secili ? null : s)
                            : null,
                      );
                    }).toList(),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(baslik,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          choices
                        ]);
                  }
                  return Row(children: [
                    SizedBox(width: 150, child: Text(baslik)),
                    Expanded(child: choices)
                  ]);
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _PersonelDegerlendirmesi extends StatelessWidget {
  final bool duzenlenebilir;
  const _PersonelDegerlendirmesi({required this.duzenlenebilir});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final m = provider.adim5Model!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📝 Personel Değerlendirmesi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Genel puan: ${m.genelPuan == null ? 'verilmedi' : m.genelPuan!.toStringAsFixed(0)} / 100'),
            Slider(
              value: m.genelPuan ?? 0,
              min: 0,
              max: 100,
              divisions: 20,
              label: (m.genelPuan ?? 0).toStringAsFixed(0),
              onChanged: duzenlenebilir
                  ? (v) => provider.updateAdim5(m.copyWith(genelPuan: v))
                  : null,
            ),
            GenelNotAlani(
              deger: m.ozetNot ?? '',
              etiket: 'Müşteriye özet (raporda görünür)',
              duzenlenebilir: duzenlenebilir,
              onChanged: (v) => provider
                  .updateAdim5(provider.adim5Model!.copyWith(ozetNot: v)),
            ),
            const SizedBox(height: 8),
            GenelNotAlani(
              deger: m.oneriler ?? '',
              etiket: 'Öneriler',
              duzenlenebilir: duzenlenebilir,
              onChanged: (v) => provider
                  .updateAdim5(provider.adim5Model!.copyWith(oneriler: v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gönderim öncesi tüm adımların özeti
class _GonderimOzeti extends StatelessWidget {
  const _GonderimOzeti();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    return Card(
      color: YerimeBakColors.lightGray,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📤 Gönderim Özeti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (var step = 1; step <= 5; step++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  provider.adimGecerli(step)
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color:
                      provider.adimGecerli(step) ? Colors.green : Colors.orange,
                ),
                title: Text('$step. ${ExpertizProvider.stepTitles[step - 1]}'),
                subtitle: provider.adimGecerli(step)
                    ? null
                    : Text('${provider.adimEksikleri(step).length} eksik'),
                onTap: () => provider.goToStep(step),
              ),
            const Divider(),
            Text('Kaydedilen fotoğraf: ${provider.toplamFotograf}'),
            Text('Kurumsal rapor dosyası: ${provider.kurumsalRaporlar.length}'),
            if (provider.taslakKayitZamani != null)
              Text(
                'Son taslak kaydı: ${DateFormat('HH:mm:ss').format(provider.taslakKayitZamani!.toLocal())}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            const Text(
              'Alttaki "Kaydet ve Gönder" ile rapor admin paneline düşer. Gönderildikten sonra değişiklik yapılamaz; '
              'admin reddederse düzeltme için size geri döner.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

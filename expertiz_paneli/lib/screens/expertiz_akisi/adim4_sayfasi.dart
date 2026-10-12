import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/expertiz/adim4_boya_kaporta_model.dart';
import '../../models/expertiz/kontrol_listesi.dart';
import '../../providers/expertiz_provider.dart';
import 'widgets/kontrol_listesi_widget.dart';

/// Adım 4: Boya / Kaporta Ekspertizi
///
/// - 13 kaporta parçası için: Orijinal / Lokal Boyalı / Boyalı / Değişen /
///   Sökülüp Takılmış / Hasarlı + opsiyonel boya kalınlığı (mikron)
/// - Şasi, direkler, podye, marşpiyel, bagaj havuzu: Orijinal / İşlemli / Hasarlı
/// - Ek hasar kayıtları (çizik, göçük, pas ...)
/// Orijinal olmayan her parça ve işlemli/hasarlı yapısal eleman için fotoğraf zorunludur.
class Adim4Sayfasi extends StatelessWidget {
  const Adim4Sayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final model = provider.adim4Model;
    if (model == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final duzenlenebilir = provider.duzenlenebilir;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdimEksikleriKarti(eksikler: provider.adimEksikleri(4)),
        const SizedBox(height: 12),
        _BoyaOzeti(model: model),
        const SizedBox(height: 12),
        KontrolListesiBolumu(
          baslik: '🎨 Kaporta Parçaları',
          bolum: ExpertizProvider.bolumBoya,
          maddeler: Adim4BoyaKaportaModel.parcalar,
          secenekler: DurumSecenekleri.parca,
          duzenlenebilir: duzenlenebilir,
          durum: (key) => model.parcaDurumlari[key],
          onDurum: (key, durum) => provider.updateAdim4(provider.adim4Model!.withParca(key, durum)),
          not: model.not,
          onNot: (key, not) => provider.updateAdim4(provider.adim4Model!.withNot(key, not)),
          onToplu: (toplu) => provider.updateAdim4(
            provider.adim4Model!.copyWith(parcaDurumlari: {...provider.adim4Model!.parcaDurumlari, ...toplu}),
          ),
          ekAlan: (madde) => _MikronAlani(
            key: ValueKey('mikron-${madde.key}'),
            deger: model.mikronlar[madde.key],
            duzenlenebilir: duzenlenebilir,
            onChanged: (value) => provider.updateAdim4(provider.adim4Model!.withMikron(madde.key, value)),
          ),
        ),
        const SizedBox(height: 20),
        KontrolListesiBolumu(
          baslik: '🔩 Şasi ve Yapısal Elemanlar',
          bolum: ExpertizProvider.bolumBoya,
          maddeler: Adim4BoyaKaportaModel.yapisal,
          secenekler: DurumSecenekleri.yapisal,
          duzenlenebilir: duzenlenebilir,
          durum: (key) => model.yapisalDurumlar[key],
          onDurum: (key, durum) => provider.updateAdim4(provider.adim4Model!.withYapisal(key, durum)),
          not: model.not,
          onNot: (key, not) => provider.updateAdim4(provider.adim4Model!.withNot(key, not)),
          onToplu: (toplu) => provider.updateAdim4(
            provider.adim4Model!.copyWith(yapisalDurumlar: {...provider.adim4Model!.yapisalDurumlar, ...toplu}),
          ),
        ),
        const SizedBox(height: 20),
        _EkHasarKayitlari(model: model, duzenlenebilir: duzenlenebilir),
        const SizedBox(height: 16),
        GenelNotAlani(
          deger: model.genelNot ?? '',
          etiket: 'Boya / kaporta genel notu',
          duzenlenebilir: duzenlenebilir,
          onChanged: (value) => provider.updateAdim4(provider.adim4Model!.copyWith(genelNot: value)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Boyalı / değişen parça özeti
class _BoyaOzeti extends StatelessWidget {
  final Adim4BoyaKaportaModel model;
  const _BoyaOzeti({required this.model});

  @override
  Widget build(BuildContext context) {
    final boyali = model.boyaliParcalar;
    final degisen = model.degisenParcalar;
    final hasarli = Adim4BoyaKaportaModel.parcalar
        .where((p) => model.parcaDurumlari[p.key] == ParcaDurumu.hasarli)
        .map((p) => p.label)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Özet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Boyalı: ${boyali.isEmpty ? '-' : boyali.join(', ')}'),
            Text('Değişen: ${degisen.isEmpty ? '-' : degisen.join(', ')}'),
            Text('Hasarlı: ${hasarli.isEmpty ? '-' : hasarli.join(', ')}'),
            Text('Ek hasar kaydı: ${model.hasarKayitlari.length}'),
          ],
        ),
      ),
    );
  }
}

/// Boya kalınlığı (mikron) girişi
class _MikronAlani extends StatefulWidget {
  final int? deger;
  final bool duzenlenebilir;
  final ValueChanged<int?> onChanged;

  const _MikronAlani({super.key, required this.deger, required this.duzenlenebilir, required this.onChanged});

  @override
  State<_MikronAlani> createState() => _MikronAlaniState();
}

class _MikronAlaniState extends State<_MikronAlani> {
  late final TextEditingController _controller = TextEditingController(text: widget.deger?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: _controller,
        enabled: widget.duzenlenebilir,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Boya kalınlığı (μm, opsiyonel)',
          helperText: 'Orijinal genelde 90-160 μm',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => widget.onChanged(int.tryParse(value)),
      ),
    );
  }
}

/// Parça listesinde olmayan ek hasarlar (pas, göçük, alt hasarı ...)
class _EkHasarKayitlari extends StatelessWidget {
  final Adim4BoyaKaportaModel model;
  final bool duzenlenebilir;

  const _EkHasarKayitlari({required this.model, required this.duzenlenebilir});

  Future<void> _ekle(BuildContext context) async {
    final provider = context.read<ExpertizProvider>();
    final konumController = TextEditingController();
    final notController = TextEditingController();
    String tip = Adim4BoyaKaportaModel.hasarTipleri.first;
    String buyukluk = Adim4BoyaKaportaModel.hasarBuyuklukleri.first;

    final kaydet = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Ek hasar kaydı'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: konumController,
                  decoration: const InputDecoration(labelText: 'Konum (ör. sağ arka jant, alt koruma)'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tip,
                  decoration: const InputDecoration(labelText: 'Hasar tipi'),
                  items: Adim4BoyaKaportaModel.hasarTipleri
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => tip = v ?? tip),
                ),
                DropdownButtonFormField<String>(
                  initialValue: buyukluk,
                  decoration: const InputDecoration(labelText: 'Büyüklük'),
                  items: Adim4BoyaKaportaModel.hasarBuyuklukleri
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() => buyukluk = v ?? buyukluk),
                ),
                TextField(controller: notController, decoration: const InputDecoration(labelText: 'Not')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(
              onPressed: () {
                if (konumController.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
    if (kaydet == true) {
      final model = provider.adim4Model!;
      provider.updateAdim4(model.hasarEkle(HasarKaydi(
        id: 'hasar_${DateTime.now().millisecondsSinceEpoch}',
        konum: konumController.text.trim(),
        tip: tip,
        buyukluk: buyukluk,
        not: notController.text.trim().isEmpty ? null : notController.text.trim(),
      )));
    }
    konumController.dispose();
    notController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '⚠️ Ek Hasar Kayıtları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            if (duzenlenebilir)
              TextButton.icon(
                onPressed: () => _ekle(context),
                icon: const Icon(Icons.add),
                label: const Text('Hasar Ekle'),
              ),
          ],
        ),
        if (model.hasarKayitlari.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Parça listesi dışında ek hasar yok.'),
          )
        else if (duzenlenebilir)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Her hasar için fotoğraf zorunludur. Kaydı silmek için "Hasarlı" etiketine tekrar dokunun.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        for (final hasar in model.hasarKayitlari)
          KontrolMaddesiKarti(
            key: ValueKey('hasar-${hasar.id}'),
            madde: KontrolMaddesi(hasar.id, '${hasar.konum} – ${hasar.tip} (${hasar.buyukluk})', 'Ek Hasar'),
            bolum: ExpertizProvider.bolumBoya,
            secenekler: const DurumSecenekleri(
              degerler: [ParcaDurumu.hasarli],
              etiket: ParcaDurumu.etiket,
              renk: ParcaDurumu.renk,
              eksiklikMi: ParcaDurumu.eksiklikMi,
              varsayilan: ParcaDurumu.hasarli,
            ),
            seciliDurum: ParcaDurumu.hasarli,
            onDurum: (durum) {
              if (durum == null && duzenlenebilir) {
                provider.updateAdim4(provider.adim4Model!.hasarSil(hasar.id));
              }
            },
            not: hasar.not ?? '',
            onNot: (not) => provider.updateAdim4(
              provider.adim4Model!.hasarGuncelle(hasar.id, hasar.copyWith(not: not)),
            ),
            duzenlenebilir: duzenlenebilir,
          ),
      ],
    );
  }
}

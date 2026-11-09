import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/expertiz/kontrol_listesi.dart';
import '../../../models/expertiz/rapor_medya.dart';
import '../../../providers/expertiz_provider.dart';

/// Durum seçeneği tanımı (dış/iç: KontrolDurumu, boya: ParcaDurumu ...)
class DurumSecenekleri {
  final List<String> degerler;
  final String Function(String?) etiket;
  final Color Function(String?) renk;
  final bool Function(String?) eksiklikMi;

  /// "Seçilmemişleri ... işaretle" kısayolunda kullanılacak değer
  final String varsayilan;

  const DurumSecenekleri({
    required this.degerler,
    required this.etiket,
    required this.renk,
    required this.eksiklikMi,
    required this.varsayilan,
  });

  /// Durumun iş anlamını değiştirmeden tema karşılığını seçer.
  Color temaRengi(BuildContext context, String? durum) {
    final r = context.renkler;
    return switch (durum) {
      'mukemmel' || 'iyi' || 'orijinal' => r.birincilMetin,
      'orta' || 'sorunlu' || 'islemli' => r.uyari,
      'kotu' || 'agirHasar' || 'hasarli' => r.tehlike,
      'lokal_boyali' => r.lokalKenar,
      'boyali' => r.boyaliKenar,
      'degisen' => r.degisenYuzey,
      'sokulup_takilmis' => r.bilgi,
      _ => r.metinIkincil,
    };
  }

  static const kontrol = DurumSecenekleri(
    degerler: KontrolDurumu.secenekler,
    etiket: KontrolDurumu.etiket,
    renk: KontrolDurumu.renk,
    eksiklikMi: KontrolDurumu.eksiklikMi,
    varsayilan: KontrolDurumu.iyi,
  );

  static const parca = DurumSecenekleri(
    degerler: ParcaDurumu.secenekler,
    etiket: ParcaDurumu.etiket,
    renk: ParcaDurumu.renk,
    eksiklikMi: ParcaDurumu.eksiklikMi,
    varsayilan: ParcaDurumu.orijinal,
  );

  static const yapisal = DurumSecenekleri(
    degerler: YapisalDurum.secenekler,
    etiket: YapisalDurum.etiket,
    renk: YapisalDurum.renk,
    eksiklikMi: YapisalDurum.eksiklikMi,
    varsayilan: YapisalDurum.orijinal,
  );
}

/// Bir kontrol listesini (gruplu) çizer: durum seçimi, not ve fotoğraflar.
class KontrolListesiBolumu extends StatelessWidget {
  final String baslik;
  final String bolum;
  final List<KontrolMaddesi> maddeler;
  final DurumSecenekleri secenekler;
  final String? Function(String key) durum;
  final void Function(String key, String? durum) onDurum;
  final String Function(String key) not;
  final void Function(String key, String not) onNot;
  final void Function(Map<String, String> topluDurumlar)? onToplu;
  final Widget Function(KontrolMaddesi madde)? ekAlan;
  final bool duzenlenebilir;

  const KontrolListesiBolumu({
    super.key,
    required this.baslik,
    required this.bolum,
    required this.maddeler,
    required this.secenekler,
    required this.durum,
    required this.onDurum,
    required this.not,
    required this.onNot,
    this.onToplu,
    this.ekAlan,
    this.duzenlenebilir = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final secilen = maddeler.where((m) => durum(m.key) != null).length;
    final eksiklikli =
        maddeler.where((m) => secenekler.eksiklikMi(durum(m.key))).toList();
    final fotoEksik = eksiklikli
        .where((m) => provider.fotograflar(bolum, m.key).isEmpty)
        .length;
    final secilmemis = maddeler.where((m) => durum(m.key) == null).toList();

    final gruplar = <String, List<KontrolMaddesi>>{};
    for (final m in maddeler) {
      gruplar.putIfAbsent(m.grup, () => []).add(m);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                baslik,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.renkler.birincil),
              ),
            ),
            Text('$secilen / ${maddeler.length}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (eksiklikli.isNotEmpty)
              Chip(
                avatar: Icon(LucideIcons.triangleAlert,
                    size: 16, color: context.renkler.uyari),
                label: Text('${eksiklikli.length} eksiklik'),
                visualDensity: VisualDensity.compact,
              ),
            if (fotoEksik > 0)
              Chip(
                avatar:
                    Icon(LucideIcons.camera, size: 16, color: context.renkler.tehlike),
                label: Text('$fotoEksik maddede fotoğraf gerekli'),
                backgroundColor: context.renkler.tehlike.withValues(alpha: .08),
                visualDensity: VisualDensity.compact,
              ),
            if (duzenlenebilir && onToplu != null && secilmemis.isNotEmpty)
              ActionChip(
                avatar: const Icon(LucideIcons.checkCheck, size: 16),
                label: Text(
                    'Kalan ${secilmemis.length} maddeyi "${secenekler.etiket(secenekler.varsayilan)}" işaretle'),
                onPressed: () async {
                  final onay = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Toplu işaretleme'),
                      content: Text(
                        'Durumu seçilmemiş ${secilmemis.length} madde "${secenekler.etiket(secenekler.varsayilan)}" '
                        'olarak işaretlenecek. Sadece gerçekten kontrol ettiğiniz maddeler için kullanın.',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Vazgeç')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('İşaretle')),
                      ],
                    ),
                  );
                  if (onay == true) {
                    onToplu!({
                      for (final m in secilmemis) m.key: secenekler.varsayilan
                    });
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in gruplar.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: context.renkler.metinIkincil,
              ),
            ),
          ),
          for (final madde in entry.value)
            KontrolMaddesiKarti(
              key: ValueKey('$bolum-${madde.key}'),
              madde: madde,
              bolum: bolum,
              secenekler: secenekler,
              seciliDurum: durum(madde.key),
              onDurum: (d) => onDurum(madde.key, d),
              not: not(madde.key),
              onNot: (n) => onNot(madde.key, n),
              ekAlan: ekAlan?.call(madde),
              duzenlenebilir: duzenlenebilir,
            ),
        ],
      ],
    );
  }
}

/// Tek bir kontrol maddesi kartı.
class KontrolMaddesiKarti extends StatefulWidget {
  final KontrolMaddesi madde;
  final String bolum;
  final DurumSecenekleri secenekler;
  final String? seciliDurum;
  final ValueChanged<String?> onDurum;
  final String not;
  final ValueChanged<String> onNot;
  final Widget? ekAlan;
  final bool duzenlenebilir;

  const KontrolMaddesiKarti({
    super.key,
    required this.madde,
    required this.bolum,
    required this.secenekler,
    required this.seciliDurum,
    required this.onDurum,
    required this.not,
    required this.onNot,
    this.ekAlan,
    this.duzenlenebilir = true,
  });

  @override
  State<KontrolMaddesiKarti> createState() => _KontrolMaddesiKartiState();
}

class _KontrolMaddesiKartiState extends State<KontrolMaddesiKarti> {
  late final TextEditingController _notController;
  final FocusNode _notFocus = FocusNode();
  bool _notAcik = false;

  @override
  void initState() {
    super.initState();
    _notController = TextEditingController(text: widget.not);
    _notAcik = widget.not.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant KontrolMaddesiKarti oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kullanıcı yazarken imleç sıçramasın; sadece dışarıdan gelen değişiklikte güncelle
    if (!_notFocus.hasFocus && widget.not != _notController.text) {
      _notController.text = widget.not;
    }
  }

  @override
  void dispose() {
    _notController.dispose();
    _notFocus.dispose();
    super.dispose();
  }

  Future<void> _fotografCek(ImageSource kaynak) async {
    final provider = context.read<ExpertizProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final renk = context.renkler; // await sonrası bağlam kullanılmaz
    try {
      final XFile? foto = await ImagePicker().pickImage(
        source: kaynak,
        imageQuality: 75,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (foto == null) return;
      final bytes = await foto.readAsBytes();
      await provider.fotografYukle(
        bolum: widget.bolum,
        maddeKey: widget.madde.key,
        maddeEtiket: widget.madde.label,
        bytes: bytes,
        dosyaAdi: foto.name.isNotEmpty ? foto.name : '${widget.madde.key}.jpg',
        not: _notController.text.trim(),
      );
      messenger.showSnackBar(SnackBar(
        content: Text('${widget.madde.label} için fotoğraf kaydedildi'),
        backgroundColor: renk.birincilMetin,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Fotoğraf kaydedilemedi: $e'),
        backgroundColor: renk.tehlike,
      ));
    }
  }

  Future<void> _fotografSil(RaporMedya medya) async {
    final provider = context.read<ExpertizProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final renk = context.renkler; // await sonrası bağlam kullanılmaz
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğraf silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await provider.medyaSil(medya);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Silinemedi: $e'),
          backgroundColor: renk.tehlike));
    }
  }

  void _fotografGoster(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child:
            InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpertizProvider>();
    final secenekler = widget.secenekler;
    final fotolar = provider.fotograflar(widget.bolum, widget.madde.key);
    final eksiklik = secenekler.eksiklikMi(widget.seciliDurum);
    final fotoGerekli = eksiklik && fotolar.isEmpty;
    final yukleniyor = provider.yukleniyor(widget.bolum, widget.madde.key);
    final renk = secenekler.temaRengi(context, widget.seciliDurum);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: fotoGerekli
              ? context.renkler.tehlike
              : widget.seciliDurum == null
                  ? context.renkler.girdiKenarlik
                  : renk.withValues(alpha: .6),
          width: fotoGerekli ? 1.6 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.madde.label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.seciliDurum == null)
                  Text('Seçilmedi',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12))
                else
                  Icon(eksiklik ? LucideIcons.triangleAlert : LucideIcons.circleCheck,
                      color: renk, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: secenekler.degerler.map((deger) {
                final secili = widget.seciliDurum == deger;
                final c = secenekler.temaRengi(context, deger);
                return ChoiceChip(
                  label: Text(secenekler.etiket(deger)),
                  selected: secili,
                  selectedColor: c.withValues(alpha: .25),
                  side: BorderSide(color: secili ? c : context.renkler.girdiKenarlik),
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: secili ? FontWeight.w700 : FontWeight.normal,
                  ),
                  onSelected: widget.duzenlenebilir
                      ? (_) => widget.onDurum(secili ? null : deger)
                      : null,
                );
              }).toList(),
            ),
            if (widget.ekAlan != null) ...[
              const SizedBox(height: 8),
              widget.ekAlan!,
            ],
            if (eksiklik || _notAcik) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _notController,
                focusNode: _notFocus,
                enabled: widget.duzenlenebilir,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: eksiklik ? 'Eksikliği açıklayın' : 'Not',
                  hintText: 'Ör. sağ köşede 3 cm çizik',
                  border: const OutlineInputBorder(),
                ),
                onChanged: widget.onNot,
              ),
            ],
            const SizedBox(height: 8),
            if (fotolar.isNotEmpty)
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fotolar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final medya = fotolar[index];
                    final url = provider.medyaUrl(medya);
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _fotografGoster(url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 76,
                                height: 76,
                                color: context.renkler.yuzeyIkincil,
                                child: const Icon(LucideIcons.imageOff),
                              ),
                            ),
                          ),
                        ),
                        if (widget.duzenlenebilir)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => _fotografSil(medya),
                              child: Container(
                                decoration: BoxDecoration(
                                    color: context.renkler.metin,
                                    shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: Icon(LucideIcons.x,
                                    size: 16, color: context.renkler.beyaz),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              children: [
                if (fotoGerekli)
                  Expanded(
                    child: Text(
                      'Eksiklik işaretlendi: en az 1 fotoğraf çekin',
                      style: TextStyle(
                          color: context.renkler.tehlike,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else if (widget.madde.fotoIpucu != null)
                  Expanded(
                    child: Text(
                      widget.madde.fotoIpucu!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                  )
                else
                  const Spacer(),
                if (!eksiklik && !_notAcik && widget.duzenlenebilir)
                  IconButton(
                    tooltip: 'Not ekle',
                    icon: const Icon(LucideIcons.notebookPen),
                    onPressed: () => setState(() => _notAcik = true),
                  ),
                if (yukleniyor)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (widget.duzenlenebilir) ...[
                  IconButton(
                    tooltip: 'Fotoğraf çek',
                    icon: Icon(LucideIcons.camera,
                        color: fotoGerekli ? context.renkler.tehlike : context.renkler.birincil),
                    onPressed: () => _fotografCek(ImageSource.camera),
                  ),
                  IconButton(
                    tooltip: 'Galeriden seç',
                    icon: Icon(LucideIcons.images,
                        color: context.renkler.birincil),
                    onPressed: () => _fotografCek(ImageSource.gallery),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Adım altındaki genel not alanı (imleç sıçramasın diye stateful).
class GenelNotAlani extends StatefulWidget {
  final String deger;
  final ValueChanged<String> onChanged;
  final String etiket;
  final bool duzenlenebilir;

  const GenelNotAlani({
    super.key,
    required this.deger,
    required this.onChanged,
    this.etiket = 'Genel Notlar',
    this.duzenlenebilir = true,
  });

  @override
  State<GenelNotAlani> createState() => _GenelNotAlaniState();
}

class _GenelNotAlaniState extends State<GenelNotAlani> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.deger);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.duzenlenebilir,
      maxLines: 3,
      decoration: InputDecoration(
          labelText: widget.etiket, border: const OutlineInputBorder()),
      onChanged: widget.onChanged,
    );
  }
}

/// Adımın üstünde gösterilen eksik listesi.
class AdimEksikleriKarti extends StatelessWidget {
  final List<String> eksikler;
  const AdimEksikleriKarti({super.key, required this.eksikler});

  @override
  Widget build(BuildContext context) {
    if (eksikler.isEmpty) {
      return Card(
        color: context.renkler.birincilMetin.withValues(alpha: .08),
        child: ListTile(
          leading: Icon(LucideIcons.badgeCheck, color: context.renkler.birincilMetin),
          title: Text('Bu adım tamam'),
        ),
      );
    }
    return Card(
      color: context.renkler.uyari.withValues(alpha: .08),
      child: ExpansionTile(
        leading: Icon(LucideIcons.clipboardClock, color: context.renkler.uyari),
        title: Text('${eksikler.length} eksik var'),
        subtitle: const Text('Tamamlamadan sonraki adıma geçilemez'),
        children: eksikler
            .take(40)
            .map((e) => ListTile(
                dense: true,
                leading: const Icon(LucideIcons.chevronRight, size: 18),
                title: Text(e)))
            .toList(),
      ),
    );
  }
}

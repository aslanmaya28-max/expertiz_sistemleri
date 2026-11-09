import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/expertiz/durum_enum.dart';
import '../../../models/expertiz/durumlu_soru_model.dart';

/// Seller assessment with full status labels on both phone and desktop.
class DurumluSoruWidget extends StatefulWidget {
  final DurumluSoru soru;
  final Function(Durum?) onDurumChanged;
  final Function(String?) onNotChanged;
  final Function(String?) onFotoChanged;
  final bool enabled;
  final bool showFoto;

  const DurumluSoruWidget(
      {super.key,
      required this.soru,
      required this.onDurumChanged,
      required this.onNotChanged,
      required this.onFotoChanged,
      this.enabled = true,
      this.showFoto = true});

  @override
  State<DurumluSoruWidget> createState() => _DurumluSoruWidgetState();
}

class _DurumluSoruWidgetState extends State<DurumluSoruWidget> {
  late final TextEditingController _note =
      TextEditingController(text: widget.soru.not ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant DurumluSoruWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.soru.not != _note.text) {
      _note.text = widget.soru.not ?? '';
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _secFoto() async {
    try {
      final image = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null && mounted) widget.onFotoChanged(image.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Fotoğraf seçilemedi. Tekrar deneyin.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photo = widget.soru.fotoYolu;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.soru.zorunlu ? '* ' : ''}${widget.soru.soru}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: Durum.values.map((status) {
                    final selected = widget.soru.durum == status;
                    final color = switch (status) {
                      Durum.mukemmel || Durum.iyi => context.renkler.birincilMetin,
                      Durum.orta || Durum.sorunlu => context.renkler.uyari,
                      Durum.kotu || Durum.agirHasar => context.renkler.tehlike,
                    };
                    return ChoiceChip(
                      label: Text(status.displayName),
                      selected: selected,
                      selectedColor: color.withValues(alpha: .14),
                      side: BorderSide(
                          color: selected ? color : context.renkler.girdiKenarlik),
                      labelStyle: TextStyle(
                          color: scheme.onSurface,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500),
                      onSelected: widget.enabled
                          ? (_) => widget.onDurumChanged(status)
                          : null,
                    );
                  }).toList()),
              const SizedBox(height: 10),
              TextField(
                  controller: _note,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Değerlendirme notu',
                      hintText: 'Gözleminizi yazın',
                      border: OutlineInputBorder()),
                  onChanged: widget.onNotChanged),
              if (widget.showFoto) ...[
                const SizedBox(height: 8),
                Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (photo != null && photo.isNotEmpty)
                        ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                                width: 72,
                                height: 72,
                                child: kIsWeb
                                    ? Image.network(photo,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                LucideIcons.imageOff))
                                    : Image.file(File(photo),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                LucideIcons.imageOff)))),
                      if (widget.enabled)
                        OutlinedButton.icon(
                            onPressed: _secFoto,
                            icon: const Icon(LucideIcons.images),
                            label: Text(photo == null
                                ? 'Fotoğraf ekle'
                                : 'Fotoğrafı değiştir')),
                    ]),
              ],
            ],
          )),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/expertiz/durum_enum.dart';
import '../../../models/expertiz/durumlu_soru_model.dart';

/// Durum seçimi olan soru widget'ı
/// Expertiz formlarında kullanılan yeniden kullanılabilir widget
class DurumluSoruWidget extends StatefulWidget {
  final DurumluSoru soru;
  final Function(Durum?) onDurumChanged;
  final Function(String?) onNotChanged;
  final Function(String?) onFotoChanged;
  final bool enabled;
  final bool showFoto;

  const DurumluSoruWidget({
    super.key,
    required this.soru,
    required this.onDurumChanged,
    required this.onNotChanged,
    required this.onFotoChanged,
    this.enabled = true,
    this.showFoto = true,
  });

  @override
  State<DurumluSoruWidget> createState() => _DurumluSoruWidgetState();
}

class _DurumluSoruWidgetState extends State<DurumluSoruWidget> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _secFoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        widget.onFotoChanged(image.path);
      }
    } catch (e) {
      debugPrint('Fotoğraf seçimi hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.enabled ? 2 : 0,
      color: widget.enabled ? Colors.white : Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Madde Adı (flex: 3)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (widget.soru.zorunlu)
                    Text(
                      '* ',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      widget.soru.soru,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.enabled ? Colors.black87 : Colors.grey,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Durum (flex: 3)
            Expanded(
              flex: 3,
              child: widget.enabled
                  ? Row(
                      children: Durum.values.map((durum) {
                        final isSelected = widget.soru.durum == durum;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onDurumChanged(durum),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _getDurumColor(durum)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? _getDurumColor(durum)
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getDurumIcon(durum),
                                    color: isSelected
                                        ? Colors.white
                                        : _getDurumColor(durum),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      durum.displayName,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : _getDurumColor(durum),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getDurumIcon(widget.soru.durum ?? Durum.orta),
                            color: _getDurumColor(widget.soru.durum ?? Durum.orta),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.soru.durum?.displayName ?? 'Seçilmedi',
                              style: TextStyle(
                                color: _getDurumColor(widget.soru.durum ?? Durum.orta),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 8),

            // Not (flex: 6)
            Expanded(
              flex: 6,
              child: TextField(
                enabled: widget.enabled,
                textAlign: TextAlign.left,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'Not...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  filled: !widget.enabled,
                  fillColor: !widget.enabled ? Colors.grey[100] : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                maxLines: 1,
                controller: TextEditingController(text: widget.soru.not),
                onChanged: widget.onNotChanged,
              ),
            ),
            const SizedBox(width: 8),

            // Fotoğraf Butonu (40x40)
            if (widget.showFoto)
              GestureDetector(
                onTap: widget.enabled ? _secFoto : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.enabled ? Colors.grey[200] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.soru.fotoYolu != null
                            ? Colors.green
                            : Colors.grey[300]!,
                      width: widget.soru.fotoYolu != null ? 2 : 1,
                    ),
                  ),
                  child: widget.soru.fotoYolu != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(
                            File(widget.soru.fotoYolu!),
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: widget.enabled ? Colors.grey[600] : Colors.grey[400],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getDurumColor(Durum durum) {
    switch (durum) {
      case Durum.mukemmel:
        return Colors.green;
      case Durum.iyi:
        return Colors.green;
      case Durum.orta:
        return Colors.orange;
      case Durum.sorunlu:
        return Colors.orange.shade700;
      case Durum.kotu:
        return Colors.red;
      case Durum.agirHasar:
        return Colors.red;
    }
  }

  IconData _getDurumIcon(Durum durum) {
    switch (durum) {
      case Durum.mukemmel:
        return Icons.star;
      case Durum.iyi:
        return Icons.check_circle;
      case Durum.orta:
        return Icons.remove_circle;
      case Durum.sorunlu:
        return Icons.warning;
      case Durum.kotu:
        return Icons.cancel;
      case Durum.agirHasar:
        return Icons.error;
    }
  }
}

/// İki seçenekli soru widget'ı (Var/Yok)
class SecimliSoruWidget extends StatelessWidget {
  final String soru;
  final bool? secim;
  final Function(bool?) onSecimChanged;
  final bool enabled;
  final String? secenek1;
  final String? secenek2;

  const SecimliSoruWidget({
    super.key,
    required this.soru,
    required this.secim,
    required this.onSecimChanged,
    this.enabled = true,
    this.secenek1 = 'Var',
    this.secenek2 = 'Yok',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: enabled ? 2 : 0,
      color: enabled ? Colors.white : Colors.grey[100],
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Soru metni
            Row(
              children: [
                Text(
                  soru,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.black87 : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Seçim butonları
            if (enabled)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onSecimChanged(true),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: secim == true ? Colors.blue : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: secim == true ? Colors.blue : Colors.grey[300]!,
                            width: secim == true ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          secenek1!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secim == true ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onSecimChanged(false),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: secim == false ? Colors.blue : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: secim == false ? Colors.blue : Colors.grey[300]!,
                            width: secim == false ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          secenek2!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secim == false ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      secim == true ? Icons.check_circle : Icons.cancel,
                      color: secim == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      secim == true ? secenek1! : secenek2!,
                      style: TextStyle(
                        color: secim == true ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

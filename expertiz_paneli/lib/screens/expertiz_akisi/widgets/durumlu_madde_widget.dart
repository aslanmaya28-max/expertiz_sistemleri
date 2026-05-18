import 'package:flutter/material.dart';
import '../../../models/expertiz/durum_enum.dart';

/// Durumlu madde widget'ı
/// Her madde için: Madde adı | Durum sekmesi | Açıklama | Fotoğraf
class DurumluMaddeWidget extends StatefulWidget {
  final String maddeAdi;
  final Durum? durum;
  final String? aciklama;
  final List<String>? fotografUrl;
  final Color temaRengi;
  final Function(Durum) onDurumChanged;
  final Function(String) onAciklamaChanged;
  final Function() onFotografEkle;

  const DurumluMaddeWidget({
    super.key,
    required this.maddeAdi,
    required this.durum,
    required this.onDurumChanged,
    this.aciklama,
    this.fotografUrl,
    required this.temaRengi,
    required this.onAciklamaChanged,
    required this.onFotografEkle,
  });

  @override
  State<DurumluMaddeWidget> createState() => _DurumluMaddeWidgetState();
}

class _DurumluMaddeWidgetState extends State<DurumluMaddeWidget> {
  late TextEditingController _aciklamaController;

  @override
  void initState() {
    super.initState();
    _aciklamaController = TextEditingController(text: widget.aciklama ?? '');
  }

  @override
  void dispose() {
    _aciklamaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol taraf: Madde adı
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.maddeAdi,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Durum sekmesi
                  DropdownButtonFormField<Durum>(
                    // ignore: deprecated_member_use
                    value: widget.durum,
                    decoration: InputDecoration(
                      labelText: 'Durum',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: Durum.values.map((d) {
                      return DropdownMenuItem<Durum>(
                        value: d,
                        child: Row(
                          children: [
                            Icon(
                              _getDurumIcon(d),
                              size: 18,
                              color: _getDurumColor(d),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              d.displayName,
                              style: TextStyle(
                                color: _getDurumColor(d),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (d) {
                      if (d != null) {
                        widget.onDurumChanged(d);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            
            // Sağ taraf: Açıklama ve Fotoğraf
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Açıklama alanı
                  TextField(
                    controller: _aciklamaController,
                    onChanged: (value) => widget.onAciklamaChanged(value),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'Detaylı bilgi giriniz...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                   
                  // Fotoğraf ekleme butonu
                  ElevatedButton.icon(
                    onPressed: widget.onFotografEkle,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(
                      widget.fotografUrl != null && widget.fotografUrl!.isNotEmpty
                          ? 'Fotoğraf Ekle (${widget.fotografUrl!.length})'
                          : 'Fotoğraf Ekle',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.temaRengi,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                   
                  // Fotoğraf önizleme
                  if (widget.fotografUrl != null && widget.fotografUrl!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.fotografUrl!.take(3).map((url) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDurumIcon(Durum durum) {
    switch (durum) {
      case Durum.mukemmel:
        return Icons.star;
      case Durum.iyi:
        return Icons.thumb_up;
      case Durum.orta:
        return Icons.remove;
      case Durum.sorunlu:
        return Icons.warning;
      case Durum.kotu:
        return Icons.close;
      case Durum.agirHasar:
        return Icons.error;
    }
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
}

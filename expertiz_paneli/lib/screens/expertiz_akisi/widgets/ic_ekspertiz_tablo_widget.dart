import 'package:flutter/material.dart';
import '../../../models/expertiz/durum_enum.dart';

/// İç Ekspertiz Tablo Widget'ı
/// Tasarım: Madde | Durum Sekmesi (Dropdown) | Açıklama | Fotoğraf Yükle (Sorun varsa)
class IcEkspertizTabloWidget extends StatelessWidget {
  final String maddeAdi;
  final Durum? durum;
  final String? aciklama;
  final bool fotografVar;
  final bool enabled;
  final Function(Durum) onDurumChanged;
  final Function(String) onAciklamaChanged;
  final Function() onFotoUpload;

  const IcEkspertizTabloWidget({
    super.key,
    required this.maddeAdi,
    this.durum,
    this.aciklama,
    this.fotografVar = false,
    this.enabled = true,
    required this.onDurumChanged,
    required this.onAciklamaChanged,
    required this.onFotoUpload,
  });

  @override
  Widget build(BuildContext context) {
    final sorunVarMi = durum == Durum.sorunlu || durum == Durum.agirHasar;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Madde Adı ve Durum Dropdown
            Row(
              children: [
                // Madde Adı
                Expanded(
                  flex: 3,
                  child: Text(
                    maddeAdi,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Durum Dropdown (Aşağı açılır)
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Durum>(
                    // ignore: deprecated_member_use
                    value: durum,
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
                            Icon(_getDurumIcon(d), size: 18, color: _getDurumColor(d)),
                            const SizedBox(width: 8),
                            Text(d.toString().split('.').last),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: enabled
                        ? (d) {
                            if (d != null) {
                              onDurumChanged(d);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Açıklama Alanı
            TextField(
              enabled: enabled,
              decoration: InputDecoration(
                labelText: 'Açıklama',
                hintText: sorunVarMi ? 'Sorunu açıklayın...' : 'Varsa ekstra bilgi giriniz...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              maxLines: 2,
              controller: TextEditingController(text: aciklama ?? ''),
              onChanged: onAciklamaChanged,
            ),
            
            // Sadece sorun varsa fotoğraf yükle butonu göster
            if (sorunVarMi) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: enabled ? onFotoUpload : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(fotografVar ? 'Fotoğraf Değiştir' : 'Fotoğraf Yükle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (fotografVar)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                ],
              ),
            ],
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
        return Icons.thumb_down;
      case Durum.agirHasar:
        return Icons.error;
    }
  }

  Color _getDurumColor(Durum durum) {
    switch (durum) {
      case Durum.mukemmel:
        return Colors.green;
      case Durum.iyi:
        return Colors.lightGreen;
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

import 'package:flutter/material.dart';
import '../../../core/constants/yerimebak_colors.dart';

/// Dosya Yükleme Widget'ı
/// Adım 5 (Kurumsal Ekspertiz) için dosya/fotoğraf yükleme alanı
class DosyaYuklemeWidget extends StatelessWidget {
  /// Dosya başlığı
  final String baslik;
  
  /// Dosya tipi (PDF, Görsel vb.)
  final String dosyaTipi;
  
  /// Yüklenen dosya sayısı
  final int dosyaSayisi;
  
  /// Dosya ekle butonuna tıklandığında çağrılır
  final VoidCallback onDosyaEkle;
  
  /// Yüklenen dosyaları göster
  final List<String> yuklenenDosyalar;
  
  /// Dosya sil butonuna tıklandığında çağrılır
  final Function(int index) onDosyaSil;

  const DosyaYuklemeWidget({
    super.key,
    required this.baslik,
    required this.dosyaTipi,
    required this.dosyaSayisi,
    required this.onDosyaEkle,
    required this.yuklenenDosyalar,
    required this.onDosyaSil,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: YerimeBakColors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Dosya Sayısı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: YerimeBakColors.darkGray,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: YerimeBakColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: YerimeBakColors.blue, width: 1),
                  ),
                  child: Text(
                    '$dosyaSayisi dosya',
                    style: const TextStyle(
                      color: YerimeBakColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
             
            // Dosya Tipi Etiketi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: YerimeBakColors.lightGray,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: YerimeBakColors.blue.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                dosyaTipi,
                style: const TextStyle(
                  color: YerimeBakColors.darkGray,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
             
            // Yüklenen Dosyalar Grid
            if (yuklenenDosyalar.isNotEmpty) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: yuklenenDosyalar.length,
                itemBuilder: (context, index) {
                  final dosya = yuklenenDosyalar[index];
                  final dosyaUzantisi = dosya.split('.').last.toLowerCase();
                  final pdfDosyasi = dosyaUzantisi == 'pdf';
                   
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: YerimeBakColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: YerimeBakColors.blue.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Center(
                          child: pdfDosyasi
                              ? const Icon(
                                  Icons.picture_as_pdf,
                                  size: 40,
                                  color: YerimeBakColors.red,
                                )
                              : const Icon(
                                  Icons.image,
                                  size: 40,
                                  color: YerimeBakColors.blue,
                                ),
                        ),
                      ),
                      // Dosya Sil Butonu
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onDosyaSil(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: YerimeBakColors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
             
            // Şık Dosya Ekle Kutucuğu
            GestureDetector(
              onTap: onDosyaEkle,
              child: Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: YerimeBakColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: YerimeBakColors.blue,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 32,
                        color: YerimeBakColors.blue.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        yuklenenDosyalar.isEmpty
                            ? 'Dosya Yükle'
                            : 'Dosya Ekle',
                        style: TextStyle(
                          fontSize: 14,
                          color: YerimeBakColors.blue.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dosyaTipi,
                        style: TextStyle(
                          fontSize: 11,
                          color: YerimeBakColors.blue.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

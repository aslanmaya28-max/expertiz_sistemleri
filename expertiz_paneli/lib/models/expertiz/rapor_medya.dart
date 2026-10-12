/// Sunucuya yüklenmiş ekspertiz dosyası (hasar fotoğrafı / kurumsal rapor).
///
/// [url] süreli imzalı bir bağlantıdır; ekranlar her açılışta API'den
/// taze liste alır.
class RaporMedya {
  static const kategoriFoto = 'inspection_photo';
  static const kategoriKurumsal = 'corporate_report';

  final String id;
  final String kategori;
  final String? bolum;
  final String? maddeKey;
  final String? maddeEtiket;
  final String not;
  final String url;
  final bool resimMi;
  final String? dosyaAdi;
  final String? icerikTipi;
  final DateTime? olusturulma;

  const RaporMedya({
    required this.id,
    required this.kategori,
    required this.url,
    this.bolum,
    this.maddeKey,
    this.maddeEtiket,
    this.not = '',
    this.resimMi = true,
    this.dosyaAdi,
    this.icerikTipi,
    this.olusturulma,
  });

  bool get kurumsalRaporMu => kategori == kategoriKurumsal;
  bool get pdfMi => icerikTipi == 'application/pdf';

  factory RaporMedya.fromJson(Map<String, dynamic> json) {
    return RaporMedya(
      id: json['id']?.toString() ?? '',
      kategori: json['category']?.toString() ?? kategoriFoto,
      bolum: json['section']?.toString(),
      maddeKey: json['item_key']?.toString(),
      maddeEtiket: json['item_label']?.toString(),
      not: json['note']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      resimMi: json['is_image'] == true,
      dosyaAdi: json['original_name']?.toString(),
      icerikTipi: json['content_type']?.toString(),
      olusturulma: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static List<RaporMedya> listFrom(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((e) => RaporMedya.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

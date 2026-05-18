class AracDegerlemeModel {
  final String aracId;
  final List<double> piyasaFiyatlari;
  final double piyasaOrtalamasi;
  final double hasarKaybi;
  final double kmKaybi;
  final double yasKaybi;
  final double toplamDegerKaybi;
  final double onerilenAlisFiyati;
  final double beklenenSatisFiyati;
  final double potansiyelKar;
  final double karMarji;
  final String riskSeviyesi;
  final List<String> oneriler;

  AracDegerlemeModel({
    required this.aracId,
    required this.piyasaFiyatlari,
    required this.piyasaOrtalamasi,
    required this.hasarKaybi,
    required this.kmKaybi,
    required this.yasKaybi,
    required this.toplamDegerKaybi,
    required this.onerilenAlisFiyati,
    required this.beklenenSatisFiyati,
    required this.potansiyelKar,
    required this.karMarji,
    required this.riskSeviyesi,
    required this.oneriler,
  });

  factory AracDegerlemeModel.fromJson(Map<String, dynamic> json) {
    return AracDegerlemeModel(
      aracId: json['aracId'] ?? '',
      piyasaFiyatlari: List<double>.from(json['piyasaFiyatlari'] ?? []),
      piyasaOrtalamasi: (json['piyasaOrtalamasi'] ?? 0).toDouble(),
      hasarKaybi: (json['hasarKaybi'] ?? 0).toDouble(),
      kmKaybi: (json['kmKaybi'] ?? 0).toDouble(),
      yasKaybi: (json['yasKaybi'] ?? 0).toDouble(),
      toplamDegerKaybi: (json['toplamDegerKaybi'] ?? 0).toDouble(),
      onerilenAlisFiyati: (json['onerilenAlisFiyati'] ?? 0).toDouble(),
      beklenenSatisFiyati: (json['beklenenSatisFiyati'] ?? 0).toDouble(),
      potansiyelKar: (json['potansiyelKar'] ?? 0).toDouble(),
      karMarji: (json['karMarji'] ?? 0).toDouble(),
      riskSeviyesi: json['riskSeviyesi'] ?? 'Orta',
      oneriler: List<String>.from(json['oneriler'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'aracId': aracId,
      'piyasaFiyatlari': piyasaFiyatlari,
      'piyasaOrtalamasi': piyasaOrtalamasi,
      'hasarKaybi': hasarKaybi,
      'kmKaybi': kmKaybi,
      'yasKaybi': yasKaybi,
      'toplamDegerKaybi': toplamDegerKaybi,
      'onerilenAlisFiyati': onerilenAlisFiyati,
      'beklenenSatisFiyati': beklenenSatisFiyati,
      'potansiyelKar': potansiyelKar,
      'karMarji': karMarji,
      'riskSeviyesi': riskSeviyesi,
      'oneriler': oneriler,
    };
  }
}

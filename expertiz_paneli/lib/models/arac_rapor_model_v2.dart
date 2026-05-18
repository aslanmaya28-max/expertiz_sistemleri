import 'package:flutter/material.dart';

class AracRapor {
  final String id;
  final String musteriId;
  final DateTime olusturmaTarihi;
  final String durum;
  final String? ilanLinki;
  final String? plaka;
  final String? marka;
  final String? model;
  final String? yil;
  final String sehir;
  final String? ilce;
  final String? ekspertizFirmasi;
  final String secilenPaket;
  final double hizmetBedeli;
  final double paketFiyati;
  final double toplamTutar;
  final String? olusturanKullanici;
  final String? personelId;
  
  // Yeni eklenen alanlar (Hata düzeltmeleri için)
  final int kilometre;
  final String saseNo;
  final bool hasarKaydiVar;
  final int hasarAdet;
  final double hasarTutar;
  final DateTime? onayTarihi;
  final String? onaylayanKullanici;
  final String? reddetmeNedeni;

  // AI Analiz Alanları
  final bool aiAnaliziYapildiMi;
  final double? aiPiyasaDegeri;
  final double? aiOnerilenAlimFiyati;
  final double? aiAltiAylikGetiri;
  final double? aiBirYillikGetiri;
  final String? aiYorumu;
  final double? aiDegerKaybi;

  AracRapor({
    required this.id,
    required this.musteriId,
    required this.olusturmaTarihi,
    required this.durum,
    this.ilanLinki,
    this.plaka,
    this.marka,
    this.model,
    this.yil,
    required this.sehir,
    this.ilce,
    this.ekspertizFirmasi,
    required this.secilenPaket,
    required this.hizmetBedeli,
    required this.paketFiyati,
    required this.toplamTutar,
    this.olusturanKullanici,
    this.personelId,
    this.kilometre = 0,
    this.saseNo = '',
    this.hasarKaydiVar = false,
    this.hasarAdet = 0,
    this.hasarTutar = 0.0,
    this.onayTarihi,
    this.onaylayanKullanici,
    this.reddetmeNedeni,
    this.aiAnaliziYapildiMi = false,
    this.aiPiyasaDegeri,
    this.aiOnerilenAlimFiyati,
    this.aiAltiAylikGetiri,
    this.aiBirYillikGetiri,
    this.aiYorumu,
    this.aiDegerKaybi,
  });

  // Getter'lar (Eski kod uyumluluğu için)
  DateTime get olusturulmaTarihi => olusturmaTarihi;

  // Durum Rengi
  Color get durumRengi => durumRengiGetir(durum);

  static Color durumRengiGetir(String durum) {
    switch (durum) {
      case 'OdemeBekliyor':
      case 'Onay Bekliyor':
        return Colors.orange;
      case 'Islemde':
      case 'Personele Atandı':
        return Colors.blue;
      case 'Tamamlandi':
      case 'Onaylandı':
        return Colors.green;
      case 'Iptal':
      case 'Reddedildi':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get durumMetni {
    switch (durum) {
      case 'OdemeBekliyor': return 'Ödeme Bekliyor';
      case 'Islemde': return 'İşlemde';
      case 'Tamamlandi': return 'Tamamlandı';
      case 'Iptal': return 'İptal Edildi';
      default: return durum;
    }
  }

  // CopyWith Metodu
  AracRapor copyWith({
    String? id,
    String? musteriId,
    DateTime? olusturmaTarihi,
    String? durum,
    String? ilanLinki,
    String? plaka,
    String? marka,
    String? model,
    dynamic yil, // int veya String gelebilir
    String? sehir,
    String? ilce,
    String? ekspertizFirmasi,
    String? secilenPaket,
    double? hizmetBedeli,
    double? paketFiyati,
    double? toplamTutar,
    String? olusturanKullanici,
    String? personelId,
    int? kilometre,
    String? saseNo,
    bool? hasarKaydiVar,
    int? hasarAdet,
    double? hasarTutar,
    DateTime? onayTarihi,
    String? onaylayanKullanici,
    String? reddetmeNedeni,
    bool? aiAnaliziYapildiMi,
    double? aiPiyasaDegeri,
    double? aiOnerilenAlimFiyati,
    double? aiAltiAylikGetiri,
    double? aiBirYillikGetiri,
    String? aiYorumu,
    double? aiDegerKaybi,
    Color? durumRengi, // Yoksayılacak
  }) {
    return AracRapor(
      id: id ?? this.id,
      musteriId: musteriId ?? this.musteriId,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      durum: durum ?? this.durum,
      ilanLinki: ilanLinki ?? this.ilanLinki,
      plaka: plaka ?? this.plaka,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      yil: yil != null ? yil.toString() : this.yil,
      sehir: sehir ?? this.sehir,
      ilce: ilce ?? this.ilce,
      ekspertizFirmasi: ekspertizFirmasi ?? this.ekspertizFirmasi,
      secilenPaket: secilenPaket ?? this.secilenPaket,
      hizmetBedeli: hizmetBedeli ?? this.hizmetBedeli,
      paketFiyati: paketFiyati ?? this.paketFiyati,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      olusturanKullanici: olusturanKullanici ?? this.olusturanKullanici,
      personelId: personelId ?? this.personelId,
      kilometre: kilometre ?? this.kilometre,
      saseNo: saseNo ?? this.saseNo,
      hasarKaydiVar: hasarKaydiVar ?? this.hasarKaydiVar,
      hasarAdet: hasarAdet ?? this.hasarAdet,
      hasarTutar: hasarTutar ?? this.hasarTutar,
      onayTarihi: onayTarihi ?? this.onayTarihi,
      onaylayanKullanici: onaylayanKullanici ?? this.onaylayanKullanici,
      reddetmeNedeni: reddetmeNedeni ?? this.reddetmeNedeni,
      aiAnaliziYapildiMi: aiAnaliziYapildiMi ?? this.aiAnaliziYapildiMi,
      aiPiyasaDegeri: aiPiyasaDegeri ?? this.aiPiyasaDegeri,
      aiOnerilenAlimFiyati: aiOnerilenAlimFiyati ?? this.aiOnerilenAlimFiyati,
      aiAltiAylikGetiri: aiAltiAylikGetiri ?? this.aiAltiAylikGetiri,
      aiBirYillikGetiri: aiBirYillikGetiri ?? this.aiBirYillikGetiri,
      aiYorumu: aiYorumu ?? this.aiYorumu,
      aiDegerKaybi: aiDegerKaybi ?? this.aiDegerKaybi,
    );
  }

  // Onayla Metodu
  AracRapor onayla(String onaylayan) {
    return copyWith(
      durum: 'Onaylandı',
      onaylayanKullanici: onaylayan,
      onayTarihi: DateTime.now(),
    );
  }

  // Reddet Metodu
  AracRapor reddet(String reddeden, String neden) {
    return copyWith(
      durum: 'Reddedildi',
      onaylayanKullanici: reddeden,
      onayTarihi: DateTime.now(),
      reddetmeNedeni: neden,
    );
  }
}

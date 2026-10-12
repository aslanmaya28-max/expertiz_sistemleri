import 'package:equatable/equatable.dart';
import '../core/constants/roles.dart';

/// Personel Modeli - Enterprise Grade & UI Compatible
///
/// SINGLE SOURCE OF TRUTH for personnel data.
/// This model includes ALL fields from both old and new structures
/// to ensure compatibility across the entire application.
class PersonelModel extends Equatable {
  /// Unique identifier for the personnel
  final String id;

  /// First name
  final String ad;

  /// Last name
  final String soyad;

  /// Full name (legacy field for backward compatibility)
  final String? adSoyad;

  /// Title/Position
  final String unvan;

  /// Province ID (REQUIRED - Single Source of Truth)
  /// Maps to IlModel.id
  final int ilId;

  /// Region ID (REQUIRED - Single Source of Truth)
  /// Maps to BolgeModel.id
  final int bolgeId;

  /// Email address
  final String? email;

  /// Phone number
  final String? telefon;

  /// Encrypted password
  final String? sifre;

  /// User role
  final UserRole rol;

  /// Registration date
  final DateTime? kayitTarihi;

  /// Active status
  final bool aktif;

  /// Department
  final String? departman;

  /// Position
  final String? pozisyon;

  /// Employment start date
  final DateTime? iseBaslamaTarihi;

  /// Salary
  final double? maas;

  /// Education level
  final String? egitimDurumu;

  /// Emergency contact
  final String? acilDurumKontagi;

  /// Emergency phone
  final String? acilDurumTelefonu;

  /// Notes
  final String? notlar;

  /// Address
  final String? adres;

  /// City name (for display)
  final String? il;

  /// District name (for display)
  final String? ilce;

  /// Region name (for display)
  final String? bolge;

  /// Expertise area
  final String? uzmanlikAlani;

  /// Completed task count
  final int? tamamlananGorevSayisi;

  /// Average rating
  final double? ortalamaPuan;

  /// Profile photo URL
  final String? profilFotografUrl;

  /// ID card photo URL
  final String? kimlikFotografUrl;

  /// Görev için aktif mi (hesap aktifliğinden ayrı). Pasif personele görev atanmaz.
  final bool gorevAktif;

  const PersonelModel({
    required this.id,
    required this.ad,
    required this.soyad,
    this.adSoyad,
    required this.unvan,
    required this.ilId,
    required this.bolgeId,
    this.email,
    this.telefon,
    this.sifre,
    required this.rol,
    this.kayitTarihi,
    this.aktif = true,
    this.departman,
    this.pozisyon,
    this.iseBaslamaTarihi,
    this.maas,
    this.egitimDurumu,
    this.acilDurumKontagi,
    this.acilDurumTelefonu,
    this.notlar,
    this.adres,
    this.il,
    this.ilce,
    this.bolge,
    this.uzmanlikAlani,
    this.tamamlananGorevSayisi,
    this.ortalamaPuan,
    this.profilFotografUrl,
    this.kimlikFotografUrl,
    this.gorevAktif = true,
  });

  /// Create PersonelModel from Map
  factory PersonelModel.fromMap(Map<String, dynamic> map) {
    final fullName = (map['adSoyad'] ?? map['full_name'] ?? map['fullName'] ?? map['name'])?.toString();
    final nameParts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final firstName = map['ad']?.toString() ?? (nameParts.isNotEmpty ? nameParts.first : '');
    final lastName = map['soyad']?.toString() ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    return PersonelModel(
      id: map['id']?.toString() ?? '',
      ad: firstName,
      soyad: lastName,
      adSoyad: fullName,
      unvan: map['unvan']?.toString() ?? '',
      ilId: map['ilId'] is int ? map['ilId'] as int : int.tryParse(map['ilId']?.toString() ?? '0') ?? 0,
      bolgeId: map['bolgeId'] is int ? map['bolgeId'] as int : int.tryParse(map['bolgeId']?.toString() ?? '0') ?? 0,
      email: map['email']?.toString(),
      telefon: map['telefon']?.toString() ?? map['phone']?.toString(),
      sifre: map['sifre']?.toString(),
      rol: UserRole.fromDatabaseValue(map['rol'] ?? map['role'] ?? 'field_staff'),
      kayitTarihi: map['kayitTarihi'] != null
          ? DateTime.tryParse(map['kayitTarihi'].toString())
          : null,
      aktif: map['aktif'] as bool? ?? map['active'] as bool? ?? map['aktif_mi'] as bool? ?? true,
      departman: map['departman']?.toString(),
      pozisyon: map['pozisyon']?.toString(),
      iseBaslamaTarihi: map['iseBaslamaTarihi'] != null
          ? DateTime.tryParse(map['iseBaslamaTarihi'].toString())
          : null,
      maas: map['maas'] is double
          ? map['maas'] as double
          : double.tryParse(map['maas']?.toString() ?? '0'),
      egitimDurumu: map['egitimDurumu']?.toString(),
      acilDurumKontagi: map['acilDurumKontagi']?.toString(),
      acilDurumTelefonu: map['acilDurumTelefonu']?.toString(),
      notlar: map['notlar']?.toString(),
      adres: map['adres']?.toString(),
      il: map['il']?.toString() ?? map['city']?.toString(),
      ilce: map['ilce']?.toString() ?? map['district']?.toString(),
      bolge: map['bolge']?.toString(),
      uzmanlikAlani: map['uzmanlikAlani']?.toString() ?? map['uzmanlik'] ?? map['expertise'],
      tamamlananGorevSayisi: map['tamamlananGorevSayisi'] is int
          ? map['tamamlananGorevSayisi'] as int
          : int.tryParse(map['tamamlananGorevSayisi']?.toString() ?? (map['tamamlananExpertiz'] ?? '0').toString()),
      ortalamaPuan: map['ortalamaPuan'] is double
          ? map['ortalamaPuan'] as double
          : double.tryParse(map['ortalamaPuan']?.toString() ?? '0'),
      profilFotografUrl: map['profilFotografUrl']?.toString(),
      kimlikFotografUrl: map['kimlikFotografUrl']?.toString(),
      gorevAktif: map['gorevAktif'] as bool? ?? map['on_duty'] as bool? ?? true,
    );
  }

  /// Create PersonelModel from JSON
  factory PersonelModel.fromJson(Map<String, dynamic> json) {
    return PersonelModel.fromMap(json);
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'soyad': soyad,
      'adSoyad': tamAd,
      'unvan': unvan,
      'ilId': ilId,
      'bolgeId': bolgeId,
      'email': email,
      'telefon': telefon,
      'sifre': sifre,
      'rol': rol.toDatabaseValue,
      'kayitTarihi': kayitTarihi?.toIso8601String(),
      'aktif': aktif,
      'departman': departman,
      'pozisyon': pozisyon,
      'iseBaslamaTarihi': iseBaslamaTarihi?.toIso8601String(),
      'maas': maas,
      'egitimDurumu': egitimDurumu,
      'acilDurumKontagi': acilDurumKontagi,
      'acilDurumTelefonu': acilDurumTelefonu,
      'notlar': notlar,
      'adres': adres,
      'il': il,
      'ilce': ilce,
      'bolge': bolge,
      'uzmanlikAlani': uzmanlikAlani,
      'tamamlananGorevSayisi': tamamlananGorevSayisi,
      'ortalamaPuan': ortalamaPuan,
      'profilFotografUrl': profilFotografUrl,
      'kimlikFotografUrl': kimlikFotografUrl,
      'gorevAktif': gorevAktif,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return toMap();
  }

  /// Full name getter
  String get tamAd => adSoyad ?? '$ad $soyad';

  /// Copy with method for immutability
  PersonelModel copyWith({
    String? id,
    String? ad,
    String? soyad,
    String? adSoyad,
    String? unvan,
    int? ilId,
    int? bolgeId,
    String? email,
    String? telefon,
    String? sifre,
    UserRole? rol,
    DateTime? kayitTarihi,
    bool? aktif,
    String? departman,
    String? pozisyon,
    DateTime? iseBaslamaTarihi,
    double? maas,
    String? egitimDurumu,
    String? acilDurumKontagi,
    String? acilDurumTelefonu,
    String? notlar,
    String? adres,
    String? il,
    String? ilce,
    String? bolge,
    String? uzmanlikAlani,
    int? tamamlananGorevSayisi,
    double? ortalamaPuan,
    String? profilFotografUrl,
    String? kimlikFotografUrl,
    bool? gorevAktif,
  }) {
    return PersonelModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      adSoyad: adSoyad ?? this.adSoyad,
      unvan: unvan ?? this.unvan,
      ilId: ilId ?? this.ilId,
      bolgeId: bolgeId ?? this.bolgeId,
      email: email ?? this.email,
      telefon: telefon ?? this.telefon,
      sifre: sifre ?? this.sifre,
      rol: rol ?? this.rol,
      kayitTarihi: kayitTarihi ?? this.kayitTarihi,
      aktif: aktif ?? this.aktif,
      departman: departman ?? this.departman,
      pozisyon: pozisyon ?? this.pozisyon,
      iseBaslamaTarihi: iseBaslamaTarihi ?? this.iseBaslamaTarihi,
      maas: maas ?? this.maas,
      egitimDurumu: egitimDurumu ?? this.egitimDurumu,
      acilDurumKontagi: acilDurumKontagi ?? this.acilDurumKontagi,
      acilDurumTelefonu: acilDurumTelefonu ?? this.acilDurumTelefonu,
      notlar: notlar ?? this.notlar,
      adres: adres ?? this.adres,
      il: il ?? this.il,
      ilce: ilce ?? this.ilce,
      bolge: bolge ?? this.bolge,
      uzmanlikAlani: uzmanlikAlani ?? this.uzmanlikAlani,
      tamamlananGorevSayisi:
          tamamlananGorevSayisi ?? this.tamamlananGorevSayisi,
      ortalamaPuan: ortalamaPuan ?? this.ortalamaPuan,
      profilFotografUrl: profilFotografUrl ?? this.profilFotografUrl,
      kimlikFotografUrl: kimlikFotografUrl ?? this.kimlikFotografUrl,
      gorevAktif: gorevAktif ?? this.gorevAktif,
    );
  }

  @override
  String toString() {
    return 'PersonelModel(id: $id, ad: $tamAd, unvan: $unvan, ilId: $ilId, bolgeId: $bolgeId)';
  }

  @override
  List<Object?> get props => [
        id,
        ad,
        soyad,
        adSoyad,
        unvan,
        ilId,
        bolgeId,
        email,
        telefon,
        sifre,
        rol,
        kayitTarihi,
        aktif,
        departman,
        pozisyon,
        iseBaslamaTarihi,
        maas,
        egitimDurumu,
        acilDurumKontagi,
        acilDurumTelefonu,
        notlar,
        adres,
        il,
        ilce,
        bolge,
        uzmanlikAlani,
        tamamlananGorevSayisi,
        ortalamaPuan,
        profilFotografUrl,
        kimlikFotografUrl,
      ];
}

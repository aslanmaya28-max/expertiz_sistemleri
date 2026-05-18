import 'package:flutter/material.dart';

/// Ödeme modeli - Müşteri ödemelerini takip etmek için
class Odeme {
  final String id;
  final double amount;
  final String customerID;
  final String staffID;
  final String reportID;
  final double commission; // %25 komisyon
  final String status; // 'Paid', 'Pending'
  final DateTime olusturmaTarihi;
  final DateTime? odemeTarihi;
  final String odemeYontemi; // 'kredi_karti', 'havale', 'nakit'
  final String? referansNo;

  Odeme({
    required this.id,
    required this.amount,
    required this.customerID,
    required this.staffID,
    required this.reportID,
    required this.commission,
    required this.status,
    required this.olusturmaTarihi,
    this.odemeTarihi,
    required this.odemeYontemi,
    this.referansNo,
  });

  factory Odeme.fromJson(Map<String, dynamic> json) {
    return Odeme(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      customerID: json['customerID']?.toString() ?? '',
      staffID: json['staffID']?.toString() ?? '',
      reportID: json['reportID']?.toString() ?? '',
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Pending',
      olusturmaTarihi: json['olusturmaTarihi'] != null
          ? DateTime.parse(json['olusturmaTarihi'].toString())
          : DateTime.now(),
      odemeTarihi: json['odemeTarihi'] != null
          ? DateTime.parse(json['odemeTarihi'].toString())
          : null,
      odemeYontemi: json['odemeYontemi']?.toString() ?? 'kredi_karti',
      referansNo: json['referansNo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'customerID': customerID,
      'staffID': staffID,
      'reportID': reportID,
      'commission': commission,
      'status': status,
      'olusturmaTarihi': olusturmaTarihi.toIso8601String(),
      'odemeTarihi': odemeTarihi?.toIso8601String(),
      'odemeYontemi': odemeYontemi,
      'referansNo': referansNo,
    };
  }

  Odeme copyWith({
    String? id,
    double? amount,
    String? customerID,
    String? staffID,
    String? reportID,
    double? commission,
    String? status,
    DateTime? olusturmaTarihi,
    DateTime? odemeTarihi,
    String? odemeYontemi,
    String? referansNo,
  }) {
    return Odeme(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      customerID: customerID ?? this.customerID,
      staffID: staffID ?? this.staffID,
      reportID: reportID ?? this.reportID,
      commission: commission ?? this.commission,
      status: status ?? this.status,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      odemeTarihi: odemeTarihi ?? this.odemeTarihi,
      odemeYontemi: odemeYontemi ?? this.odemeYontemi,
      referansNo: referansNo ?? this.referansNo,
    );
  }

  // Helper getters
  bool get isPaid => status == 'Paid';
  bool get isPending => status == 'Pending';
  
  double get komisyonTutari => amount * (commission / 100);
  double get netTutar => amount - komisyonTutari;
  
  String get durumText => isPaid ? 'Ödendi' : 'Beklemede';
  Color get durumRengi => isPaid ? Colors.green : Colors.orange;
  
  IconData get durumIkonu => isPaid ? Icons.check_circle : Icons.pending;

  // Formatlı tutar
  String get formatliTutar => '${amount.toStringAsFixed(2)} TL';
  String get formatliKomisyon => '${komisyonTutari.toStringAsFixed(2)} TL';
  String get formatliNet => '${netTutar.toStringAsFixed(2)} TL';

  // Boş ödeme oluştur
  static Odeme empty() {
    return Odeme(
      id: '',
      amount: 0.0,
      customerID: '',
      staffID: '',
      reportID: '',
      commission: 25.0,
      status: 'Pending',
      olusturmaTarihi: DateTime.now(),
      odemeYontemi: 'kredi_karti',
    );
  }

  @override
  String toString() {
    return 'Odeme(id: $id, amount: $amount, status: $status, customerID: $customerID)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Odeme && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Personel hakediş modeli - Personelin kazandığı komisyonları takip etmek için
class PersonelHakedis {
  final String id;
  final String personelID;
  final String odemeID;
  final String reportID;
  final double hakedisTutari;
  final DateTime kazanimTarihi;
  final String? odemeTarihi;
  final String durum; // 'bekleniyor', 'odendi', 'iptal'

  PersonelHakedis({
    required this.id,
    required this.personelID,
    required this.odemeID,
    required this.reportID,
    required this.hakedisTutari,
    required this.kazanimTarihi,
    this.odemeTarihi,
    required this.durum,
  });

  factory PersonelHakedis.fromJson(Map<String, dynamic> json) {
    return PersonelHakedis(
      id: json['id']?.toString() ?? '',
      personelID: json['personelID']?.toString() ?? '',
      odemeID: json['odemeID']?.toString() ?? '',
      reportID: json['reportID']?.toString() ?? '',
      hakedisTutari: (json['hakedisTutari'] as num?)?.toDouble() ?? 0.0,
      kazanimTarihi: json['kazanimTarihi'] != null
          ? DateTime.parse(json['kazanimTarihi'].toString())
          : DateTime.now(),
      odemeTarihi: json['odemeTarihi']?.toString(),
      durum: json['durum']?.toString() ?? 'bekleniyor',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personelID': personelID,
      'odemeID': odemeID,
      'reportID': reportID,
      'hakedisTutari': hakedisTutari,
      'kazanimTarihi': kazanimTarihi.toIso8601String(),
      'odemeTarihi': odemeTarihi,
      'durum': durum,
    };
  }

  PersonelHakedis copyWith({
    String? id,
    String? personelID,
    String? odemeID,
    String? reportID,
    double? hakedisTutari,
    DateTime? kazanimTarihi,
    String? odemeTarihi,
    String? durum,
  }) {
    return PersonelHakedis(
      id: id ?? this.id,
      personelID: personelID ?? this.personelID,
      odemeID: odemeID ?? this.odemeID,
      reportID: reportID ?? this.reportID,
      hakedisTutari: hakedisTutari ?? this.hakedisTutari,
      kazanimTarihi: kazanimTarihi ?? this.kazanimTarihi,
      odemeTarihi: odemeTarihi ?? this.odemeTarihi,
      durum: durum ?? this.durum,
    );
  }

  // Helper getters
  bool get odendi => durum == 'odendi';
  bool get bekleniyor => durum == 'bekleniyor';
  
  String get durumText {
    switch (durum) {
      case 'odendi':
        return 'Ödendi';
      case 'iptal':
        return 'İptal';
      default:
        return 'Bekleniyor';
    }
  }

  Color get durumRengi {
    switch (durum) {
      case 'odendi':
        return Colors.green;
      case 'iptal':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get formatliTutar => '${hakedisTutari.toStringAsFixed(2)} TL';

  @override
  String toString() {
    return 'PersonelHakedis(id: $id, personelID: $personelID, hakedisTutari: $hakedisTutari)';
  }
}

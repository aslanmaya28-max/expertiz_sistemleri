import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// İl Modeli - UI Compatible
///
/// This model is designed to work with the existing UI components
/// in personel_bolge_sistemi.dart and other screens
class IlModel extends Equatable {
  /// Unique province identifier (String-based for UI compatibility)
  final String id;

  /// Province name
  final String ad;

  /// License plate code (String-based for UI compatibility)
  final String plaka;

  /// Region ID this province belongs to
  final int bolgeId;

  /// Region name (for display purposes)
  final String bolge;

  /// List of districts in this province
  final List<String> ilceler;

  /// Color for UI display
  final Color renk;

  /// Total personnel count in this province
  final int toplamPersonel;

  /// Active personnel count in this province
  final int aktifPersonel;

  const IlModel({
    required this.id,
    required this.ad,
    required this.plaka,
    required this.bolgeId,
    this.bolge = '',
    required this.ilceler,
    required this.renk,
    this.toplamPersonel = 0,
    this.aktifPersonel = 0,
  });

  /// Create IlModel from Map
  factory IlModel.fromMap(Map<String, dynamic> map) {
    return IlModel(
      id: map['id']?.toString() ?? '',
      ad: map['ad']?.toString() ?? '',
      plaka: map['plaka']?.toString() ?? '',
      bolgeId: map['bolgeId'] is int ? map['bolgeId'] as int : int.tryParse(map['bolgeId']?.toString() ?? '0') ?? 0,
      bolge: map['bolge']?.toString() ?? '',
      ilceler: map['ilceler'] != null
          ? List<String>.from(map['ilceler'] as List)
          : [],
      renk: map['renk'] != null
          ? Color(int.parse(map['renk'].toString()))
          : Colors.grey[300]!,
      toplamPersonel: map['toplamPersonel'] is int
          ? map['toplamPersonel'] as int
          : int.tryParse(map['toplamPersonel']?.toString() ?? '0') ?? 0,
      aktifPersonel: map['aktifPersonel'] is int
          ? map['aktifPersonel'] as int
          : int.tryParse(map['aktifPersonel']?.toString() ?? '0') ?? 0,
    );
  }

  /// Create IlModel from JSON
  factory IlModel.fromJson(Map<String, dynamic> json) {
    return IlModel.fromMap(json);
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'plaka': plaka,
      'bolgeId': bolgeId,
      'bolge': bolge,
      'ilceler': ilceler,
      'renk': renk.toARGB32().toRadixString(16).padLeft(8, '0'),
      'toplamPersonel': toplamPersonel,
      'aktifPersonel': aktifPersonel,
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return toMap();
  }

  /// İl adı (UI beklentisi)
  String get ilAdi => ad;

  /// Copy with method for immutability
  IlModel copyWith({
    String? id,
    String? ad,
    String? plaka,
    int? bolgeId,
    String? bolge,
    List<String>? ilceler,
    Color? renk,
    int? toplamPersonel,
    int? aktifPersonel,
  }) {
    return IlModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      plaka: plaka ?? this.plaka,
      bolgeId: bolgeId ?? this.bolgeId,
      bolge: bolge ?? this.bolge,
      ilceler: ilceler ?? this.ilceler,
      renk: renk ?? this.renk,
      toplamPersonel: toplamPersonel ?? this.toplamPersonel,
      aktifPersonel: aktifPersonel ?? this.aktifPersonel,
    );
  }

  @override
  String toString() {
    return 'IlModel(id: $id, ad: $ad, plaka: $plaka, bolgeId: $bolgeId)';
  }

  @override
  List<Object?> get props => [id, ad, plaka, bolgeId, bolge, ilceler, renk, toplamPersonel, aktifPersonel];
}

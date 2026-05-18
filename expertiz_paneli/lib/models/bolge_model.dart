import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'il_model.dart';

/// Bölge Modeli - UI Compatible
///
/// This model is designed to work with the existing UI components
/// in personel_bolge_sistemi.dart and other screens
class BolgeModel extends Equatable {
  /// Unique region identifier (String-based for UI compatibility)
  final String id;

  /// Region name
  final String ad;

  /// Region color for UI display
  final Color renk;

  /// List of provinces in this region
  final List<IlModel> iller;

  const BolgeModel({
    required this.id,
    required this.ad,
    required this.renk,
    required this.iller,
  });

  /// Create BolgeModel from Map
  factory BolgeModel.fromMap(Map<String, dynamic> map) {
    return BolgeModel(
      id: map['id']?.toString() ?? '',
      ad: map['ad']?.toString() ?? '',
      renk: map['renk'] != null
          ? Color(int.parse(map['renk'].toString()))
          : Colors.blue,
      iller: map['iller'] != null
          ? (map['iller'] as List)
              .map((il) => IlModel.fromMap(il as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  /// Create BolgeModel from JSON
  factory BolgeModel.fromJson(Map<String, dynamic> json) {
    return BolgeModel.fromMap(json);
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ad': ad,
      'renk': renk.toARGB32().toRadixString(16).padLeft(8, '0'),
      'iller': iller.map((il) => il.toMap()).toList(),
    };
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return toMap();
  }

  /// Bölge adı (UI beklentisi)
  String get bolgeAdi => ad;

  /// Copy with method for immutability
  BolgeModel copyWith({
    String? id,
    String? ad,
    Color? renk,
    List<IlModel>? iller,
  }) {
    return BolgeModel(
      id: id ?? this.id,
      ad: ad ?? this.ad,
      renk: renk ?? this.renk,
      iller: iller ?? this.iller,
    );
  }

  @override
  String toString() {
    return 'BolgeModel(id: $id, ad: $ad, iller: ${iller.length})';
  }

  @override
  List<Object?> get props => [id, ad, renk, iller];
}

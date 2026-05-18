import 'package:flutter/material.dart';

/// BolgeStatViewModel - Region Statistics View Model
/// 
/// ARCHITECTURAL RULES:
/// - NO logic outside construction
/// - NO setters
/// - NO mutation
class BolgeStatViewModel {
  final int bolgeId;
  final String bolgeAdi;
  final int toplamIl;
  final int toplamPersonel;
  final Color renk;

  const BolgeStatViewModel({
    required this.bolgeId,
    required this.bolgeAdi,
    required this.toplamIl,
    required this.toplamPersonel,
    required this.renk,
  });

  /// CopyWith method for immutability
  BolgeStatViewModel copyWith({
    int? bolgeId,
    String? bolgeAdi,
    int? toplamIl,
    int? toplamPersonel,
    Color? renk,
  }) {
    return BolgeStatViewModel(
      bolgeId: bolgeId ?? this.bolgeId,
      bolgeAdi: bolgeAdi ?? this.bolgeAdi,
      toplamIl: toplamIl ?? this.toplamIl,
      toplamPersonel: toplamPersonel ?? this.toplamPersonel,
      renk: renk ?? this.renk,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BolgeStatViewModel && other.bolgeId == bolgeId;
  }

  @override
  int get hashCode => bolgeId.hashCode;
}

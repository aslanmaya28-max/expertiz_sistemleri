import 'package:flutter/material.dart';

/// IlStatViewModel - Province Statistics View Model
/// 
/// ARCHITECTURAL RULES:
/// - NO logic outside construction
/// - NO setters
/// - NO mutation
class IlStatViewModel {
  final int ilId;
  final String ilAdi;
  final int toplamPersonel;
  final int aktifPersonel;
  final Color bolgeRenk;

  const IlStatViewModel({
    required this.ilId,
    required this.ilAdi,
    required this.toplamPersonel,
    required this.aktifPersonel,
    required this.bolgeRenk,
  });

  /// CopyWith method for immutability
  IlStatViewModel copyWith({
    int? ilId,
    String? ilAdi,
    int? toplamPersonel,
    int? aktifPersonel,
    Color? bolgeRenk,
  }) {
    return IlStatViewModel(
      ilId: ilId ?? this.ilId,
      ilAdi: ilAdi ?? this.ilAdi,
      toplamPersonel: toplamPersonel ?? this.toplamPersonel,
      aktifPersonel: aktifPersonel ?? this.aktifPersonel,
      bolgeRenk: bolgeRenk ?? this.bolgeRenk,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IlStatViewModel && other.ilId == ilId;
  }

  @override
  int get hashCode => ilId.hashCode;
}

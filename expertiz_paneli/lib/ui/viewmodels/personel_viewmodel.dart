import '../../models/personel_model.dart';
import '../../core/mappers/location_mapper.dart';

/// PersonelViewModel - Enterprise Grade View Model
/// 
/// ARCHITECTURAL RULES:
/// - NO logic outside construction
/// - NO setters
/// - NO mutation
/// - Uses LocationMapper to resolve display names
class PersonelViewModel {
  final String id;
  final String fullName;
  final String unvan;
  final String ilAdi;
  final String bolgeAdi;

  const PersonelViewModel({
    required this.id,
    required this.fullName,
    required this.unvan,
    required this.ilAdi,
    required this.bolgeAdi,
  });

  /// Factory constructor from PersonelModel
  /// Uses LocationMapper to resolve ilAdi & bolgeAdi
  factory PersonelViewModel.fromModel(PersonelModel personel, LocationMapper mapper) {
    return PersonelViewModel(
      id: personel.id,
      fullName: '${personel.ad} ${personel.soyad}',
      unvan: personel.unvan,
      ilAdi: mapper.getIlAdi(personel.ilId),
      bolgeAdi: mapper.getBolgeAdi(personel.bolgeId),
    );
  }

  /// CopyWith method for immutability
  PersonelViewModel copyWith({
    String? id,
    String? fullName,
    String? unvan,
    String? ilAdi,
    String? bolgeAdi,
  }) {
    return PersonelViewModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      unvan: unvan ?? this.unvan,
      ilAdi: ilAdi ?? this.ilAdi,
      bolgeAdi: bolgeAdi ?? this.bolgeAdi,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersonelViewModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

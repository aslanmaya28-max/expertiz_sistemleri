/// Ekspertiz Paketi Modeli
class ExpertizPackage {
  final String id;
  final String name;
  final double price;
  final List<String> features;

  const ExpertizPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.features,
  });
}

/// Kurumsal Ekspertiz Firması Modeli
class ExpertizFirm {
  final String id;
  final String name;
  final String logoUrl; // Assets veya network
  final List<ExpertizPackage> packages;

  const ExpertizFirm({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.packages,
  });
}

// Firma / paket fiyatları admin panelinden yönetilir ve merkezi API'den
// (`GET /expertiz/packages`) okunur; burada sabit liste tutulmaz.

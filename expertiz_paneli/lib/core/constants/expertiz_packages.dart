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

/// Kurumsal Ekspertiz Verileri
class ExpertizPackages {
  static const List<ExpertizFirm> firms = [
    ExpertizFirm(
      id: "FIRM_001",
      name: "Pilot Garage",
      logoUrl: "assets/logos/pilot_garage.png",
      packages: [
        ExpertizPackage(
            id: "PG_ECO",
            name: "Ekonomik Paket",
            price: 3500.0,
            features: ["Kaporta/Boya", "Motor Mekanik", "Dyno Test"]),
        ExpertizPackage(
            id: "PG_STD",
            name: "Standart Paket",
            price: 4500.0,
            features: [
              "Kaporta/Boya",
              "Motor Mekanik",
              "Dyno Test",
              "Fren Testi",
              "Süspansiyon Testi"
            ]),
        ExpertizPackage(
            id: "PG_FULL",
            name: "Full Paket",
            price: 6000.0,
            features: [
              "Kaporta/Boya",
              "Motor Mekanik",
              "Dyno Test",
              "Fren Testi",
              "Süspansiyon Testi",
              "OBD Beyin Kontrol",
              "Airbag Kontrol"
            ]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_002",
      name: "Otorapor",
      logoUrl: "assets/logos/otorapor.png",
      packages: [
        ExpertizPackage(
            id: "OR_BRONZE",
            name: "Bronz Paket",
            price: 3250.0,
            features: ["Kaporta", "Motor", "Şanzıman"]),
        ExpertizPackage(
            id: "OR_SILVER",
            name: "Gümüş Paket",
            price: 4250.0,
            features: ["Kaporta", "Motor", "Şanzıman", "Alt Kontrol", "Yanal Kayma"]),
        ExpertizPackage(
            id: "OR_GOLD",
            name: "Altın Paket",
            price: 5750.0,
            features: [
              "Full Mekanik",
              "Kaporta Boya",
              "OBD",
              "Airbag",
              "Conta Kaçak Testi"
            ]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_003",
      name: "Tarcanlar Ekspertiz",
      logoUrl: "assets/logos/tarcanlar.png",
      packages: [
        ExpertizPackage(
            id: "TR_STD",
            name: "Standart Kontrol",
            price: 4000.0,
            features: ["Motor", "Kaporta", "Şase Kontrol"]),
        ExpertizPackage(
            id: "TR_PRO",
            name: "Profesyonel Kontrol",
            price: 5500.0,
            features: ["Motor", "Kaporta", "Şase", "Airbag", "Kilometre Teyit"]),
        ExpertizPackage(
            id: "TR_ELITE",
            name: "Elit Kontrol",
            price: 7000.0,
            features: ["Full Detaylı Ekspertiz + Yol Testi"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_004",
      name: "Dynomoss",
      logoUrl: "assets/logos/dynomoss.png",
      packages: [
        ExpertizPackage(id: "DM_1", name: "Eko", price: 3000.0, features: ["Dyno", "Boya"]),
        ExpertizPackage(id: "DM_2", name: "Orta", price: 4000.0, features: ["Dyno", "Boya", "Mekanik"]),
        ExpertizPackage(id: "DM_3", name: "Full", price: 5000.0, features: ["Full Paket"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_005",
      name: "Umran Oto Ekspertiz",
      logoUrl: "assets/logos/umran.png",
      packages: [
        ExpertizPackage(id: "UM_1", name: "Baz Paket", price: 3200.0, features: ["Kaporta", "Motor"]),
        ExpertizPackage(id: "UM_2", name: "Klasik Paket", price: 4200.0, features: ["Kaporta", "Motor", "Alt Takım"]),
        ExpertizPackage(id: "UM_3", name: "Premium Paket", price: 5500.0, features: ["Full + Conta Testi"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_006",
      name: "Eksperix",
      logoUrl: "assets/logos/eksperix.png",
      packages: [
        ExpertizPackage(id: "EX_1", name: "Eko", price: 2900.0, features: ["Boya", "Motor"]),
        ExpertizPackage(id: "EX_2", name: "Full", price: 4500.0, features: ["Boya", "Motor", "Mekanik"]),
        ExpertizPackage(id: "EX_3", name: "VIP", price: 5900.0, features: ["Full + Airbag"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_007",
      name: "Computest",
      logoUrl: "assets/logos/computest.png",
      packages: [
        ExpertizPackage(id: "CT_1", name: "Mobil", price: 3100.0, features: ["Temel Kontrol"]),
        ExpertizPackage(id: "CT_2", name: "Gold", price: 4100.0, features: ["Standart Kontrol"]),
        ExpertizPackage(id: "CT_3", name: "Platinum", price: 5200.0, features: ["Gelişmiş Kontrol"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_008",
      name: "Garantili Arabam",
      logoUrl: "assets/logos/garantili.png",
      packages: [
        ExpertizPackage(id: "GA_1", name: "Paket 1", price: 3300.0, features: ["Kaporta"]),
        ExpertizPackage(id: "GA_2", name: "Paket 2", price: 4400.0, features: ["Kaporta + Motor"]),
        ExpertizPackage(id: "GA_3", name: "Paket 3", price: 5600.0, features: ["Full"]),
      ],
    ),
     ExpertizFirm(
      id: "FIRM_009",
      name: "Dynobil",
      logoUrl: "assets/logos/dynobil.png",
      packages: [
        ExpertizPackage(id: "DB_1", name: "BASIC", price: 3000.0, features: ["Motor %"]),
        ExpertizPackage(id: "DB_2", name: "PLUS", price: 4000.0, features: ["Motor % + Kaporta"]),
        ExpertizPackage(id: "DB_3", name: "PREMIUM", price: 5300.0, features: ["Full Check-up"]),
      ],
    ),
    ExpertizFirm(
      id: "FIRM_010",
      name: "Auto King Ekspertiz",
      logoUrl: "assets/logos/autoking.png",
      packages: [
        ExpertizPackage(id: "AK_1", name: "King Eko", price: 3750.0, features: ["Temel"]),
        ExpertizPackage(id: "AK_2", name: "King Star", price: 4950.0, features: ["Orta"]),
        ExpertizPackage(id: "AK_3", name: "King Gold", price: 6500.0, features: ["Gelişmiş"]),
      ],
    ),
  ];
}

// ignore_for_file: non_constant_identifier_names

class AracMarka {
  final String marka;
  final List<String> modeller;

  AracMarka({required this.marka, required this.modeller});
}

class AracTipi {
  final String tipi;
  final List<AracMarka> markalar;

  AracTipi({required this.tipi, required this.markalar});
}

final List<AracTipi> aracVeri = [
  // OTOMOBİL - 20 Marka
  AracTipi(
    tipi: "Otomobil",
    markalar: [
      AracMarka(marka: "Fiat", modeller: ["Egea Sedan", "Egea HB", "Linea", "Punto", "Bravo"]),
      AracMarka(marka: "Renault", modeller: ["Clio", "Megane", "Symbol", "Fluence", "Talisman"]),
      AracMarka(marka: "Peugeot", modeller: ["208", "308", "408", "508"]),
      AracMarka(marka: "Citroen", modeller: ["C3", "C4", "C5", "C-Elysee"]),
      AracMarka(marka: "Volkswagen", modeller: ["Polo", "Golf", "Passat", "Jetta"]),
      AracMarka(marka: "Opel", modeller: ["Corsa", "Astra", "Insignia"]),
      AracMarka(marka: "Hyundai", modeller: ["i10", "i20", "i30", "Elantra"]),
      AracMarka(marka: "Toyota", modeller: ["Corolla", "Yaris", "Camry"]),
      AracMarka(marka: "Honda", modeller: ["Civic", "City", "Accord"]),
      AracMarka(marka: "Ford", modeller: ["Fiesta", "Focus", "Mondeo"]),
      AracMarka(marka: "Kia", modeller: ["Rio", "Ceed", "Stinger"]),
      AracMarka(marka: "Skoda", modeller: ["Fabia", "Octavia", "Superb"]),
      AracMarka(marka: "Seat", modeller: ["Ibiza", "Leon", "Tarraco"]),
      AracMarka(marka: "Alfa Romeo", modeller: ["Giulia", "Stelvio"]),
      AracMarka(marka: "Audi", modeller: ["A1", "A3", "A4", "A6"]),
      AracMarka(marka: "BMW", modeller: ["1 Serisi", "3 Serisi", "5 Serisi"]),
      AracMarka(marka: "Mercedes", modeller: ["A Serisi", "C Serisi", "E Serisi"]),
      AracMarka(marka: "Mini", modeller: ["Cooper", "Cooper S", "Clubman"]),
      AracMarka(marka: "Lexus", modeller: ["IS", "ES", "NX"]),
      AracMarka(marka: "Mazda", modeller: ["Mazda3", "Mazda6", "CX-3"]),
    ],
  ),

  // SUV & PICKUP - 15 Marka
  AracTipi(
    tipi: "SUV & Pickup",
    markalar: [
      AracMarka(marka: "Toyota", modeller: ["RAV4", "Hilux", "C-HR"]),
      AracMarka(marka: "Hyundai", modeller: ["Kona", "Tucson", "Santa Fe"]),
      AracMarka(marka: "Peugeot", modeller: ["2008", "3008", "5008"]),
      AracMarka(marka: "Dacia", modeller: ["Duster", "Jogger", "Sandero Stepway"]),
      AracMarka(marka: "Nissan", modeller: ["Qashqai", "Juke", "X-Trail", "Navara"]),
      AracMarka(marka: "Volkswagen", modeller: ["T-Roc", "Tiguan", "Amarok"]),
      AracMarka(marka: "Mitsubishi", modeller: ["ASX", "Outlander", "L200"]),
      AracMarka(marka: "Ford", modeller: ["Kuga", "Puma", "Ranger"]),
      AracMarka(marka: "Jeep", modeller: ["Renegade", "Compass", "Cherokee"]),
      AracMarka(marka: "Mazda", modeller: ["CX-3", "CX-5", "CX-60"]),
      AracMarka(marka: "Subaru", modeller: ["Forester", "XV", "Outback"]),
      AracMarka(marka: "Land Rover", modeller: ["Range Rover Evoque", "Discovery Sport"]),
      AracMarka(marka: "Audi", modeller: ["Q2", "Q3", "Q5", "Q7"]),
      AracMarka(marka: "BMW", modeller: ["X1", "X3", "X5"]),
      AracMarka(marka: "Mercedes", modeller: ["GLA", "GLC", "GLE"]),
    ],
  ),

  // ELEKTRİKLİ ARAÇLAR - 13 Marka
  AracTipi(
    tipi: "Elektrikli Araçlar",
    markalar: [
      AracMarka(marka: "Tesla", modeller: ["Model 3", "Model Y", "Model S", "Model X"]),
      AracMarka(marka: "Renault", modeller: ["ZOE", "Megane E-Tech"]),
      AracMarka(marka: "Fiat", modeller: ["500e"]),
      AracMarka(marka: "Hyundai", modeller: ["IONIQ 5", "Kona EV"]),
      AracMarka(marka: "BMW", modeller: ["i3", "i4", "iX"]),
      AracMarka(marka: "Mercedes", modeller: ["EQA", "EQB", "EQE", "EQS"]),
      AracMarka(marka: "Volkswagen", modeller: ["ID.3", "ID.4"]),
      AracMarka(marka: "Volvo", modeller: ["C40", "XC40 Recharge"]),
      AracMarka(marka: "Peugeot", modeller: ["e-208", "e-2008"]),
      AracMarka(marka: "TOGG", modeller: ["T10X", "T8X"]),
      AracMarka(marka: "MG", modeller: ["ZS EV", "5 EV"]),
      AracMarka(marka: "BYD", modeller: ["Han EV", "Tang EV"]),
      AracMarka(marka: "Cupra", modeller: ["Born"]),
    ],
  ),

  // MİNİVAN & PANELVAN - 12 Marka
  AracTipi(
    tipi: "Minivan & Panelvan",
    markalar: [
      AracMarka(marka: "Fiat", modeller: ["Fiorino", "Doblo", "Scudo", "Talento"]),
      AracMarka(marka: "Ford", modeller: ["Tourneo Courier", "Transit Custom", "Connect"]),
      AracMarka(marka: "Renault", modeller: ["Kangoo", "Trafic", "Master"]),
      AracMarka(marka: "Volkswagen", modeller: ["Caddy", "Transporter", "Caravelle"]),
      AracMarka(marka: "Peugeot", modeller: ["Rifter", "Traveller", "Expert"]),
      AracMarka(marka: "Citroen", modeller: ["Berlingo", "Spacetourer", "Jumpy"]),
      AracMarka(marka: "Mercedes", modeller: ["Citan", "Vito", "Sprinter"]),
      AracMarka(marka: "Opel", modeller: ["Combo", "Vivaro", "Movano"]),
      AracMarka(marka: "Toyota", modeller: ["ProAce City", "ProAce Verso"]),
      AracMarka(marka: "Hyundai", modeller: ["H-1", "Staria"]),
      AracMarka(marka: "Nissan", modeller: ["NV200", "e-NV200"]),
      AracMarka(marka: "Mitsubishi", modeller: ["L300", "Delica"]),
    ],
  ),
];

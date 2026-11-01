/**
 * Araç formu yardımcıları: Türkiye pazarı marka/model kataloğu, Türkçe arama ve binlik biçimleme.
 * Katalog yalnız kolaylık içindir; listede olmayan marka/model yazıldığı gibi kabul edilir.
 */

export const ARAC_KATALOGU: Record<string, string[]> = {
  "Alfa Romeo": ["Giulia", "Giulietta", "Junior", "Stelvio", "Tonale"],
  Audi: ["A1", "A3", "A4", "A5", "A6", "A7", "A8", "e-tron", "Q2", "Q3", "Q4 e-tron", "Q5", "Q7", "Q8", "TT"],
  BMW: ["1 Serisi", "2 Serisi", "3 Serisi", "4 Serisi", "5 Serisi", "7 Serisi", "i4", "i5", "i7", "iX", "iX1", "iX3", "X1", "X2", "X3", "X4", "X5", "X6", "X7", "Z4"],
  BYD: ["Atto 2", "Atto 3", "Dolphin", "Han", "Seal", "Seal U", "Seal U DM-i", "Sealion 7", "Tang"],
  Chery: ["Tiggo 4", "Tiggo 7", "Tiggo 8"],
  Chevrolet: ["Aveo", "Captiva", "Cruze", "Spark"],
  Citroen: ["Berlingo", "C-Elysee", "C3", "C3 Aircross", "C4", "C4 X", "C5 Aircross", "C5 X", "e-C4"],
  Cupra: ["Ateca", "Born", "Formentor", "Leon", "Tavascan"],
  Dacia: ["Bigster", "Duster", "Jogger", "Logan", "Sandero", "Sandero Stepway", "Spring"],
  DS: ["DS 3", "DS 4", "DS 7", "DS 9"],
  Fiat: ["500", "500L", "500X", "600", "Doblo", "Egea", "Egea Cross", "Fiorino", "Linea", "Panda", "Punto", "Tipo", "Topolino"],
  Ford: ["C-Max", "Fiesta", "Focus", "Kuga", "Mondeo", "Mustang Mach-E", "Puma", "Ranger", "Tourneo Connect", "Tourneo Courier", "Tourneo Custom", "Transit", "Transit Courier", "Transit Custom"],
  Honda: ["City", "Civic", "CR-V", "e:Ny1", "HR-V", "Jazz", "ZR-V"],
  Hyundai: ["Accent Blue", "Bayon", "Elantra", "Getz", "i10", "i20", "i30", "IONIQ 5", "IONIQ 6", "Kona", "Santa Fe", "Tucson"],
  Isuzu: ["D-Max"],
  Jaecoo: ["7"],
  Jeep: ["Avenger", "Compass", "Grand Cherokee", "Renegade", "Wrangler"],
  Kia: ["Ceed", "Ceed SW", "Cerato", "EV3", "EV6", "EV9", "Niro", "Picanto", "Rio", "Sorento", "Sportage", "Stonic", "XCeed"],
  "Land Rover": ["Defender", "Discovery", "Discovery Sport", "Range Rover", "Range Rover Evoque", "Range Rover Sport", "Range Rover Velar"],
  Leapmotor: ["C10", "T03"],
  Lexus: ["ES", "LBX", "NX", "RX", "UX"],
  Mazda: ["2", "3", "6", "CX-3", "CX-30", "CX-5", "CX-60"],
  "Mercedes-Benz": ["A Serisi", "B Serisi", "C Serisi", "CLA", "CLS", "E Serisi", "EQA", "EQB", "EQE", "EQS", "G Serisi", "GLA", "GLB", "GLC", "GLE", "GLS", "S Serisi", "Citan", "Sprinter", "V Serisi", "Vito"],
  MG: ["Cyberster", "HS", "Marvel R", "MG3", "MG4", "MG5", "ZS"],
  MINI: ["Aceman", "Clubman", "Cooper", "Countryman"],
  Mitsubishi: ["ASX", "Eclipse Cross", "L200", "Outlander", "Space Star"],
  Nissan: ["Juke", "Leaf", "Micra", "Navara", "Note", "Qashqai", "X-Trail"],
  Omoda: ["5", "E5"],
  Opel: ["Astra", "Combo", "Corsa", "Crossland", "Grandland", "Insignia", "Meriva", "Mokka", "Vivaro", "Zafira"],
  Peugeot: ["208", "2008", "301", "308", "3008", "408", "508", "5008", "e-208", "e-2008", "Expert", "Partner", "Rifter", "Traveller"],
  Porsche: ["911", "Cayenne", "Macan", "Panamera", "Taycan"],
  Renault: ["Arkana", "Austral", "Captur", "Clio", "Fluence", "Kadjar", "Kangoo", "Koleos", "Megane", "Megane Sedan", "Rafale", "Symbioz", "Symbol", "Taliant", "Talisman", "Trafic", "Zoe"],
  Seat: ["Arona", "Ateca", "Ibiza", "Leon", "Tarraco", "Toledo"],
  Skoda: ["Elroq", "Enyaq", "Fabia", "Kamiq", "Karoq", "Kodiaq", "Octavia", "Rapid", "Scala", "Superb"],
  Smart: ["#1", "#3", "ForFour", "ForTwo"],
  Subaru: ["Forester", "Impreza", "Outback", "XV"],
  Suzuki: ["Jimny", "S-Cross", "Swift", "SX4", "Vitara"],
  Tesla: ["Model 3", "Model S", "Model X", "Model Y"],
  Togg: ["T10F", "T10X"],
  Toyota: ["Auris", "bZ4X", "C-HR", "Camry", "Corolla", "Corolla Cross", "Hilux", "Land Cruiser", "Proace City", "RAV4", "Yaris", "Yaris Cross"],
  Volkswagen: ["Amarok", "Arteon", "Caddy", "Caravelle", "Golf", "ID.3", "ID.4", "ID.5", "ID.7", "Jetta", "Passat", "Passat Variant", "Polo", "Scirocco", "T-Cross", "T-Roc", "Taigo", "Tiguan", "Tiguan Allspace", "Touareg", "Touran", "Transporter"],
  Volvo: ["C40", "EX30", "EX40", "S60", "S90", "V40", "V60", "XC40", "XC60", "XC90"],
};

export const MARKALAR = Object.keys(ARAC_KATALOGU).sort((a, b) => a.localeCompare(b, "tr"));

/** Arama için Türkçe ve aksanlı harfleri sadeleştirir (Ş→s, İ/ı→i, ë→e ...). */
export function sadelestir(metin: string): string {
  return metin
    .replace(/İ/g, "i")
    .replace(/I/g, "i")
    .replace(/ı/g, "i")
    .toLocaleLowerCase("tr")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9#]+/g, " ")
    .trim();
}

/** Seçenekleri sorguya göre süzer: önce başı eşleşenler, sonra içinde geçenler. */
export function katalogAra(secenekler: string[], sorgu: string, sinir = 50): string[] {
  const s = sadelestir(sorgu);
  if (!s) return secenekler.slice(0, sinir);
  const bas: string[] = [];
  const ic: string[] = [];
  for (const secenek of secenekler) {
    const d = sadelestir(secenek);
    if (d.startsWith(s) || d.split(" ").some((kelime) => kelime.startsWith(s))) bas.push(secenek);
    else if (d.replace(/ /g, "").includes(s.replace(/ /g, ""))) ic.push(secenek);
  }
  return [...bas, ...ic].slice(0, sinir);
}

/** Markanın katalogdaki modelleri (marka yazımı farklı olsa da: "mercedes", "Škoda"). */
export function modelleri(marka: string): string[] {
  const s = sadelestir(marka);
  if (!s) return [];
  const anahtar = MARKALAR.find((m) => sadelestir(m) === s || sadelestir(m).replace(/ /g, "") === s.replace(/ /g, ""));
  return anahtar ? ARAC_KATALOGU[anahtar] : [];
}

/** Yalnız rakamlar (yapıştırılan "24.000 km" → "24000"); baştaki sıfırlar atılır. */
export function sadeceRakam(metin: string, enFazlaHane = 12): string {
  return metin.replace(/\D/g, "").replace(/^0+(?=\d)/, "").slice(0, enFazlaHane);
}

/** "24000" → "24.000" (gösterim için; formda ham rakamlar saklanır). */
export function binlikNokta(rakamlar: string): string {
  return rakamlar.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

/** Gönderimden önce kısa kontrol (sunucu da aynı sınırları denetler, kredi düşmeden). */
export function degerlemeFormHatasi(f: { year: string; km: string; price: string }, buYil = new Date().getFullYear()): string | null {
  const yil = Number(f.year);
  if (!f.year || yil < 1980 || yil > buYil + 1) return `Model yılı 1980 ile ${buYil + 1} arasında olmalı.`;
  if (Number(f.km) > 2_000_000) return "Kilometre en fazla 2.000.000 olabilir.";
  const fiyat = Number(f.price);
  if (!f.price || fiyat < 10_000 || fiyat > 200_000_000) return "İlan fiyatı 10.000 ₺ ile 200.000.000 ₺ arasında olmalı.";
  return null;
}

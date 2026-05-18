# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Türkiye 2. El Piyasası Hedef Araç Listesi
Segment bazlı, öncelik sıralı, 2012-2026 yıl aralığı.

Kapsam: ~%85-90 Türkiye 2. el piyasası talep hacmi
"""

# ─── Yıl Aralığı ─────────────────────────────────────────────────────────────
YEARS_RANGE = list(range(2012, 2027))  # 2012-2026 (15 yıl) ✅ GÜNCELLENDİ

# ─── Hedef Araçlar ───────────────────────────────────────────────────────────
# Format: (marka, model, segment, öncelik)
# Öncelik: 1=en yüksek hacim (önce çek), 2=orta, 3=ikincil
TURKEY_2EL_TARGETS = [

    # ── B-Segment (Küçük / Şehir içi) ────────────────────────────────────────
    ("Renault",   "Clio",       "B", 1),   # B-seg lideri
    ("Renault",   "Symbol",     "B", 1),
    ("Volkswagen","Polo",       "B", 1),
    ("Hyundai",   "i20",        "B", 1),
    ("Ford",      "Fiesta",     "B", 2),
    ("Opel",      "Corsa",      "B", 2),
    ("Dacia",     "Sandero",    "B", 1),   # uygun fiyat lideri
    ("Peugeot",   "301",        "B", 2),
    ("Citroen",   "C-Elysee",   "B", 2),
    ("Seat",      "Ibiza",      "B", 2),
    ("Suzuki",    "Swift",      "B", 2),   # ✅ JAPON EKLENDİ
    ("Nissan",    "Micra",      "B", 2),   # ✅ JAPON EKLENDİ

    # ── C-Segment (Orta Sınıf / Aile) ────────────────────────────────────────
    # En yüksek hacimli segment (~%50 pazar payı)
    ("Fiat",      "Egea",       "C", 1),   # C-seg toplam lideri
    ("Renault",   "Megane",     "C", 1),
    ("Ford",      "Focus",      "C", 1),
    ("Toyota",    "Corolla",    "C", 1),
    ("Opel",      "Astra",      "C", 1),
    ("Fiat",      "Linea",      "C", 2),
    ("Volkswagen","Golf",       "C", 1),
    ("Honda",     "Civic",      "C", 1),
    ("Renault",   "Fluence",    "C", 2),
    ("Hyundai",   "Accent",     "C", 2),
    ("Mazda",     "3",          "C", 1),   # ✅ JAPON EKLENDİ
    ("Nissan",    "Qashqai",    "C", 1),   # ✅ JAPON EKLENDİ (SUV/C arası)
    ("Mitsubishi","Lancer",     "C", 2),   # ✅ JAPON EKLENDİ
    ("MG",        "ZS",         "C", 2),   # ✅ ÇİN EKLENDİ

    # ── D-Segment (Üst-Orta / Prestij Aile) ──────────────────────────────────
    ("Volkswagen","Passat",     "D", 1),
    ("BMW",       "3 Serisi",   "D", 1),
    ("Mercedes",  "C-Class",    "D", 1),
    ("Skoda",     "Superb",     "D", 2),
    ("Audi",      "A4",         "D", 2),
    ("Opel",      "Insignia",   "D", 2),
    ("Mazda",     "6",          "D", 2),   # ✅ JAPON EKLENDİ
    ("Subaru",    "Legacy",     "D", 3),   # ✅ JAPON EKLENDİ
    ("Volvo",     "S60",        "D", 2),   # ✅ İSTİSNİ MARKA
    ("Lexus",     "IS",         "D", 3),   # ✅ JAPON (Lüks)

    # ── SUV / Crossover (En Çok Satanlar & VAG Grubu) ────────────────────────
    # 2024 verilerinde SUV segmenti toplam satışların %56'sını oluşturuyor.
    ("Dacia",     "Duster",     "SUV", 1),
    ("Nissan",    "Qashqai",    "SUV", 1),
    ("Hyundai",   "Tucson",     "SUV", 1),
    ("Peugeot",   "2008",       "SUV", 1),
    ("Peugeot",   "3008",       "SUV", 2),
    ("Volkswagen","T-Roc",      "SUV", 1),   # Popüler
    ("Volkswagen","Taigo",      "SUV", 1),   # Popüler
    ("Volkswagen","Tiguan",     "SUV", 1),   # Çok Satan
    ("Volkswagen","T-Cross",    "SUV", 2),
    ("Volkswagen","Touareg",    "SUV", 3),   # Premium/Nadir
    ("Audi",      "Q2",         "SUV", 2),
    ("Audi",      "Q3",         "SUV", 1),   # Popüler
    ("Audi",      "Q5",         "SUV", 2),
    ("Audi",      "Q7",         "SUV", 3),
    ("Skoda",     "Kamiq",      "SUV", 2),
    ("Skoda",     "Karoq",      "SUV", 2),
    ("Skoda",     "Kodiaq",     "SUV", 2),
    ("Seat",      "Arona",      "SUV", 1),   # Popüler
    ("Seat",      "Ateca",      "SUV", 2),
    ("Cupra",     "Formentor",  "SUV", 2),   # Popülerleşen
    ("Cupra",     "Ateca",      "SUV", 3),
    ("Hyundai",   "Bayon",      "SUV", 2),
    ("Dacia",     "Sandero Stepway", "SUV", 1),
    ("Mazda",     "CX-5",       "SUV", 1),   # ✅ JAPON EKLENDİ
    ("Mazda",     "CX-30",      "SUV", 2),   # ✅ JAPON EKLENDİ
    ("Subaru",    "Forester",   "SUV", 2),   # ✅ JAPON EKLENDİ
    ("Subaru",    "XV",         "SUV", 3),   # ✅ JAPON EKLENDİ
    ("Suzuki",    "Vitara",     "SUV", 2),   # ✅ JAPON EKLENDİ
    ("MG",        "HS",         "SUV", 2),   # ✅ ÇİN EKLENDİ
    ("Chery",     "Tiggo 8",    "SUV", 2),   # ✅ ÇİN EKLENDİ
    ("Great Wall","Ora",        "SUV", 3),   # ✅ ÇİN EKLENDİ
    ("Haval",     "H6",         "SUV", 3),   # ✅ ÇİN EKLENDİ

    # ── Hafif Ticari / Van ────────────────────────────────────────────────────
    ("Fiat",      "Doblo",           "Ticari", 1),
    ("Ford",      "Transit Courier", "Ticari", 1),
    ("Ford",      "Transit",         "Ticari", 1),
    ("Fiat",      "Fiorino",         "Ticari", 1),
    ("Volkswagen","Caddy",           "Ticari", 2),
    ("Renault",   "Kangoo",          "Ticari", 2),
    ("Peugeot",   "Partner",         "Ticari", 2),

    # ── Elektrikli ────────────────────────────────────────────────────────────
    ("Togg",      "T10X",       "EV", 2),
    ("Togg",      "T10F",       "EV", 2),
    ("Tesla",     "Model Y",    "EV", 2),
    ("Tesla",     "Model 3",    "EV", 2),
    ("Volvo",     "EX30",       "EV", 3),
    ("Opel",      "Mokka",      "EV", 3),
    ("MG",        "4",          "EV", 3),   # ✅ ÇİN EKLENDİ
    ("MG",        "ZS EV",      "EV", 3),   # ✅ ÇİN EKLENDİ
    ("BYD",       "Atto 3",     "EV", 2),   # ✅ ÇİN EKLENDİ
    ("BYD",       "Seal",       "EV", 3),   # ✅ ÇİN EKLENDİ
    ("BYD",       "Dolphin",    "EV", 3),   # ✅ ÇİN EKLENDİ
]

# ─── Segment Etiketleri ──────────────────────────────────────────────────────
SEGMENT_LABELS = {
    "B":      "🅱️ B-Segment (Küçük)",
    "C":      "🅲 C-Segment (Orta)",
    "D":      "🅳 D-Segment (Üst-Orta)",
    "SUV":    "🚙 SUV/Crossover",
    "Ticari": "🚚 Hafif Ticari",
    "EV":     "⚡ Elektrikli",
}

# ─── Öncelik Kuyruğu ─────────────────────────────────────────────────────────
def get_priority_queue(max_results: int = None):
    """
    Araçları öncelik sırasına göre döndürür (önce 1, sonra 2, sonra 3).
    Returns: List[(marka, model, segment, oncelik)]
    """
    sorted_targets = sorted(TURKEY_2EL_TARGETS, key=lambda x: x[3])
    if max_results:
        return sorted_targets[:max_results]
    return sorted_targets


def get_segments_summary():
    """Segment bazlı özet istatistikler."""
    from collections import Counter
    seg_counts = Counter(t[2] for t in TURKEY_2EL_TARGETS)
    result = {}
    for seg, count in seg_counts.items():
        result[seg] = {
            "label": SEGMENT_LABELS.get(seg, seg),
            "model_count": count,
            "models": [t[1] for t in TURKEY_2EL_TARGETS if t[2] == seg],
        }
    return result


def get_years_for_segment(segment: str):
    """
    EV segmenti için daha kısa yıl aralığı (2020+), 
    diğerleri için tam 2012-2026.
    """
    if segment == "EV":
        return list(range(2020, 2027))  # ✅ GÜNCELLENDİ
    if segment == "Ticari":
        return list(range(2012, 2027))  # Ticari araçlar daha uzun kullanılır
    return YEARS_RANGE


if __name__ == "__main__":
    summary = get_segments_summary()
    total = len(TURKEY_2EL_TARGETS)
    print(f"{'='*60}")
    print(f"  YERİMEBAK AI — Piyasa Hedef Listesi Özeti")
    print(f"{'='*60}")
    for seg, info in summary.items():
        print(f"\n{info['label']}")
        print(f"  Model sayısı : {info['model_count']}")
        print(f"  Modeller     : {', '.join(info['models'])}")
    
    print(f"\n{'='*60}")
    print(f"  Toplam Model       : {total}")
    print(f"  Yıl Aralığı        : 2012-2026 (15 yıl)")
    print(f"  Piyasa Kapsamı     : ~%85-90 Türkiye 2. el talep hacmi")
    print(f"{'='*60}")
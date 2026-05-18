# YERİMEBAK AI v8.0 - Analysis Service Constants

# Marka Bazlı Segmentler
MARKA_SEGMENTI = {
    "premium": {
        "markalar": ["bmw", "mercedes", "audi", "porsche", "lexus", "volvo", "infiniti", "jaguar", "land rover"],
        "yillik_kayip": 0.13,
        "baz_fiyat_carpan": 2.8,
    },
    "orta": {
        "markalar": ["volkswagen", "vw", "seat", "skoda", "honda", "toyota", "hyundai", "kia", "mazda", "subaru"],
        "yillik_kayip": 0.15,
        "baz_fiyat_carpan": 1.6,
    },
    "ekonomi": {
        "markalar": ["renault", "fiat", "peugeot", "citroen", "ford", "opel", "dacia", "chevrolet"],
        "yillik_kayip": 0.17,
        "baz_fiyat_carpan": 1.0,
    },
}

# Parça Bazlı Hasar Katsayıları
PARCA_HASAR_KATSAYI = {
    "tavan": 0.08,
    "ön kaput": 0.04,
    "arka kaput": 0.04,
    "sağ ön kapı": 0.035,
    "sol ön kapı": 0.035,
    "sağ arka kapı": 0.03,
    "sol arka kapı": 0.03,
    "ön tampon": 0.03,
    "arka tampon": 0.025,
    "sağ ön çamurluk": 0.025,
    "sol ön çamurluk": 0.025,
    "sağ arka çamurluk": 0.02,
    "sol arka çamurluk": 0.02,
    "bağlantı kolu": 0.015,
    "diğer": 0.02,
}

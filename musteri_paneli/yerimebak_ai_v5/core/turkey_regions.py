# -*- coding: utf-8 -*-
"""
Türkiye il / coğrafi bölge referans verisi.

Personel kapsama, talep yönlendirme ve bölge raporları için tek kaynak.
81 il, plaka kodu ve resmi 7 coğrafi bölge eşleşmesi.
Flutter tarafındaki `LocationMapper` ile aynı ID'leri kullanır.
"""
from typing import Dict, List, Optional

REGIONS: Dict[int, str] = {
    1: "Marmara",
    2: "İç Anadolu",
    3: "Ege",
    4: "Akdeniz",
    5: "Karadeniz",
    6: "Doğu Anadolu",
    7: "Güneydoğu Anadolu",
}

# plaka -> (il adı, bölge id)
PROVINCES: Dict[int, tuple] = {
    1: ("Adana", 4),
    2: ("Adıyaman", 7),
    3: ("Afyonkarahisar", 3),
    4: ("Ağrı", 6),
    5: ("Amasya", 5),
    6: ("Ankara", 2),
    7: ("Antalya", 4),
    8: ("Artvin", 5),
    9: ("Aydın", 3),
    10: ("Balıkesir", 1),
    11: ("Bilecik", 1),
    12: ("Bingöl", 6),
    13: ("Bitlis", 6),
    14: ("Bolu", 5),
    15: ("Burdur", 4),
    16: ("Bursa", 1),
    17: ("Çanakkale", 1),
    18: ("Çankırı", 2),
    19: ("Çorum", 5),
    20: ("Denizli", 3),
    21: ("Diyarbakır", 7),
    22: ("Edirne", 1),
    23: ("Elazığ", 6),
    24: ("Erzincan", 6),
    25: ("Erzurum", 6),
    26: ("Eskişehir", 2),
    27: ("Gaziantep", 7),
    28: ("Giresun", 5),
    29: ("Gümüşhane", 5),
    30: ("Hakkari", 6),
    31: ("Hatay", 4),
    32: ("Isparta", 4),
    33: ("Mersin", 4),
    34: ("İstanbul", 1),
    35: ("İzmir", 3),
    36: ("Kars", 6),
    37: ("Kastamonu", 5),
    38: ("Kayseri", 2),
    39: ("Kırklareli", 1),
    40: ("Kırşehir", 2),
    41: ("Kocaeli", 1),
    42: ("Konya", 2),
    43: ("Kütahya", 3),
    44: ("Malatya", 6),
    45: ("Manisa", 3),
    46: ("Kahramanmaraş", 4),
    47: ("Mardin", 7),
    48: ("Muğla", 3),
    49: ("Muş", 6),
    50: ("Nevşehir", 2),
    51: ("Niğde", 2),
    52: ("Ordu", 5),
    53: ("Rize", 5),
    54: ("Sakarya", 1),
    55: ("Samsun", 5),
    56: ("Siirt", 7),
    57: ("Sinop", 5),
    58: ("Sivas", 2),
    59: ("Tekirdağ", 1),
    60: ("Tokat", 5),
    61: ("Trabzon", 5),
    62: ("Tunceli", 6),
    63: ("Şanlıurfa", 7),
    64: ("Uşak", 3),
    65: ("Van", 6),
    66: ("Yozgat", 2),
    67: ("Zonguldak", 5),
    68: ("Aksaray", 2),
    69: ("Bayburt", 5),
    70: ("Karaman", 2),
    71: ("Kırıkkale", 2),
    72: ("Batman", 7),
    73: ("Şırnak", 7),
    74: ("Bartın", 5),
    75: ("Ardahan", 6),
    76: ("Iğdır", 6),
    77: ("Yalova", 1),
    78: ("Karabük", 5),
    79: ("Kilis", 7),
    80: ("Osmaniye", 4),
    81: ("Düzce", 5),
}

BIG_CITY_PLATES = {34, 6, 35, 16, 7, 42, 1, 27, 41}

_ASCII_FOLD = str.maketrans({
    "ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u",
})

# Yaygın alternatif yazımlar
_ALIASES = {
    "icel": 33,
    "afyon": 3,
    "maras": 46,
    "k.maras": 46,
    "urfa": 63,
    "antep": 27,
    "hakkâri": 30,
}


def _fold(value: str) -> str:
    text = (value or "").strip()
    # Türkçe büyük harfleri doğru küçült
    text = text.replace("İ", "i").replace("I", "ı").lower()
    return text.translate(_ASCII_FOLD)


_NAME_INDEX: Dict[str, int] = {_fold(name): plate for plate, (name, _) in PROVINCES.items()}
_NAME_INDEX.update({_fold(alias): plate for alias, plate in _ALIASES.items()})


def province_plate(value: Optional[str]) -> Optional[int]:
    """İl adını (ör. 'istanbul', 'İSTANBUL', 'Istanbul / Kadıköy', '34') plaka koduna çevirir."""
    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    if raw.isdigit():
        plate = int(raw)
        return plate if plate in PROVINCES else None
    # 'İstanbul / Kadıköy', 'Kadıköy, İstanbul' gibi değerleri parçala
    candidates = [raw]
    for separator in ("/", ",", "-", "(", " "):
        if separator in raw:
            candidates.extend(part.strip(" )") for part in raw.split(separator) if part.strip(" )"))
    for candidate in candidates:
        plate = _NAME_INDEX.get(_fold(candidate))
        if plate:
            return plate
    return None


def province_name(plate: Optional[int]) -> str:
    if plate is None or plate not in PROVINCES:
        return ""
    return PROVINCES[plate][0]


def region_id_of(plate: Optional[int]) -> Optional[int]:
    if plate is None or plate not in PROVINCES:
        return None
    return PROVINCES[plate][1]


def region_name(region_id: Optional[int]) -> str:
    return REGIONS.get(region_id or 0, "")


def describe_city(value: Optional[str]) -> Dict[str, object]:
    """Serbest metin şehirden il/bölge bilgisini çıkarır."""
    plate = province_plate(value)
    region_id = region_id_of(plate)
    return {
        "il_id": plate,
        "city": province_name(plate) if plate else (str(value or "").split("/")[0].strip()),
        "region_id": region_id,
        "region": region_name(region_id),
    }


def minimum_target(plate: Optional[int]) -> int:
    return 3 if plate in BIG_CITY_PLATES else 1


def provinces_in_region(region_id: int) -> List[int]:
    return sorted(plate for plate, (_, rid) in PROVINCES.items() if rid == region_id)

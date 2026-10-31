# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Pydantic Enums
All enum definitions for data models
"""

from enum import Enum


class FuelType(str, Enum):
    """Yakıt tipi enum"""
    BENZIN = "Benzin"
    DIZEL = "Dizel"
    LPG = "LPG"
    HIBRIT = "Hibrit"
    ELEKTRIK = "Elektrik"
    HYBRID = "Hybrid"
    PLUG_IN_HYBRID = "Plug-in Hibrit"
    UNKNOWN = "Bilinmiyor"


class GearType(str, Enum):
    """Vites tipi enum"""
    MANUEL = "Manuel"
    OTOMATIK = "Otomatik"
    YARI_OTOMATIK = "Yarı Otomatik"
    SEMI_AUTOMATIC = "Yarı Otomatik"
    DCT = "DCT"
    CVT = "CVT"
    TIPTRONIC = "Tiptronic"
    UNKNOWN = "Bilinmiyor"


class PaintStatus(str, Enum):
    """Boya durumu enum - KRİTİK"""
    ORIGINAL = "Orjinal/Boyasız"
    PAINTED = "Boyalı"
    CHANGED = "Değişen"
    MIXED = "Karma"
    UNKNOWN = "Bilinmiyor"


class BodyType(str, Enum):
    """Kasa tipi enum"""
    SEDAN = "Sedan"
    HATCHBACK = "Hatchback"
    SUV = "SUV"
    MPV = "MPV"
    COUPE = "Coupe"
    CABRIO = "Cabrio"
    STATION_WAGON = "Station Wagon"
    PICKUP = "Pick-up"
    CROSSOVER = "Crossover"
    ROADSTER = "Roadster"
    UNKNOWN = "Bilinmiyor"


class Color(str, Enum):
    """Renk enum"""
    WHITE = "Beyaz"
    BLACK = "Siyah"
    GREY = "Gri"
    SILVER = "Gümüş"
    BLUE = "Mavi"
    RED = "Kırmızı"
    BROWN = "Kahverengi"
    BEIGE = "Bej"
    GREEN = "Yeşil"
    YELLOW = "Sarı"
    ORANGE = "Turuncu"
    GOLD = "Altın"
    UNKNOWN = "Bilinmiyor"


class SellerType(str, Enum):
    """Satıcı tipi enum"""
    DEALER = "Galeriden"
    INDIVIDUAL = "Sahibinden"
    COMPANY = "Yetkili Bayi"
    UNKNOWN = "Bilinmiyor"


class WarrantyStatus(str, Enum):
    """Garanti durumu enum"""
    UNDER_WARRANTY = "Garantisi Var"
    NO_WARRANTY = "Garantisi Yok"
    EXTENDED_WARRANTY = "Garanti Uzatılmış"
    UNKNOWN = "Bilinmiyor"

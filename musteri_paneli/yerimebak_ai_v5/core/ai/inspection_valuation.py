# -*- coding: utf-8 -*-
"""
Ekspertiz Bazlı Değerleme Motoru (Yerimebak)
===========================================

Personelin sahada doldurduğu tam raporu (dış / iç / boya-kaporta / mekanik /
kurumsal) okuyup aracın *temiz piyasa değerinden* her bulgunun değer kaybını
parça parça düşer ve yapay zekânın nihai fiyatını belirler.

Akış:
    1. Piyasa referansı  → hasarsız (temiz) emsal ilanların medyanı, km/yıl düzeltmeli
    2. Bulgular          → her parça / madde için % değer kaybı (kalem kalem, TL karşılığıyla)
    3. Yaş / km etkisi   → kozmetik kayıplar yaşlı ve yüksek km'li araçta daha az etkili
    4. Nihai değer       → temiz değer × (1 − toplam kayıp), adil fiyat aralığı ve pazarlık fiyatı
    5. Fiyat yorumu      → ilan fiyatı varsa ekspertiz düzeltmeli değerle karşılaştırma

Katsayılar Türkiye ikinci el piyasasındaki güncel (2025-2026) gözlemlere göre
kalibre edilmiştir:
    * Araç Endeks ilan analizi: 1-2 boyalı ≈ -%3, 3-5 boyalı ≈ -%5,2, 6+ boyalı ≈ -%8,1,
      en az bir değişen parça (medyan) ≈ -%9,4.
    * Ekspertiz firmaları (RS Oto vb.): tavan işlemi -%15-25, kaput değişeni -%10-15,
      kemer altı boya -%3-7, şasi / podye işlemi -%20-35, ağır hasar -%30-45,
      tampon boyası ihmal edilebilir.
    * Tramer: hasar tutarı / araç değeri %0-5 → -%2-5, %5-15 → -%5-12, %15-40 → -%15-30.
    * SBM / sigorta değer kaybı formülü: araç yaşı ve km arttıkça kozmetik
      kayıpların etkisi azalır (yaş ve km katsayıları).

Bu modül saf Python'dur (veritabanına dokunmaz); birim testleri doğrudan çağırabilir.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple

MODEL_VERSION = "ekspertiz-degerleme-2026.10"

# Toplam değer kaybı tavanı (pert / ağır hasar seviyesi)
MAX_TOTAL_LOSS_PCT = 50.0
# İlan fiyatı → gerçekleşen satış (pazarlık payı)
NEGOTIATION_MARGIN_PCT = 3.0

# ---------------------------------------------------------------------------
# Kaporta parçaları: durum → % değer kaybı
# ---------------------------------------------------------------------------
PART_LABELS: Dict[str, str] = {
    "onTampon": "Ön Tampon",
    "kaput": "Motor Kaputu",
    "solOnCamurluk": "Sol Ön Çamurluk",
    "solOnKapi": "Sol Ön Kapı",
    "solArkaKapi": "Sol Arka Kapı",
    "solArkaCamurluk": "Sol Arka Çamurluk",
    "sagOnCamurluk": "Sağ Ön Çamurluk",
    "sagOnKapi": "Sağ Ön Kapı",
    "sagArkaKapi": "Sağ Arka Kapı",
    "sagArkaCamurluk": "Sağ Arka Çamurluk",
    "tavan": "Tavan",
    "bagajKapagi": "Bagaj Kapağı",
    "arkaTampon": "Arka Tampon",
}

# Parça sınıfları: tampon (plastik), kapı, ön çamurluk (cıvatalı), arka çamurluk
# (kaynaklı, gövdenin parçası), kaput, bagaj, tavan.
_PART_CLASS = {
    "onTampon": "tampon", "arkaTampon": "tampon",
    "kaput": "kaput",
    "solOnCamurluk": "on_camurluk", "sagOnCamurluk": "on_camurluk",
    "solArkaCamurluk": "arka_camurluk", "sagArkaCamurluk": "arka_camurluk",
    "solOnKapi": "kapi", "solArkaKapi": "kapi", "sagOnKapi": "kapi", "sagArkaKapi": "kapi",
    "bagajKapagi": "bagaj",
    "tavan": "tavan",
}

#                  lokal_boyali  boyali  degisen  sokulup_takilmis  hasarli
_PART_LOSS: Dict[str, Dict[str, float]] = {
    "tampon":        {"lokal_boyali": 0.15, "boyali": 0.4, "degisen": 0.6, "sokulup_takilmis": 0.1, "hasarli": 0.8},
    "kapi":          {"lokal_boyali": 0.6, "boyali": 1.5, "degisen": 5.0, "sokulup_takilmis": 0.4, "hasarli": 1.8},
    "on_camurluk":   {"lokal_boyali": 0.6, "boyali": 1.5, "degisen": 4.0, "sokulup_takilmis": 0.4, "hasarli": 1.8},
    "arka_camurluk": {"lokal_boyali": 0.7, "boyali": 1.8, "degisen": 8.0, "sokulup_takilmis": 0.6, "hasarli": 2.2},
    "kaput":         {"lokal_boyali": 0.8, "boyali": 2.5, "degisen": 8.0, "sokulup_takilmis": 0.5, "hasarli": 2.5},
    "bagaj":         {"lokal_boyali": 0.6, "boyali": 1.5, "degisen": 5.0, "sokulup_takilmis": 0.4, "hasarli": 1.8},
    "tavan":         {"lokal_boyali": 3.0, "boyali": 8.0, "degisen": 18.0, "sokulup_takilmis": 2.0, "hasarli": 5.0},
}

PART_STATUS_LABELS = {
    "orijinal": "Orijinal",
    "lokal_boyali": "Lokal Boyalı",
    "boyali": "Boyalı",
    "degisen": "Değişen",
    "sokulup_takilmis": "Sökülüp Takılmış",
    "hasarli": "Hasarlı",
}

# Aynı türden çok sayıda işlem: ilk parçalar tam, sonrakiler azalan etkiyle
# (Araç Endeks: 3-5 boyalı ≈ -%5,2, 6+ boyalı ≈ -%8,1).
_PAINT_DIMINISHING = (1.0, 1.0, 0.7, 0.7, 0.7, 0.5)
_REPLACED_DIMINISHING = (1.0, 0.85, 0.7)

# ---------------------------------------------------------------------------
# Yapısal elemanlar (şasi, direk, podye ...): işlemli / hasarlı
# ---------------------------------------------------------------------------
STRUCTURAL_LABELS = {
    "onSasi": "Ön Şasi",
    "arkaSasi": "Arka Şasi",
    "onDirekler": "Ön (A) Direkler",
    "ortaDirekler": "Orta (B) Direkler",
    "arkaDirekler": "Arka (C) Direkler",
    "podye": "Podyeler",
    "marsbiyel": "Marşpiyeller",
    "bagajHavuzu": "Bagaj Havuzu",
}
_STRUCTURAL_LOSS = {
    "onSasi": (15.0, 22.0),
    "arkaSasi": (12.0, 18.0),
    "onDirekler": (12.0, 18.0),
    "ortaDirekler": (12.0, 18.0),
    "arkaDirekler": (10.0, 15.0),
    "podye": (8.0, 12.0),
    "marsbiyel": (6.0, 9.0),
    "bagajHavuzu": (6.0, 9.0),
}
_STRUCTURAL_DIMINISHING = (1.0, 0.7, 0.5)

# ---------------------------------------------------------------------------
# Dış / iç kontrol listeleri (KontrolDurumu: mukemmel, iyi, orta, sorunlu, kotu, agirHasar, yok)
# ---------------------------------------------------------------------------
_CHECK_DEFAULT = {"orta": 0.1, "sorunlu": 0.3, "kotu": 0.7, "agirHasar": 2.0}
_CHECK_SPECIAL_DIS = {
    "onCam": {"orta": 0.1, "sorunlu": 0.4, "kotu": 0.8, "agirHasar": 1.2},
    "arkaCam": {"orta": 0.1, "sorunlu": 0.3, "kotu": 0.6, "agirHasar": 1.0},
    "onFarlar": {"orta": 0.1, "sorunlu": 0.4, "kotu": 0.8, "agirHasar": 1.2},
    "onSolLastik": {"orta": 0.05, "sorunlu": 0.2, "kotu": 0.4, "agirHasar": 0.6},
    "onSagLastik": {"orta": 0.05, "sorunlu": 0.2, "kotu": 0.4, "agirHasar": 0.6},
    "arkaSolLastik": {"orta": 0.05, "sorunlu": 0.2, "kotu": 0.4, "agirHasar": 0.6},
    "arkaSagLastik": {"orta": 0.05, "sorunlu": 0.2, "kotu": 0.4, "agirHasar": 0.6},
    "egzoz": {"orta": 0.1, "sorunlu": 0.4, "kotu": 0.8, "agirHasar": 1.5},
    # Görsel şasi kontrolü — boya/kaporta adımında yapısal eleman işaretlenmediyse kullanılır
    "onSasi": {"orta": 0.5, "sorunlu": 3.0, "kotu": 6.0, "agirHasar": 12.0},
    "arkaSasi": {"orta": 0.5, "sorunlu": 2.5, "kotu": 5.0, "agirHasar": 10.0},
}
_CHECK_SPECIAL_IC = {
    # Su baskını izi en ağır iç bulgudur
    "kokuNem": {"orta": 0.5, "sorunlu": 3.0, "kotu": 8.0, "agirHasar": 15.0},
    "uyariLambalari": {"orta": 0.3, "sorunlu": 1.5, "kotu": 3.0, "agirHasar": 5.0},
    "klima": {"orta": 0.1, "sorunlu": 0.6, "kotu": 1.2, "agirHasar": 2.0},
    "emniyetKemerleri": {"orta": 0.1, "sorunlu": 0.5, "kotu": 1.0, "agirHasar": 2.0},
    "direksiyon": {"orta": 0.1, "sorunlu": 0.5, "kotu": 1.0, "agirHasar": 2.0},
}
_DIS_CAP_PCT = 6.0
_IC_CAP_PCT = 6.0  # su baskını / uyarı lambaları bu tavana dahil değildir
_IC_UNCAPPED = {"kokuNem", "uyariLambalari"}

# Flutter kontrol_listesi.dart ile aynı etiketler (rapor kontrolListesi içermezse kullanılır)
DIS_LABELS = {
    "onTampon": "Ön Tampon",
    "onKaput": "Kaput",
    "onFarlar": "Ön Farlar",
    "sisFarlari": "Sis Farları",
    "onPanjur": "Ön Panjur / Izgara",
    "onCam": "Ön Cam",
    "silecekler": "Silecekler",
    "solOnCamurluk": "Sol Ön Çamurluk",
    "solOnKapi": "Sol Ön Kapı",
    "solArkaKapi": "Sol Arka Kapı",
    "solArkaCamurluk": "Sol Arka Çamurluk",
    "solAyna": "Sol Ayna",
    "sagOnCamurluk": "Sağ Ön Çamurluk",
    "sagOnKapi": "Sağ Ön Kapı",
    "sagArkaKapi": "Sağ Arka Kapı",
    "sagArkaCamurluk": "Sağ Arka Çamurluk",
    "sagAyna": "Sağ Ayna",
    "arkaTampon": "Arka Tampon",
    "bagajKapagi": "Bagaj Kapağı",
    "stopLambalari": "Stop Lambaları",
    "arkaCam": "Arka Cam",
    "tavan": "Tavan",
    "tavanTente": "Sunroof / Tavan Tente",
    "onSasi": "Ön Şasi (Görsel)",
    "arkaSasi": "Arka Şasi (Görsel)",
    "egzoz": "Egzoz Sistemi",
    "altKoruma": "Alt Koruma / Karter Muhafazası",
    "onSolLastik": "Sol Ön Lastik",
    "onSagLastik": "Sağ Ön Lastik",
    "arkaSolLastik": "Sol Arka Lastik",
    "arkaSagLastik": "Sağ Arka Lastik",
    "jantlar": "Jantlar",
    "stepne": "Stepne / Lastik Tamir Kiti",
    "kapiKollari": "Kapı Kolları ve Kilitler",
    "camFitilleri": "Kapı / Cam Fitilleri",
}
IC_LABELS = {
    "direksiyon": "Direksiyon (Boşluk/Kaplama)",
    "gostergePaneli": "Gösterge Paneli",
    "uyariLambalari": "Uyarı Lambaları (Motor/ABS/Airbag)",
    "korna": "Korna",
    "klima": "Klima / Isıtma",
    "sesSistemi": "Multimedya / Ses Sistemi",
    "torpido": "Torpido ve Orta Konsol",
    "onKoltuklar": "Ön Koltuklar",
    "arkaKoltuklar": "Arka Koltuklar",
    "koltukDosemesi": "Koltuk Döşemesi (Yırtık/Leke)",
    "koltukAyarlari": "Koltuk Ayar Mekanizmaları",
    "emniyetKemerleri": "Emniyet Kemerleri",
    "dorseme": "Taban Döşemesi / Paspas Altı",
    "tavanDosemesi": "Tavan Döşemesi",
    "kapiDosemeleri": "Kapı Döşemeleri",
    "bagajIci": "Bagaj İçi ve Havuzu",
    "onPencereler": "Ön Kapı Camları",
    "arkaPencereler": "Arka Kapı Camları",
    "camlar": "Cam Yüzeyleri (Çizik/Çatlak)",
    "merkeziKilit": "Merkezi Kilit",
    "camKontrolleri": "Elektrikli Cam Düğmeleri",
    "aynaKontrolleri": "Ayna Ayar / Katlama",
    "icAydinlatma": "İç Aydınlatma",
    "sunroofMekanizma": "Sunroof Mekanizması",
    "kokuNem": "Koku / Nem / Su Baskını İzi",
}

CHECK_STATUS_LABELS = {
    "mukemmel": "Mükemmel",
    "iyi": "İyi",
    "orta": "Orta",
    "sorunlu": "Sorunlu",
    "kotu": "Kötü",
    "agirHasar": "Ağır Hasar",
    "yok": "Yok / Uygulanamaz",
}

# Dış ekspertiz anahtarı → boya/kaporta parça anahtarı (çift sayımı önlemek için)
_DIS_TO_PART = {
    "onTampon": "onTampon", "onKaput": "kaput", "tavan": "tavan", "bagajKapagi": "bagajKapagi",
    "arkaTampon": "arkaTampon",
    "solOnCamurluk": "solOnCamurluk", "solOnKapi": "solOnKapi", "solArkaKapi": "solArkaKapi",
    "solArkaCamurluk": "solArkaCamurluk", "sagOnCamurluk": "sagOnCamurluk", "sagOnKapi": "sagOnKapi",
    "sagArkaKapi": "sagArkaKapi", "sagArkaCamurluk": "sagArkaCamurluk",
}

# ---------------------------------------------------------------------------
# Mekanik (adım 5: motor, şanzıman ...)
# ---------------------------------------------------------------------------
MECHANICAL_LABELS = {
    "motorDurumu": "Motor",
    "sanzimanDurumu": "Şanzıman",
    "frenSistemi": "Fren Sistemi",
    "direksiyonSistemi": "Direksiyon / Yürüyen",
    "elektrikSistemi": "Elektrik / OBD",
}
_MECHANICAL_LOSS = {
    "motorDurumu": {"orta": 1.0, "sorunlu": 5.0, "kotu": 12.0, "agirHasar": 18.0},
    "sanzimanDurumu": {"orta": 1.0, "sorunlu": 4.0, "kotu": 10.0, "agirHasar": 15.0},
    "frenSistemi": {"orta": 0.3, "sorunlu": 1.0, "kotu": 2.0, "agirHasar": 3.0},
    "direksiyonSistemi": {"orta": 0.5, "sorunlu": 1.5, "kotu": 3.0, "agirHasar": 4.0},
    "elektrikSistemi": {"orta": 0.3, "sorunlu": 1.5, "kotu": 3.0, "agirHasar": 4.0},
}
_MECHANICAL_SCORE_PENALTY = {
    "motorDurumu": {"orta": 8, "sorunlu": 25, "kotu": 45, "agirHasar": 60},
    "sanzimanDurumu": {"orta": 8, "sorunlu": 22, "kotu": 40, "agirHasar": 55},
    "frenSistemi": {"orta": 3, "sorunlu": 8, "kotu": 15, "agirHasar": 20},
    "direksiyonSistemi": {"orta": 4, "sorunlu": 10, "kotu": 18, "agirHasar": 25},
    "elektrikSistemi": {"orta": 3, "sorunlu": 8, "kotu": 15, "agirHasar": 20},
}

_HASAR_KAYDI_LOSS = {"kucuk": 0.3, "küçük": 0.3, "orta": 0.7, "buyuk": 1.5, "büyük": 1.5}
_HASAR_KAYDI_CAP = 4.0


# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------
def _num(value: Any) -> Optional[float]:
    if value is None or value == "":
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip().replace("TL", "").replace("₺", "").replace(" ", "")
    if not text:
        return None
    # "1.250.000" / "1.250.000,50" / "1250000.5"
    if "," in text:
        text = text.replace(".", "").replace(",", ".")
    elif text.count(".") > 1 or re.fullmatch(r"\d{1,3}(\.\d{3})+", text):
        text = text.replace(".", "")
    try:
        return float(text)
    except ValueError:
        return None


def _dict(value: Any) -> Dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _status_map(value: Any) -> Dict[str, str]:
    return {str(k): str(v) for k, v in _dict(value).items() if v not in (None, "")}


def _fold(text: Any) -> str:
    table = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    return str(text or "").translate(table).lower().strip()


def _norm_part_status(value: Any) -> str:
    raw = _fold(value).replace(" ", "_").replace("-", "_")
    if raw in ("", "orijinal", "original", "boyasiz", "temiz"):
        return "orijinal"
    if raw in ("lokal_boyali", "lokal", "lokal_boya"):
        return "lokal_boyali"
    if raw in ("boyali", "boyanmis", "boya"):
        return "boyali"
    if raw in ("degisen", "degismis", "degisti"):
        return "degisen"
    if raw in ("sokulup_takilmis", "soktak", "sok_tak"):
        return "sokulup_takilmis"
    if raw in ("hasarli", "hasar", "gocuk"):
        return "hasarli"
    return "orijinal"


def _norm_structural(value: Any) -> str:
    raw = _fold(value)
    if raw in ("islemli", "boyali", "kaynakli", "duzeltilmis", "degisen"):
        return "islemli"
    if raw in ("hasarli", "hasar"):
        return "hasarli"
    return "orijinal"


def _norm_check(value: Any) -> str:
    raw = _fold(value).replace(" ", "")
    return {
        "mukemmel": "mukemmel", "iyi": "iyi", "orta": "orta", "sorunlu": "sorunlu",
        "kotu": "kotu", "agirhasar": "agirHasar", "yok": "yok",
    }.get(raw, "")


def _diminish(values: List[float], factors: Tuple[float, ...]) -> List[float]:
    """Büyükten küçüğe sıralı kayıplara azalan katsayı uygular; orijinal sırayı korur."""
    order = sorted(range(len(values)), key=lambda i: values[i], reverse=True)
    result = [0.0] * len(values)
    for rank, idx in enumerate(order):
        factor = factors[rank] if rank < len(factors) else factors[-1]
        result[idx] = values[idx] * factor
    return result


def age_factor(age_years: Optional[int]) -> float:
    """Kozmetik kayıpların yaşa göre etkisi (SBM formülündeki yaş katsayısının yumuşatılmışı)."""
    if age_years is None:
        return 1.0
    if age_years <= 3:
        return 1.0
    if age_years <= 6:
        return 0.9
    if age_years <= 10:
        return 0.8
    return 0.65


def km_factor(km: Optional[float]) -> float:
    """Kozmetik kayıpların km'ye göre etkisi (SBM km katsayısının yumuşatılmışı)."""
    if not km or km <= 60_000:
        return 1.0
    if km <= 120_000:
        return 0.95
    if km <= 200_000:
        return 0.85
    return 0.75


def tramer_loss_pct(amount: float, base_value: float) -> float:
    """Tramer tutarının araç değerine oranına göre kademeli değer kaybı (ViaCars kademeleri)."""
    if amount <= 0 or base_value <= 0:
        return 0.0
    ratio = amount / base_value
    if ratio <= 0.05:
        pct = 1.0 + 80.0 * ratio            # %0-5  → %1-5
    elif ratio <= 0.15:
        pct = 5.0 + 70.0 * (ratio - 0.05)   # %5-15 → %5-12
    elif ratio <= 0.40:
        pct = 12.0 + 72.0 * (ratio - 0.15)  # %15-40 → %12-30
    else:
        pct = 30.0
    return round(min(pct, 30.0), 2)


def _fmt_int(value: float) -> str:
    return f"{value:,.0f}".replace(",", ".")


def _fmt_tl(value: float) -> str:
    return f"{_fmt_int(value)} TL"


def _fmt_pct(value: float, signed: bool = False) -> str:
    text = f"{value:+.1f}" if signed else f"{value:.1f}"
    return "%" + text.replace(".", ",")


# ---------------------------------------------------------------------------
# Veri yapıları
# ---------------------------------------------------------------------------
@dataclass
class LossItem:
    kategori: str          # kaporta | yapisal | dis | ic | mekanik | tramer | hasar_kaydi
    anahtar: str
    baslik: str
    durum: str
    yuzde: float           # nihai (azalan etki ve yaş/km sonrası) yüzde
    ham_yuzde: float       # katsayı tablosundaki yüzde
    aciklama: str = ""
    tutar: float = 0.0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "kategori": self.kategori,
            "anahtar": self.anahtar,
            "baslik": self.baslik,
            "durum": self.durum,
            "yuzde": round(self.yuzde, 2),
            "hamYuzde": round(self.ham_yuzde, 2),
            "tutar": round(self.tutar),
            "aciklama": self.aciklama,
        }


@dataclass
class InspectionFindings:
    """Personel raporundan çıkarılan, değerlemeye girdi olan bulgular."""
    parts: Dict[str, str] = field(default_factory=dict)
    microns: Dict[str, float] = field(default_factory=dict)
    structural: Dict[str, str] = field(default_factory=dict)
    dis: Dict[str, str] = field(default_factory=dict)
    ic: Dict[str, str] = field(default_factory=dict)
    mechanical: Dict[str, str] = field(default_factory=dict)
    damage_records: List[Dict[str, Any]] = field(default_factory=list)
    tramer_amount: float = 0.0
    tramer_count: int = 0
    corporate_score: Optional[float] = None
    corporate_summary: str = ""
    km: Optional[float] = None
    year: Optional[int] = None
    labels: Dict[str, str] = field(default_factory=dict)

    @property
    def has_bodywork_data(self) -> bool:
        return bool(self.parts or self.structural)

    @property
    def filled_sections(self) -> List[str]:
        out = []
        if self.dis:
            out.append("dis")
        if self.ic:
            out.append("ic")
        if self.parts or self.structural:
            out.append("boya_kaporta")
        if self.mechanical:
            out.append("mekanik")
        if self.corporate_score is not None or self.corporate_summary:
            out.append("kurumsal")
        return out


def _legacy_parts(adim4: Dict[str, Any], labels: Dict[str, str]) -> Dict[str, str]:
    """Eski raporlarda yalnızca boyaliParcalar / degisenParcalar etiket listesi vardır."""
    label_to_key = {_fold(v): k for k, v in PART_LABELS.items()}
    label_to_key.update({"kaput": "kaput", "on tampon": "onTampon", "arka tampon": "arkaTampon",
                         "bagaj": "bagajKapagi", "bagaj kapagi": "bagajKapagi", "tavan": "tavan"})
    parts: Dict[str, str] = {}
    unknown_idx = 0

    def put(label: Any, status: str):
        nonlocal unknown_idx
        key = label_to_key.get(_fold(label))
        if key is None:
            # Etiket tanınmazsa ortalama bir kapı/çamurluk gibi değerlendir
            # (sınıfı bilinmeyen parça kapı/çamurluk katsayısıyla değerlendirilir)
            unknown_idx += 1
            key = f"diger_{unknown_idx}"
            labels[key] = str(label)
        if parts.get(key) != "degisen":
            parts[key] = status

    for label in adim4.get("boyaliParcalar") or []:
        put(label, "boyali")
    for label in adim4.get("degisenParcalar") or []:
        put(label, "degisen")
    return parts


def extract_findings(tam_rapor: Optional[Dict[str, Any]], vehicle: Optional[Dict[str, Any]] = None) -> InspectionFindings:
    """tam_rapor (Flutter TamRaporModel.toJson) → InspectionFindings."""
    tam = _dict(tam_rapor)
    vehicle = vehicle or {}
    adim1 = _dict(tam.get("adim1"))
    adim2 = _dict(tam.get("adim2"))
    adim3 = _dict(tam.get("adim3"))
    adim4 = _dict(tam.get("adim4"))
    adim5 = _dict(tam.get("adim5"))

    f = InspectionFindings()

    # --- Boya / kaporta
    parts = {k: _norm_part_status(v) for k, v in _status_map(adim4.get("parcaDurumlari")).items()}
    if not parts:
        parts = _legacy_parts(adim4, f.labels)
    f.parts = parts
    for k, v in _dict(adim4.get("mikronlar")).items():
        n = _num(v)
        if n:
            f.microns[str(k)] = n
    structural = {k: _norm_structural(v) for k, v in _status_map(adim4.get("yapisalDurumlar")).items()}
    if not structural:
        for key in STRUCTURAL_LABELS:
            if adim4.get(key):
                structural[key] = _norm_structural(adim4.get(key))
    f.structural = structural
    f.damage_records = [r for r in (adim4.get("hasarKayitlari") or []) if isinstance(r, dict)]

    # --- Dış / iç kontrol listeleri
    for target, adim in ((f.dis, adim2), (f.ic, adim3)):
        statuses = _status_map(adim.get("maddeDurumlari"))
        if not statuses:
            for item in adim.get("kontrolListesi") or []:
                if isinstance(item, dict) and item.get("key") and item.get("durum"):
                    statuses[str(item["key"])] = str(item["durum"])
                    if item.get("label"):
                        f.labels[str(item["key"])] = str(item["label"])
        for item in adim.get("kontrolListesi") or []:
            if isinstance(item, dict) and item.get("key") and item.get("label"):
                f.labels.setdefault(str(item["key"]), str(item["label"]))
        for k, v in statuses.items():
            norm = _norm_check(v)
            if norm:
                target[k] = norm

    # --- Mekanik ve kurumsal
    for key in MECHANICAL_LABELS:
        norm = _norm_check(adim5.get(key))
        if norm and norm != "yok":
            f.mechanical[key] = norm
    f.corporate_score = _num(adim5.get("genelPuan"))
    f.corporate_summary = str(adim5.get("kurumsalSonucOzeti") or adim5.get("ozetNot") or "").strip()

    # --- Tramer, km, yıl
    f.tramer_amount = _num(adim1.get("hasarKayitToplamTutar")) or 0.0
    f.tramer_count = int(_num(adim1.get("hasarKayitAdet")) or 0)
    f.km = _num(adim1.get("guncelKm")) or _num(vehicle.get("km"))
    year = _num(adim1.get("yil")) or _num(vehicle.get("yil")) or _num(vehicle.get("year"))
    f.year = int(year) if year else None
    return f


# ---------------------------------------------------------------------------
# Değer kaybı hesabı
# ---------------------------------------------------------------------------
def compute_losses(f: InspectionFindings, base_value: float = 0.0, now: Optional[datetime] = None) -> Dict[str, Any]:
    """Bulgulardan kalem kalem değer kaybı (%) hesaplar."""
    now = now or datetime.now()
    age = max(0, now.year - f.year) if f.year else None
    cosmetic_factor = round(age_factor(age) * km_factor(f.km), 3)
    items: List[LossItem] = []

    # 1) Kaporta parçaları — boyalar ve değişenler ayrı ayrı azalan etkiyle
    paint_like = [(k, s) for k, s in f.parts.items() if s in ("lokal_boyali", "boyali", "sokulup_takilmis", "hasarli")]
    replaced = [(k, s) for k, s in f.parts.items() if s == "degisen"]
    for group, factors in ((paint_like, _PAINT_DIMINISHING), (replaced, _REPLACED_DIMINISHING)):
        raw = [_PART_LOSS[_PART_CLASS.get(k, "kapi")][s] for k, s in group]
        dim = _diminish(raw, factors)
        for (k, s), r, d in zip(group, raw, dim):
            micron = f.microns.get(k)
            notes = []
            if micron:
                notes.append(f"Boya kalınlığı {micron:.0f} µm")
            if s == "degisen" and _PART_CLASS.get(k) == "arka_camurluk":
                notes.append("Arka çamurluk kaynaklı parçadır, değişimi gövde işlemi sayılır")
            if s == "degisen" and k == "tavan":
                notes.append("Tavan değişimi takla / ağır hasar göstergesidir")
            if _PART_CLASS.get(k) == "tampon":
                notes.append("Plastik tampon işlemi değere etkisi düşüktür")
            note = " · ".join(notes)
            items.append(LossItem("kaporta", k, PART_LABELS.get(k) or f.labels.get(k, k), PART_STATUS_LABELS[s],
                                  d * cosmetic_factor, r, note))

    # 2) Yapısal elemanlar — yaş/km etkisi uygulanmaz (güvenlik ve satılabilirlik)
    structural = [(k, s) for k, s in f.structural.items() if s in ("islemli", "hasarli")]
    raw = [_STRUCTURAL_LOSS.get(k, (6.0, 9.0))[0 if s == "islemli" else 1] for k, s in structural]
    for (k, s), r, d in zip(structural, raw, _diminish(raw, _STRUCTURAL_DIMINISHING)):
        items.append(LossItem("yapisal", k, STRUCTURAL_LABELS.get(k, k), "İşlemli" if s == "islemli" else "Hasarlı",
                              d, r, "Yapısal (gövde) işlemi — ağır hasar sınıfı"))

    # 3) Ek hasar kayıtları (çizik, göçük, pas ...)
    rec_total = 0.0
    for idx, rec in enumerate(f.damage_records):
        size = _fold(rec.get("buyukluk"))
        pct = _HASAR_KAYDI_LOSS.get(size, 0.5)
        pct = min(pct, max(0.0, _HASAR_KAYDI_CAP - rec_total))
        rec_total += pct
        if pct <= 0:
            continue
        title = " ".join(str(x) for x in (rec.get("konum"), rec.get("tip")) if x) or f"Hasar kaydı {idx + 1}"
        items.append(LossItem("hasar_kaydi", f"hasar_{idx}", title, str(rec.get("buyukluk") or "-"),
                              pct * cosmetic_factor, pct, str(rec.get("not") or "")))

    # 4) Dış ekspertiz — boya/kaporta adımında zaten işlenen parçalar tekrar sayılmaz
    dis_total = 0.0
    for key, status in f.dis.items():
        if status in ("mukemmel", "iyi", "yok", ""):
            continue
        part_key = _DIS_TO_PART.get(key)
        if part_key and f.parts.get(part_key, "orijinal") != "orijinal":
            continue
        if key in ("onSasi", "arkaSasi") and f.structural.get(key) in ("islemli", "hasarli"):
            continue
        table = _CHECK_SPECIAL_DIS.get(key, _CHECK_DEFAULT)
        pct = table.get(status, 0.0)
        if key not in ("onSasi", "arkaSasi"):
            pct = min(pct, max(0.0, _DIS_CAP_PCT - dis_total))
            dis_total += pct
        if pct <= 0:
            continue
        factor = 1.0 if key in ("onSasi", "arkaSasi") else cosmetic_factor
        items.append(LossItem("dis", key, f.labels.get(key) or DIS_LABELS.get(key, key), CHECK_STATUS_LABELS.get(status, status),
                              pct * factor, pct, ""))

    # 5) İç ekspertiz
    ic_total = 0.0
    for key, status in f.ic.items():
        if status in ("mukemmel", "iyi", "yok", ""):
            continue
        table = _CHECK_SPECIAL_IC.get(key, {k: v * 0.8 for k, v in _CHECK_DEFAULT.items()})
        pct = table.get(status, 0.0)
        if key not in _IC_UNCAPPED:
            pct = min(pct, max(0.0, _IC_CAP_PCT - ic_total))
            ic_total += pct
        if pct <= 0:
            continue
        note = ""
        if key == "kokuNem" and status in ("kotu", "agirHasar"):
            note = "Su baskını şüphesi — ağır hasar sınıfı"
        items.append(LossItem("ic", key, f.labels.get(key) or IC_LABELS.get(key, key), CHECK_STATUS_LABELS.get(status, status),
                              pct, pct, note))

    # 6) Mekanik (motor, şanzıman ...) — onarım maliyeti niteliğinde, yaş/km etkisi yok
    for key, status in f.mechanical.items():
        pct = _MECHANICAL_LOSS[key].get(status, 0.0)
        if pct <= 0:
            continue
        items.append(LossItem("mekanik", key, MECHANICAL_LABELS[key], CHECK_STATUS_LABELS.get(status, status),
                              pct, pct, "Onarım maliyeti ve arıza riski"))

    # 7) Tramer (sigorta hasar kaydı). Aynı hasarın fiziksel izi kaporta kalemlerinde
    #    düşüldüyse kaydın yalnızca "tramerli araç" algısı kadarı eklenir.
    bodywork_pct = sum(i.yuzde for i in items if i.kategori in ("kaporta", "yapisal"))
    if f.tramer_amount > 0 and base_value > 0:
        tier = tramer_loss_pct(f.tramer_amount, base_value)
        pct = max(tier - 0.5 * bodywork_pct, tier * 0.35)
        ratio = f.tramer_amount / base_value * 100
        items.append(LossItem(
            "tramer", "tramer", "Tramer (hasar kaydı)", _fmt_tl(f.tramer_amount),
            pct * cosmetic_factor, tier,
            f"Hasar tutarı araç değerinin {_fmt_pct(ratio)}'i"
            + (" · fiziksel izi kaporta kalemlerinde düşüldü, yalnızca kayıt etkisi eklendi" if bodywork_pct > 0 and pct < tier else ""),
        ))
    elif f.tramer_amount > 0 or f.tramer_count > 0:
        pct = min(4.0, 1.5 * max(1, f.tramer_count))
        pct = max(pct - 0.5 * bodywork_pct, pct * 0.35)
        desc = _fmt_tl(f.tramer_amount) if f.tramer_amount else f"{f.tramer_count} kayıt"
        items.append(LossItem("tramer", "tramer", "Tramer (hasar kaydı)", desc, pct * cosmetic_factor, pct,
                              "Piyasa değeri bilinmediğinden kayıt sayısına göre tahmini etki"))

    total = sum(i.yuzde for i in items)
    capped = total > MAX_TOTAL_LOSS_PCT
    if capped:
        scale = MAX_TOTAL_LOSS_PCT / total
        for i in items:
            i.yuzde *= scale
        total = MAX_TOTAL_LOSS_PCT

    by_cat: Dict[str, float] = {}
    for i in items:
        by_cat[i.kategori] = by_cat.get(i.kategori, 0.0) + i.yuzde

    heavy = (
        any(i.kategori == "yapisal" for i in items)
        or f.parts.get("tavan") == "degisen"
        or f.ic.get("kokuNem") in ("kotu", "agirHasar")
        or any(s == "agirHasar" for s in f.dis.values())
        or f.mechanical.get("motorDurumu") == "kotu"
    )
    replaced_count = sum(1 for s in f.parts.values() if s == "degisen")
    painted_count = sum(1 for s in f.parts.values() if s in ("boyali", "lokal_boyali"))
    if heavy or total >= 15:
        level = "HEAVY"
    elif replaced_count or total >= 6:
        level = "MEDIUM"
    elif total >= 1.0 or painted_count:
        level = "LIGHT"
    else:
        level = "NONE"

    return {
        "items": items,
        "total_pct": round(total, 2),
        "by_category": {k: round(v, 2) for k, v in by_cat.items()},
        "capped": capped,
        "heavy_damage": heavy,
        "damage_level": level,
        "painted_count": painted_count,
        "replaced_count": replaced_count,
        "structural_count": sum(1 for s in f.structural.values() if s in ("islemli", "hasarli")),
        "age_years": age,
        "cosmetic_factor": cosmetic_factor,
    }


# ---------------------------------------------------------------------------
# Skorlar
# ---------------------------------------------------------------------------
def compute_scores(f: InspectionFindings, losses: Dict[str, Any]) -> Dict[str, Any]:
    cats = losses["by_category"]
    body_pct = cats.get("kaporta", 0) + cats.get("yapisal", 0) + cats.get("hasar_kaydi", 0) + cats.get("tramer", 0)
    hasar = max(0.0, min(100.0, 100.0 - body_pct * 3.5))

    mech_data = bool(f.mechanical)
    mech = 95.0
    for key, status in f.mechanical.items():
        mech -= _MECHANICAL_SCORE_PENALTY[key].get(status, 0)
    if f.ic.get("uyariLambalari") in ("sorunlu", "kotu", "agirHasar"):
        mech -= {"sorunlu": 10, "kotu": 20, "agirHasar": 30}[f.ic["uyariLambalari"]]
        mech_data = True
    if not mech_data and f.corporate_score is not None:
        mech = f.corporate_score
        mech_data = True
    if not mech_data:
        mech = 75.0  # nötr — mekanik veri girilmedi
    mech = max(0.0, min(100.0, mech))

    penalty = {"orta": 1.5, "sorunlu": 4.0, "kotu": 8.0, "agirHasar": 15.0}
    cond = 100.0
    for status in list(f.dis.values()) + list(f.ic.values()):
        cond -= penalty.get(status, 0.0)
    if f.ic.get("kokuNem") in ("kotu", "agirHasar"):
        cond -= 25
    cond = max(0.0, min(100.0, cond))

    genel = hasar * 0.35 + mech * 0.35 + cond * 0.30
    if f.corporate_score is not None:
        genel = genel * 0.8 + f.corporate_score * 0.2
    if losses["heavy_damage"]:
        genel = min(genel, 55.0)
    genel = max(0.0, min(100.0, genel))

    return {
        "aracDurumuPuan": round(cond, 1),
        "motorMekanikPuan": round(mech, 1),
        "hasarPuan": round(hasar, 1),
        "genelPuan": round(genel, 1),
        "mekanikVeriVar": mech_data,
    }


# ---------------------------------------------------------------------------
# Piyasa değeri
# ---------------------------------------------------------------------------
def _base_from_market(market: Dict[str, Any], f: InspectionFindings) -> Dict[str, Any]:
    """Piyasa referansından temiz araç (hasarsız) baz değerini ve km/yıl düzeltmesini çıkarır."""
    market = _dict(market)
    clean = _num(market.get("clean_median_price"))
    median = _num(market.get("market_median_price")) or _num(market.get("market_avg_price"))
    source = market.get("source")
    base = None
    method = ""
    if market.get("found") and source == "listings":
        if clean and int(market.get("clean_count") or 0) >= 3:
            base, method = clean, "Hasarsız (boyasız/değişensiz) emsal ilanların medyanı"
        elif median:
            base, method = median, "Emsal ilanların medyanı (hasarlı olduğu bilinen ilanlar hariç)"
    elif market.get("found") and source == "last_resort_listed_price":
        listed = _num(_dict(market.get("scope")).get("listed_price")) or median
        if listed:
            base, method = listed, "Emsal ilan bulunamadı — ilan fiyatı temiz araç fiyatı kabul edildi (düşük güven)"
    if not base:
        return {"found": False}

    adjustments = []
    ref_km = _num(market.get("reference_median_km"))
    ref_year = _num(market.get("reference_median_year"))
    if source == "listings" and f.km and ref_km and ref_km > 0:
        km_pct = max(-10.0, min(10.0, (ref_km - f.km) / 10_000 * 0.8))
        if abs(km_pct) >= 0.3:
            adjustments.append({"baslik": "Kilometre farkı", "yuzde": round(km_pct, 2),
                                "aciklama": f"Emsal medyan {_fmt_int(ref_km)} km, bu araç {_fmt_int(f.km)} km"})
    if source == "listings" and f.year and ref_year:
        yr_pct = max(-12.0, min(12.0, (f.year - ref_year) * 4.0))
        if abs(yr_pct) >= 0.3:
            adjustments.append({"baslik": "Model yılı farkı", "yuzde": round(yr_pct, 2),
                                "aciklama": f"Emsal medyan yıl {ref_year:.0f}, bu araç {f.year}"})
    adj_total = sum(a["yuzde"] for a in adjustments)
    adjusted = base * (1 + adj_total / 100.0)
    for a in adjustments:
        a["tutar"] = round(base * a["yuzde"] / 100.0)
    return {
        "found": True,
        "raw_base": round(base),
        "base": round(adjusted),
        "method": method,
        "adjustments": adjustments,
        "confidence": int(market.get("confidence") or 0),
        "stale": bool(market.get("stale")),
        "source": source,
        "count": int(market.get("count") or 0),
    }


def _round_price(value: float) -> int:
    if value >= 1_000_000:
        step = 5_000
    elif value >= 100_000:
        step = 1_000
    else:
        step = 500
    return int(round(value / step) * step)


def _price_verdict(listed: float, ai_value: float, heavy: bool) -> Dict[str, Any]:
    diff_pct = (listed - ai_value) / ai_value * 100.0
    if diff_pct <= -5:
        verdict, text = "AVANTAJLI", "İlan fiyatı ekspertiz sonucuna göre piyasanın altında"
    elif diff_pct <= 3:
        verdict, text = "MAKUL", "İlan fiyatı ekspertiz sonucuyla uyumlu"
    elif diff_pct <= 10:
        verdict, text = "PAZARLIK", "İlan fiyatı bulgulara göre biraz yüksek, pazarlık önerilir"
    else:
        verdict, text = "YUKSEK", "İlan fiyatı bulgulara göre yüksek"
    if heavy:
        text += " — ancak araçta ağır hasar bulgusu var"
    return {"karar": verdict, "aciklama": text, "farkYuzde": round(diff_pct, 1), "farkTutar": round(listed - ai_value)}


# ---------------------------------------------------------------------------
# Ana giriş
# ---------------------------------------------------------------------------
def evaluate(
    tam_rapor: Optional[Dict[str, Any]],
    market_reference: Optional[Dict[str, Any]],
    listed_price: Optional[float] = None,
    vehicle: Optional[Dict[str, Any]] = None,
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Ekspertiz bulgularını piyasa değerinden düşerek AI fiyatını belirler."""
    vehicle = vehicle or {}
    findings = extract_findings(tam_rapor, vehicle)
    base_info = _base_from_market(market_reference or {}, findings)
    base_value = float(base_info.get("base") or 0)
    losses = compute_losses(findings, base_value, now=now)
    scores = compute_scores(findings, losses)
    listed = _num(listed_price) or 0.0

    items: List[LossItem] = losses["items"]
    total_pct = losses["total_pct"]
    result: Dict[str, Any] = {
        "modelVersiyonu": MODEL_VERSION,
        "degerlemeYapildi": bool(base_info.get("found")),
        "toplamDegerKaybiYuzde": total_pct,
        "kategoriKayiplari": losses["by_category"],
        "hasarSeviyesi": losses["damage_level"],
        "agirHasar": losses["heavy_damage"],
        "boyaliParcaSayisi": losses["painted_count"],
        "degisenParcaSayisi": losses["replaced_count"],
        "yapisalIslemSayisi": losses["structural_count"],
        "aracYasi": losses["age_years"],
        "yasKmKatsayisi": losses["cosmetic_factor"],
        "kayipTavaniUygulandi": losses["capped"],
        "doldurulanBolumler": findings.filled_sections,
        "skorlar": scores,
        "ilanFiyati": round(listed) if listed > 0 else None,
    }

    if base_info.get("found"):
        loss_tl = base_value * total_pct / 100.0
        for i in items:
            i.tutar = base_value * i.yuzde / 100.0
        ai_value = base_value - loss_tl
        confidence = base_info["confidence"]
        if base_info["source"] != "listings":
            confidence = min(confidence, 25)
        if base_info["stale"]:
            confidence = min(confidence, 60)
        if len(findings.filled_sections) < 3:
            confidence = max(10, confidence - 15)
        spread = 0.04 if confidence >= 80 else 0.06 if confidence >= 60 else 0.09
        if losses["heavy_damage"]:
            spread += 0.03
        result.update({
            "piyasaDegeri": base_info["raw_base"],
            "temizPiyasaDegeri": round(base_value),
            "piyasaYontemi": base_info["method"],
            "piyasaDuzeltmeleri": base_info["adjustments"],
            "toplamDegerKaybiTutar": round(loss_tl),
            "aiDegeri": _round_price(ai_value),
            "adilFiyatAraligi": {
                "min": _round_price(ai_value * (1 - spread)),
                "max": _round_price(ai_value * (1 + spread)),
            },
            "onerilenAlimFiyati": _round_price(ai_value * (1 - NEGOTIATION_MARGIN_PCT / 100.0)),
            "guvenSkoru": int(confidence),
            "eskiPiyasaVerisi": base_info["stale"],
        })
        if listed > 0:
            result["fiyatYorumu"] = _price_verdict(listed, ai_value, losses["heavy_damage"])
    else:
        result.update({
            "piyasaDegeri": None,
            "temizPiyasaDegeri": None,
            "aiDegeri": None,
            "guvenSkoru": 0,
            "piyasaYontemi": "Piyasa referansı bulunamadı — yalnızca yüzde olarak değer kaybı hesaplandı",
        })

    result["kalemler"] = [i.to_dict() for i in sorted(items, key=lambda x: x.yuzde, reverse=True)]
    result["ozet"] = _summary(result, findings)
    return result


def _summary(r: Dict[str, Any], f: InspectionFindings) -> str:
    parts = []
    if r["degisenParcaSayisi"]:
        parts.append(f"{r['degisenParcaSayisi']} değişen")
    if r["boyaliParcaSayisi"]:
        parts.append(f"{r['boyaliParcaSayisi']} boyalı parça")
    if r["yapisalIslemSayisi"]:
        parts.append(f"{r['yapisalIslemSayisi']} yapısal işlem")
    if parts:
        text = f"Ekspertizde {', '.join(parts)} tespit edildi"
    else:
        text = "Ekspertizde kaporta işlemi tespit edilmedi"
    text += f"; bulguların toplam değer kaybı {_fmt_pct(r['toplamDegerKaybiYuzde'])}."
    if r.get("aiDegeri"):
        text += (f" Temiz piyasa değeri {_fmt_tl(r['temizPiyasaDegeri'])} üzerinden bulgular düşülerek "
                 f"aracın değeri {_fmt_tl(r['aiDegeri'])} olarak belirlendi"
                 f" (adil aralık {_fmt_tl(r['adilFiyatAraligi']['min'])} – {_fmt_tl(r['adilFiyatAraligi']['max'])}).")
        yorum = r.get("fiyatYorumu")
        if yorum:
            text += (f" İlan fiyatı {_fmt_tl(r['ilanFiyati'])} ({_fmt_pct(yorum['farkYuzde'], signed=True)}): "
                     f"{yorum['aciklama']}.")
    else:
        text += " Yeterli piyasa verisi olmadığından TL değeri hesaplanamadı."
    if r["agirHasar"]:
        text += " Araçta ağır hasar sınıfında bulgu bulunuyor."
    return text


def classify_listing_condition(*texts: Iterable[Any]) -> str:
    """İlan metinlerinden (boya bilgisi, hasar bilgisi, açıklama) kondisyon sınıfı: clean | damaged | heavy | unknown."""
    blob = _fold(" ".join(str(t) for t in texts if t))
    if not blob.strip():
        return "unknown"
    if re.search(r"agir hasar|pert|hurda|sel hasar|su baskin|takla", blob):
        return "heavy"
    negated_clean = re.search(r"boyasiz|degisensiz|hatasiz|is_original\W+true|orijinal|boyasiz/degisensiz", blob)
    damaged = re.search(r"degisen\b|degismis|(?<!lokal )boyali\b|has_changed\W+true|has_paint\W+true|hasarli|tramerli|degisen parca", blob)
    if negated_clean and not damaged:
        return "clean"
    if damaged:
        # "boyasız, değişensiz" gibi ifadelerde "değişen" kelimesi geçmez (degisensiz ayrı token)
        return "damaged"
    return "unknown"

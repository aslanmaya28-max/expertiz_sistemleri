# -*- coding: utf-8 -*-
"""
YERİMEBAK AI – Araç Analiz Servisi v1.0
Değer kaybı, fiyat önerisi, enflasyon getiri + Gemini + GLM-4.7 çift motor raporlama
"""

import os
import json
import sys
import asyncio
import dataclasses
from datetime import datetime
from typing import Dict, List, Any, Optional

from yerimebak_ai_v5.core.opportunity_engine import OpportunityEngine
from yerimebak_ai_v5.dashboard.services.live_data_service_v2 import get_live_service_v2
from yerimebak_ai_v5.core.risk_engine_v8 import get_risk_engine_v8, RiskEngineV8
from yerimebak_ai_v5.core.condition_analyzer import get_condition_analyzer, ConditionAnalyzer
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.dashboard.services.constants import MARKA_SEGMENTI, PARCA_HASAR_KATSAYI

# Enflasyon Parametreleri (Şubat 2026 tahminleri)
TUFE_YILLIK = 0.36
TUFE_6_AYLIK = 0.17
ARAC_DEGER_KAZANIM_YILLIK = 0.28

# ─── Km Katsayısı ─────────────────────────────────────────────────────────────
def km_katsayisi(km: int) -> float:
    """Km başına değer kaybı katsayısı (0.0 = en kötü, 1.0 = sıfır km)"""
    if km <= 0:
        return 1.0
    elif km <= 20_000:
        return 0.97
    elif km <= 50_000:
        return 0.93
    elif km <= 100_000:
        return 0.87
    elif km <= 150_000:
        return 0.72  # Reduced from 0.78
    elif km <= 200_000:
        return 0.55  # Reduced from 0.68
    else:
        return 0.35  # Reduced from 0.55 - Significant penalty for 200k+


def get_segment(brand: str) -> Dict:
    brand_lower = brand.lower().strip()
    for seg_name, seg_data in MARKA_SEGMENTI.items():
        if any(m in brand_lower for m in seg_data["markalar"]):
            return {"ad": seg_name, **seg_data}
    return {"ad": "ekonomi", **MARKA_SEGMENTI["ekonomi"]}


class AnalizServisi:
    """
    Araç analiz servisi. Hem hesaplama hem de AI rapor üretimi yapar.
    Gemini: Ana rapor motorudur.
    GLM-4.7: Denetim ve çapraz kontrol motorudur.
    """

    def __init__(self):
        self._gemini = None
        self._glm = None
        self._init_ai()
        self._gemini_enabled = (self._gemini is not None)
        self._glm_enabled = (self._glm is not None)
        self.data_service = get_live_service_v2()
        self.opp_engine = OpportunityEngine()
        
        # v8.0 Deterministic motors
        self.risk_engine_v8 = get_risk_engine_v8()
        self.condition_analyzer = get_condition_analyzer()
        
        # v8.1 Unified AI Service
        from yerimebak_ai_v5.core.unified_ai_service import get_unified_ai_service
        self.unified_ai = get_unified_ai_service()

    def _init_ai(self):
        """AI motorlarını başlat. Her ikisi de opsiyonel."""
        # .env dosyasını proje kökünden yükle (her çalışma dizininden güvenli)
        try:
            from dotenv import load_dotenv
            _env_path = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(
                    os.path.dirname(os.path.abspath(__file__))))),
                ".env"
            )
            load_dotenv(_env_path, override=False)
        except Exception:
            pass

        # Root path'e ekle
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        if root not in sys.path:
            sys.path.insert(0, root)

        # ─── 2026 Unified Tril-Engine Architecture ───
        try:
            self._or_key = os.getenv("OPENROUTER_API_KEY")
            
            # Engine Models
            self._p_model = os.getenv("PRIMARY_MODEL", "google/gemma-3-27b-it:free")
            self._s_model = os.getenv("SECONDARY_MODEL", "stepfun/step-3.5-flash:free")
            self._f_model = os.getenv("FALLBACK_MODEL", "qwen/qwen3-next-80b-a3b-instruct:free")
            
            # Failover Settings
            self._failover_enabled = os.getenv("ENABLE_AI_FAILOVER", "True").lower() == "true"
            self._max_retries = int(os.getenv("MAX_AI_RETRIES", "3"))
            
            import openai
            
            if self._or_key:
                self._client = openai.OpenAI(
                    api_key=self._or_key,
                    base_url="https://openrouter.ai/api/v1",
                )
                self._gemini_enabled = True
                self._gemini_is_openrouter = True
                print(f"✅ [AnalizServisi] Tril-Engine Ready: {self._p_model} -> {self._s_model} -> {self._f_model}")
            else:
                print("⚠️ [AnalizServisi] OPENROUTER_API_KEY bulunamadı")
        except Exception as e:
            print(f"⚠️ [AnalizServisi] Motor başlatma hatası: {e}")


    # ─────────────────────────────────────────────────────────────────────────
    #  PAZAR VERİSİ ÇEK
    # ─────────────────────────────────────────────────────────────────────────
    def search_market(self, brand: str, model: str, year: int, km: int = None) -> Dict[str, Any]:
        """SQLite veri gölünden piyasa verisi sorgula — FORENSIC ARCHITECTURE."""
        try:

            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()
            query = """
                SELECT brand, model, year, price, km, fuel, transmission, source, url, scraped_at
                FROM listings
                WHERE LOWER(brand) LIKE ? AND LOWER(model) LIKE ? AND year = ?
                ORDER BY scraped_at DESC
                LIMIT 50
            """
            cursor.execute(query, (f"%{brand.lower()}%", f"%{model.lower()}%", year))
            rows = cursor.fetchall()
            cols = ["brand", "model", "year", "price", "km", "fuel", "transmission", "source", "url", "scraped_at"]
            listings = [dict(zip(cols, r)) for r in rows if r[3] and r[3] > 0]
            conn.close()

            if listings:
                prices = [l["price"] for l in listings]
                stats = {
                    "total": len(listings),
                    "avg": round(sum(prices) / len(prices)),
                    "min": min(prices),
                    "max": max(prices),
                    "median": sorted(prices)[len(prices) // 2],
                }
            else:
                stats = {}

            return {"listings": listings, "stats": stats, "source": "live_db"}

        except Exception as e:
            print(f"⚠️ Piyasa sorgusu hatası: {e}")
            return {"listings": [], "stats": {}, "source": "error"}

    # ─────────────────────────────────────────────────────────────────────────
    #  DEĞER KAYBI HESAPLA
    # ─────────────────────────────────────────────────────────────────────────
    def hesapla_deger_kaybi(
        self,
        brand: str,
        model: str,
        year: int,
        km: int,
        degisen_parcalar: List[str],
        boyali_parcalar: List[str],
        tramer_bedeli: int = 0,
        paket: str = "",
        piyasa_ortalamasi: int = 0,
    ) -> Dict[str, Any]:
        """
        Tüm faktörleri hesaba katarak değer kaybı oranı ve ağırlıklı fiyat üretir.
        """
        current_year = 2026
        
        # 0. Year Sanity Check (Hallucination Guard)
        if int(year) > current_year:
            # If scraper somehow extracted 2026 for a 2017 model, or AI hallucinated
            # We log it and use a fallback or the scraper's raw year if exists
            print(f"⚠️  [Hallucination Guard] Future year detected: {year}. Correcting to current or suspected year.")
            year = current_year # Cap at current year unless we have evidence
            
        yas = max(0, current_year - int(year))
        segment = get_segment(brand)

        # 1. Yaş kaybı
        yas_kaybi_oran = 1 - ((1 - segment["yillik_kayip"]) ** yas)

        # 2. Km kaybı
        km_k = km_katsayisi(km)

        # 3. Hasar kaybı
        hasar_kayip_oran = 0.0
        for parca in degisen_parcalar:
            hasar_kayip_oran += PARCA_HASAR_KATSAYI.get(parca.lower(), PARCA_HASAR_KATSAYI["diğer"])
        for parca in boyali_parcalar:
            hasar_kayip_oran += PARCA_HASAR_KATSAYI.get(parca.lower(), PARCA_HASAR_KATSAYI["diğer"]) * 0.6

        # 4. Tramer
        tramer_kayip_oran = (tramer_bedeli / 1_000_000) * 0.15 if tramer_bedeli > 0 else 0.0

        # 5. Toplam DKK — UI göstergesi için tam bileşik oran
        dkk = min(0.75, yas_kaybi_oran + (1 - km_k) * 0.4 + hasar_kayip_oran + tramer_kayip_oran)

        # 6. Kondisyon indirimi katsayısı (yaş hariç: km + hasar + tramer)
        kondisyon_kayip = min(0.40, (1 - km_k) * 0.4 + hasar_kayip_oran + tramer_kayip_oran)

        # 7. Piyasa Verisi Otomatik Sorgu (Tier Fallback)
        veri_kaynagi = "Hesaplama"
        if piyasa_ortalamasi == 0:
            db_res = self.search_market(brand, model, year, km)
            db_stats = db_res.get('stats', {})
            db_count = db_stats.get('total', 0)
            db_avg = db_stats.get('avg', 0)

            if db_count >= 3:
                # Tier 1: Yeterli veri var
                piyasa_ortalamasi = db_avg
                veri_kaynagi = f"📊 Piyasa (DB: {db_count} ilan)"
            elif db_count > 0:
                # Tier 2: Az veri var
                piyasa_ortalamasi = db_avg
                veri_kaynagi = f"⚠️ Piyasa (DB: {db_count} ilan - kısıtlı)"
            else:
                # Tier 3: Veri yok → Formül + Kuyruğa ekle - IMPROVED v2.1
                piyasa_ortalamasi = 0
                veri_kaynagi = "⏳ Tahmin (İlan bulunamadı)"
                # Otomatik scrape tetikle - arka planda çalıştır
                try:
                    self._queue_priority_scrape(brand, model, year)
                    print(f"      🔄 Otomatik scrape tetiklendi: {brand} {model} {year}")
                except Exception as e:
                    print(f"      ⚠️ Scrape tetikleme hatası: {e}")

        if piyasa_ortalamasi > 0:
            # Piyasa verisi varsa (Tier 1/2): kondisyon indirimini uygula
            baz = piyasa_ortalamasi
            hesaplanan_fiyat = int(piyasa_ortalamasi * (1 - kondisyon_kayip))
        else:
            # Piyasa verisi yok (Tier 3) → yaşa göre ayarlanmış piyasa tahmini
            # Şubat 2026: orta segment sıfır km ~2.4M ₺
            BAZ_SIFIR_KM = 2_400_000
            baz = BAZ_SIFIR_KM * segment["baz_fiyat_carpan"] * ((1 - segment["yillik_kayip"]) ** yas)
            # Yaş baz'da VAR — sadece kondisyon indirimi
            hesaplanan_fiyat = int(baz * (1 - kondisyon_kayip))

        return {
            "segment": segment["ad"],
            "yas": yas,
            "dkk": round(dkk, 4),
            "yas_kaybi_oran": round(yas_kaybi_oran, 4),
            "km_katsayisi": round(km_k, 4),
            "hasar_kayip_oran": round(hasar_kayip_oran, 4),
            "tramer_kayip_oran": round(tramer_kayip_oran, 4),
            "baz_fiyat": int(baz),
            "hesaplanan_fiyat": hesaplanan_fiyat,
            "veri_kaynagi": veri_kaynagi
        }

    # ─────────────────────────────────────────────────────────────────────────
    #  FİYAT ÖNERİLERİ ve GETİRİ ANALİZİ
    # ─────────────────────────────────────────────────────────────────────────
    def hesapla_fiyat_onerileri(self, piyasa_ortalamasi: int, hesaplanan_fiyat: int) -> Dict[str, Any]:
        """Alış tavsiyeleri ve senaryo analizi üretir."""
        ref = piyasa_ortalamasi if piyasa_ortalamasi > 0 else hesaplanan_fiyat

        tavsiye_alis = int(ref * 0.93)       # %7 altı — güvenli alış
        makul_alis = int(ref * 0.88)         # %12 altı — yatırım
        firsat_alis = int(ref * 0.82)        # %18 altı — fırsat alışı

        def kar_senaryosu(alis: int) -> Dict:
            satis_6ay = int(alis * (1 + ARAC_DEGER_KAZANIM_YILLIK / 2))
            satis_1yil = int(alis * (1 + ARAC_DEGER_KAZANIM_YILLIK))
            enflasyon_kaybi_6ay = int(alis * TUFE_6_AYLIK)
            enflasyon_kaybi_1yil = int(alis * TUFE_YILLIK)

            kar_6ay = satis_6ay - alis
            kar_1yil = satis_1yil - alis
            reel_kar_6ay = kar_6ay - enflasyon_kaybi_6ay
            reel_kar_1yil = kar_1yil - enflasyon_kaybi_1yil

            return {
                "alis": alis,
                "satis_6ay_tahmini": satis_6ay,
                "kar_6ay_nominal": kar_6ay,
                "reel_kar_6ay": reel_kar_6ay,
                "getiri_6ay_pct": round((kar_6ay / alis) * 100, 1),
                "reel_getiri_6ay_pct": round((reel_kar_6ay / alis) * 100, 1),
                "satis_1yil_tahmini": satis_1yil,
                "kar_1yil_nominal": kar_1yil,
                "reel_kar_1yil": reel_kar_1yil,
                "getiri_1yil_pct": round((kar_1yil / alis) * 100, 1),
                "reel_getiri_1yil_pct": round((reel_kar_1yil / alis) * 100, 1),
            }

        return {
            "piyasa_ortalamasi": ref,
            "hesaplanan_deger": hesaplanan_fiyat,
            "tavsiye_alis": tavsiye_alis,
            "makul_alis": makul_alis,
            "firsat_alis": firsat_alis,
            "enflasyon_6ay_pct": round(TUFE_6_AYLIK * 100, 1),
            "enflasyon_1yil_pct": round(TUFE_YILLIK * 100, 1),
            "arac_deger_artis_1yil_pct": round(ARAC_DEGER_KAZANIM_YILLIK * 100, 1),
            "senaryo_tavsiye": kar_senaryosu(tavsiye_alis),
            "senaryo_makul": kar_senaryosu(makul_alis),
            "senaryo_firsat": kar_senaryosu(firsat_alis),
        }

    # ─────────────────────────────────────────────────────────────────────────
    #  AI RAPOR
    # ─────────────────────────────────────────────────────────────────────────
    def _build_prompt(
        self,
        arac: Dict,
        deger_analizi: Dict,
        fiyat_analizi: Dict,
        piyasa: Dict,
        listing_count: int = 0
    ) -> str:
        # Pazar trendleri ve benzer ilanlar
        listings_str = ""
        if piyasa.get("listings"):
            for l in piyasa["listings"][:5]:
                listings_str += f"  - {l['brand']} {l['model']} {l['year']} | {l['price']:,} ₺ | {l.get('km', 0):,} km\n"

        # Hasar ve Boya durumunu adlandır
        ops_costs = 4000 #expertise + listing
        bodywork = f"Değişen: {', '.join(arac.get('degisen', []))}, Boya: {', '.join(arac.get('boyali', []))}"
        tramer = arac.get('tramer', 0)
        damage_lvl = "Yok"
        if tramer > 100000: damage_lvl = "Ağır"
        elif tramer > 40000: damage_lvl = "Orta"
        elif tramer > 0: damage_lvl = "Hafif"

        return f"""# YERİMEBAK AI v7.2 — SAHİPSİZ ULTRA MASTER PROMPT

Sen, 20 yıllık tecrübeye sahip, profesyonel galerici, ekspertiz ustası ve portföy yöneticisisin.
Amacın: Bir aracın GERÇEK ticari değerini hesaplamak. ASLA iyimser olma, daima konservatif kal.

---

# CORE ANALYSIS MODULES

1 — MARKET INTELLIGENCE: market_price_min, market_price_avg, market_price_max. listing_count. 
   price_position_index = ((market_price_avg − listed_price) / market_price_avg) × 100

2 — EXIT PRICE ENGINE: estimated_exit_price: market_price_avg × (0.97 — 1.02). ASLA market_price_max geçemez.

3 — KM & DAMAGE VALUE LOSS: Hasar Etkisi: NONE:%0, LIGHT:%2, MEDIUM:%5, HEAVY:%10+. KM arttıkça konservatif düşüş.

4 — LIQUIDITY & SEASONALITY: liquidity_score (0-100), estimated_days_to_sell. 
   seasonality_multiplier (0.90 — 1.15). final_days_to_sell = estimated_days_to_sell × seasonality_multiplier.

5 — EXPENSE ENGINE: 
   expertise_cost = 2000, prep_cost = listed_price × 0.01, listing_cost = 2000.
   finance_cost = listed_price × 0.0015 × final_days_to_sell.
   estimated_total_cost = listed_price + ops_costs + finance_cost.

6 — NET PROFIT ENGINE: net_profit = estimated_exit_price − estimated_total_cost.
   net_margin_percent = (net_profit / estimated_total_cost) × 100. (MAX %25)

7 — RISK & OPPORTUNITY: Risk (KM, Hasar, Liquidity, Saturation). opportunity_score (0-100).

8 — CONFIDENCE ENGINE: confidence_score (Veri kalitesi, listing_count, model reliability).

9 — DEALER DECISION: STRONG_BUY, BUY, NEGOTIATE, HOLD, AVOID.

---

# HALLUCINATION GUARDS (ZORUNLU)
- KURAL 1: KM > 200000 AND liquidity_score < 50 THEN opportunity_score MAX 65.
- KURAL 2: net_margin_percent MAX 25.
- KURAL 3: estimated_exit_price > market_price_max ASLA OLAMAZ.
- KURAL 4: Negatif kar varsa decision: AVOID.

---

# INPUT DATA
make_model: "{arac.get('brand', '')} {arac.get('model', '')} {arac.get('paket', '')}"
year: {arac.get('year', 2020)}
mileage_km: {arac.get('km', 0)}
listed_price: {fiyat_analizi.get('piyasa_ortalamasi', 0)}
market_price_avg: {fiyat_analizi.get('piyasa_ortalamasi', 0)}
bodywork_status: "{bodywork}"
damage_level: "{damage_lvl}"
listing_count: {listing_count}

---

# OUTPUT: STRICT JSON

{{
  "analysis_meta": {{ "version": "7.2-sahipsiz", "confidence_score": 0-100 }},
  "market_valuation": {{
    "market_price_min": 0, "market_price_avg": 0, "market_price_max": 0,
    "price_position_index": 0, "competitor_count": 0
  }},
  "exit_strategy": {{ "estimated_exit_price": 0, "negotiation_buffer_percent": 0 }},
  "commercial_analysis": {{
    "estimated_total_cost": 0, "net_profit_tl": 0, "net_margin_percent": 0,
    "finance_cost": 0, "optimal_purchase_price": 0
  }},
  "liquidity_metrics": {{
    "liquidity_score": 0, "estimated_days_to_sell": 0, "final_days_to_sell": 0
  }},
  "technical_scoring": {{ "opportunity_score": 0, "risk_percentage": 0 }},
  "dealer_verdict": {{ "decision": "AVOID|HOLD|NEGOTIATE|BUY|STRONG_BUY", "action_note": "" }},
  "technical_summary": "Uzman galerici teknik özeti (Türkçe)"
}}"""


    def _generate_with_failover(self, prompt: str, system_msg: str, initial_model: str = None) -> Optional[str]:
        """Redirects to UnifiedAIService (Sync Wrapper)"""
        if not self.unified_ai.enabled:
            return None
        
        # Use asyncio.run for sync dashboard compatibility
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # If already in a loop, we might need a different approach, but for Streamlit it's usually fine
                import nest_asyncio
                nest_asyncio.apply()
            
            return asyncio.run(self.unified_ai._call_ai_with_failover(prompt, system_msg))
        except Exception as e:
            print(f"⚠️ [UnifiedRedirect] Failover error: {e}")
            return None

    def gemini_rapor(self, prompt: str) -> Dict[str, Any]:
        """Gemma/Primary motor ile JSON rapor üretir ve parse eder (Ultra Robust v3)."""
        sys_msg = "You are a professional car dealer expert system. You only speak JSON. Never output conversational text. Ensure valid JSON format."
        res = self._generate_with_failover(prompt, sys_msg)
        
        if not res:
            return {"error": "AI_ACCESS_ERROR", "detail": "AI motorlarından yanıt alınamadı."}

        # JSON Cleaning Strategy
        clean_json = res.strip()
        
        # 1. Regex ile ilk { ve son } arasını yakala (en garanti yöntem)
        import re
        try:
            json_match = re.search(r'(\{.*\})', clean_json, re.DOTALL)
            if json_match:
                clean_json = json_match.group(1)
            else:
                # Markdown block temizliği (fallback)
                if "```json" in clean_json:
                    clean_json = clean_json.split("```json")[1].split("```")[0].strip()
                elif "```" in clean_json:
                    clean_json = clean_json.split("```")[1].split("```")[0].strip()
        except: pass

        # 2. JSON içindeki tehlikeli karakterleri temizle (AI bazen bozuk JSON üretir)
        # (Örneğin yorum satırları veya tek tırnaklar)
        # Ama şimdilik standart parser'a güvenelim, bozulursa geliştiririz.

        try:
            ai_data = json.loads(clean_json)
            if not isinstance(ai_data, dict):
                raise ValueError("Bozuk veri yapısı (Array/String beklenen Object değil)")
            return ai_data
        except Exception as e:
            msg = f"⚠️ AI Yanıt Ayrıştırma Hatası: {e}"
            print(msg)
            # Kritik: Hatalı JSON'ı kurtarmaya çalış (en yaygın hata: trailing commas veya control chars)
            try:
                # Basit bir temizlik daha
                clean_json = re.sub(r',\s*\}', '}', clean_json) # Trailing commas in objects
                clean_json = re.sub(r',\s*\]', ']', clean_json) # Trailing commas in arrays
                ai_data = json.loads(clean_json)
                return ai_data
            except:
                return {
                    "error": "JSON_PARSE_ERROR", 
                    "detail": str(e),
                    "raw_response": res
                }

    def _sanitize_ai_json(self, ai_data: Dict[str, Any], opp_res: Dict[str, Any]) -> Dict[str, Any]:
        """AI hallüsinasyonlarını durdur ve gerçekçi sınırlar getir (v7.1 Ultra Guard)."""
        if not ai_data or "error" in ai_data:
            return ai_data
            
        # Extract fields for easier access (v7.1 uses nested structure)
        comm = ai_data.get('commercial_analysis', {})
        tech = ai_data.get('technical_scoring', {})
        verdict = ai_data.get('dealer_verdict', {})
        
        # 1. Risk Senkronizasyonu
        sys_risk = opp_res.get('risk_score', 0)
        ai_risk = tech.get('risk_percentage', 0)
        tech['risk_percentage'] = float(max(ai_risk, sys_risk))
        
        # 2. Marj Sabitleme (%25 cap)
        ai_margin = comm.get('net_margin_percent', 0)
        if ai_margin > 25:
            comm['net_margin_percent'] = 25.0
            # Karı da orantılı güncelle (Opsiyonel: total cost üzerinden hesaplanabilir)
            total_cost = comm.get('estimated_total_cost', 0)
            if total_cost > 0:
                comm['net_profit_tl'] = round(total_cost * 0.25, 0)
        
        # 3. Fırsat Skoru Senkronizasyonu
        sys_opp = opp_res.get('opportunity_score', 0)
        ai_opp = tech.get('opportunity_score', 0)
        
        # v7.2 Strict Risk Caps
        if tech['risk_percentage'] > 35: ai_opp = min(ai_opp, 70)
        if tech['risk_percentage'] > 55: ai_opp = min(ai_opp, 45)
        if tech['risk_percentage'] > 75: ai_opp = min(ai_opp, 15)

        tech['opportunity_score'] = round((ai_opp * 0.2) + (sys_opp * 0.8), 1) # v7.2: System dominance increased
        
        # 4. Confidence Sync (v7.2)
        sys_conf = opp_res.get('confidence_score', 50)
        ai_conf = ai_data.get('analysis_meta', {}).get('confidence_score', 50)
        ai_data.get('analysis_meta', {})['confidence_score'] = round((ai_conf * 0.3) + (sys_conf * 0.7), 1)
        
        # 4. Yıl Hallüsinasyonu
        current_year = 2026
        # make sure to check all possible year locations if AI deviates
        if ai_data.get('year', 0) > current_year:
             ai_data['year'] = current_year
             
        # 5. Rule-based override (v7.1 Guards)
        if comm.get('net_profit_tl', 0) < 0:
            verdict['decision'] = "AVOID"
            
        if tech.get('damage_level') == "HEAVY" and verdict.get('decision') not in ["AVOID", "NEGOTIATE"]:
            verdict['decision'] = "NEGOTIATE"

        return ai_data

    def glm_rapor(self, prompt: str) -> str:
        """StepFun ile denetim raporu üret (Metin formatında kalabilir)."""
        sys_msg = (
            "Sen uzman bir araç değerleme denetçisisin. "
            "JSON verisini inceleyip riskleri kısa Türkçe notlar halinde belirtirsin."
        )
        return self._generate_with_failover(prompt, sys_msg, initial_model=self._s_model)

    # ─────────────────────────────────────────────────────────────────────────
    #  ANA ANALİZ FONKSİYONU
    # ─────────────────────────────────────────────────────────────────────────
    def tam_analiz(self, 
                   brand: str, 
                   model: str, 
                   year: int, 
                   km: int, 
                   paket: str = "",
                   yakit: str = "",
                   sanziman: str = "",
                   renk: str = "",
                   degisen_parcalar: list = None,
                   boyali_parcalar: list = None,
                   tramer_bedeli: int = 0,
                   listing_count: int = None) -> Dict[str, Any]:
        """
        v7.2 — SAHİPSİZ ULTRA: Komple araç analizi, fiyatlama ve AI raporlama
        """
        degisen_parcalar = degisen_parcalar or []
        boyali_parcalar = boyali_parcalar or []

        if listing_count is None:
            # Re-fetch or use existing listing_count logic if needed
            # For now, let's look at the result of get_piyasa_verisi
            pass

        # The original code calls self.search_market, which returns market data.
        # We will use this to get listing_count if not provided.
        # 1. Piyasa verisi çek
        piyasa = self.search_market(brand, model, year)
        
        if listing_count is None:
            listing_count = piyasa.get('stats', {}).get('total', 0)
        
        # Ensure listing_count is at least the length of listings if stats are missing
        if listing_count == 0 and piyasa.get('listings'):
            listing_count = len(piyasa['listings'])

        piyasa_ortalamasi = piyasa["stats"].get("avg", 0)

        # 2. Değer kaybı hesapla
        deger_analizi = self.hesapla_deger_kaybi(
            brand=brand, model=model, year=year, km=km,
            degisen_parcalar=degisen_parcalar,
            boyali_parcalar=boyali_parcalar,
            tramer_bedeli=tramer_bedeli,
            paket=paket,
            piyasa_ortalamasi=piyasa_ortalamasi,
        )

        # 3. Fiyat önerileri
        fiyat_analizi = self.hesapla_fiyat_onerileri(
            piyasa_ortalamasi=piyasa_ortalamasi,
            hesaplanan_fiyat=deger_analizi["hesaplanan_fiyat"],
        )

        # 4. Prompt hazırla
        arac = {
            "brand": brand, "model": model, "year": year, "km": km,
            "paket": paket, "yakit": yakit, "sanziman": sanziman, "renk": renk,
            "degisen": degisen_parcalar, "boyali": boyali_parcalar, "tramer": tramer_bedeli,
        }
        prompt = self._build_prompt(arac, deger_analizi, fiyat_analizi, piyasa, listing_count)

        # JSON Çıktı Al
        ai_json_raw = self.gemini_rapor(prompt)
        
        # 5. Rafine Fırsat Skoru (OpportunityEngine use)
        from yerimebak_ai_v5.core.opportunity_engine import OpportunityEngine
        # Calculate base risk for Opportunity Engine (v7.2)
        base_risk = 0
        if tramer_bedeli > 100000: base_risk = 80
        elif tramer_bedeli > 40000: base_risk = 50
        elif tramer_bedeli > 0: base_risk = 20
        
        damage_lvl = "Yok"
        if tramer_bedeli > 100000: damage_lvl = "Ağır"
        elif tramer_bedeli > 40000: damage_lvl = "Orta"
        elif tramer_bedeli > 0: damage_lvl = "Hafif"

        # 5. Opportunity & Decision Engine (v7.2)
        opp_res = self.opp_engine.calculate_opportunity(
            price=fiyat_analizi.get('piyasa_ortalamasi', 0), # Simplified for base analysis
            market_avg=fiyat_analizi.get('piyasa_ortalamasi', 0),
            condition_score=85, # Base condition
            risk_score=base_risk,
            km=km,
            year=year,
            damage_level=damage_lvl,
            listing_count=listing_count
        )

        # 5.5. v8.0 Deterministic Risk Engine (Matematiksel Hesaplama)
        # Boya verisini formatla
        paint_data_list = []
        if boyali_parcalar:
            for parca in boyali_parcalar:
                paint_data_list.append({
                    "location": parca,
                    "condition": "PAINTED"
                })
        
        # Değişen parçaları formatla
        changed_parts_list = degisen_parcalar or []
        
        # Paket seviyesini belirle
        package_level_map = {
            "": "BASE",
            "Temel": "BASE",
            "Orta": "MID",
            "İyi": "HIGH",
            "Full": "FULL",
            "FULL": "FULL"
        }
        package_level = package_level_map.get(paket, "BASE")
        
        # Risk Engine V8 hesapla
        risk_data = {
            "price": float(fiyat_analizi.get('piyasa_ortalamasi', 0)),
            "vehicle_km": int(km) if km else 0,
            "market_average_km": int(year * 20000) if year else 150000,  # Yıllık 20.000 KM
            "painted_parts": len(paint_data_list),
            "local_paint_parts": 0,  # Şimdilik 0
            "changed_parts": changed_parts_list,
            "damage_amount": float(tramer_bedeli) if tramer_bedeli else 0,
            "package_level": package_level
        }
        
        risk_result_v8 = self.risk_engine_v8.calculate(risk_data)
        
        # KM ve Boya analizlerini hesapla
        km_analysis = None
        paint_analysis = None
        if km > 0:
            km_analysis = self.condition_analyzer.analyze_km(
                current_km=int(km),
                vehicle_year=year,
                segment="medium"
            )
        if paint_data_list:
            paint_analysis = self.condition_analyzer.analyze_paint(
                paint_data=paint_data_list,
                vehicle_year=year
            )

        # 6. AI Guard - Gerçeklik Kontrolü (Hallucination Filter)
        if not ai_json_raw or "error" in ai_json_raw:
            # AI failed (Quota, Parse Error, etc.) -> Use V8 Deterministic Fallback
            print(f"⚠️ [AnalizServisi] AI Error detected. Using System Logic Fallback (v8).")
            
            # Recalculate robust commercial numbers based on v8 exit price
            est_exit = risk_result_v8.get('exit_price', fiyat_analizi.get('piyasa_ortalamasi', 0))
            listed = fiyat_analizi.get('piyasa_ortalamasi', 0)
            cost = listed + 4000 + (listed * 0.0015 * risk_result_v8.get('estimated_days_to_sell', 15))
            net_profit = est_exit - cost
            net_margin = (net_profit / cost * 100) if cost > 0 else 0
            
            ai_json = {
                "analysis_meta": {"version": "8.0-deterministic-fallback", "confidence_score": 80},
                "market_valuation": {
                    "market_price_min": fiyat_analizi.get('firsat_alis', 0),
                    "market_price_avg": listed,
                    "market_price_max": int(listed * 1.05),
                    "price_position_index": 0
                },
                "exit_strategy": {
                    "estimated_exit_price": est_exit,
                    "negotiation_buffer_percent": 10
                },
                "commercial_analysis": {
                    "estimated_total_cost": cost,
                    "finance_cost": (listed * 0.0015 * risk_result_v8.get('estimated_days_to_sell', 15)),
                    "net_profit_tl": int(net_profit),
                    "net_margin_percent": round(min(net_margin, 25.0)),
                    "optimal_purchase_price": max(0, est_exit - (est_exit * 0.12) - 4000),
                    "maximum_purchase_price": cost
                },
                "liquidity_metrics": {
                    "liquidity_score": 100 - risk_result_v8.get('estimated_days_to_sell', 15),
                    "estimated_days_to_sell": risk_result_v8.get('estimated_days_to_sell', 15),
                    "final_days_to_sell": risk_result_v8.get('estimated_days_to_sell', 15)
                },
                "technical_scoring": {
                    "opportunity_score": risk_result_v8.get('opportunity_score', 0),
                    "risk_percentage": risk_result_v8.get('total_risk', 0)
                },
                "dealer_verdict": {
                    "decision": risk_result_v8.get('decision', 'HOLD'),
                    "action_note": "Risk Motoru V8 üzerinden deterministik hesaplandı."
                },
                "technical_summary": f"Araç {km:,} km'de ve {year} modeldir. V8 Deterministik Risk: %{risk_result_v8.get('total_risk', 0)}. Galeri bazlı matematiksel değerleme devrede."
            }
        else:
            ai_json = self._sanitize_ai_json(ai_json_raw, opp_res)

        glm_metin = self.glm_rapor(
            f"Aşağıdaki araç verisini ve AI analizini denetle:\n{json.dumps(ai_json, ensure_ascii=False)}"
        )

        return {
            "arac": arac,
            "piyasa": piyasa,
            "deger_analizi": deger_analizi,
            "fiyat_analizi": fiyat_analizi,
            "opp_res": opp_res,
            "ai_json": ai_json,
            "ai_rapor": {
                "glm": glm_metin,
                "gemini_aktif": self._gemini_enabled,
                "glm_aktif": self._glm_enabled,
            },
            # v8.0 Deterministik Risk Sonuçları
            "risk_v8": risk_result_v8,
            "km_analysis": dataclasses.asdict(km_analysis) if km_analysis else None,
            "paint_analysis": dataclasses.asdict(paint_analysis) if paint_analysis else None,
            "timestamp": datetime.now().isoformat(),
        }

    def _queue_priority_scrape(self, brand: str, model: str, year: int):
        """Eksik olan marka/modeli arka plan worker kuyruğuna ekler."""
        # TODO: Redis veya DB tabanlı bir kuyruk sistemi entegre edilecek.
        # Şimdilik sadece logluyoruz.
        print(f"📌 [PriorityQueue] Eksik veri tespit edildi, kuyruğa eklendi: {brand} {model} {year}")
        pass


# ─── Singleton ───────────────────────────────────────────────────────────────
_analiz_servisi: Optional[AnalizServisi] = None

def get_analiz_servisi() -> AnalizServisi:
    global _analiz_servisi
    if _analiz_servisi is None:
        _analiz_servisi = AnalizServisi()
    return _analiz_servisi

def reset_analiz_servisi():
    """Singleton'ı sıfırla — key değişikliği sonrası çağrılabilir."""
    global _analiz_servisi
    _analiz_servisi = None

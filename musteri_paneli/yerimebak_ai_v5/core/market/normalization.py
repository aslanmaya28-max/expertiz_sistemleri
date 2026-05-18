# -*- coding: utf-8 -*-
"""
YERİMEBAK AI – ANTIGRAVITY v5.2+ SaaS CORE
Normalization Layer: Input Standardization & Validation
"""

from typing import Dict, Any, List
import re
from datetime import datetime

class NormalizationLayer:
    """
    Standardizes raw inputs from multiple sources into a unified forensic snapshot.
    Enforces consistency for the 12 core automotive fields.
    """
    
    @staticmethod
    def normalize_vehicle(raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Input: Raw dict from Scrapers (Arabam, Borusan).
        Output: Normalized vehicle snapshot with 12 standardized fields.
        """
        # 1. Basic Cleaning
        brand = str(raw_data.get("brand") or "").upper().strip()
        series = str(raw_data.get("series") or "").strip()
        model = str(raw_data.get("model") or "").strip()
        
        # 2. Reconcile "Sahibinden" placeholders
        if "SAHIBINDEN" in brand or not brand or brand == "UNKNOWN" or len(brand) < 2:
            title = str(raw_data.get("title", "")).upper()
            model_upper = model.upper()
            # Multi-level brand/series mapping
            brand_map = {
                "VOLKSWAGEN": ["VOLKSWAGEN", "VW", "PASSAT", "GOLF", "POLO", "TIGUAN", "JETTA"],
                "BMW": ["BMW", "320", "520", "X5"],
                "MERCEDES": ["MERCEDES", "BENZ", "C180", "E200", "A180"],
                "FIAT": ["FIAT", "EGEA", "LINEA", "DOBLO", "FIORINO"],
                "RENAULT": ["RENAULT", "MEGANE", "CLIO", "SYMBOL", "FLUENCE"],
                "FORD": ["FORD", "FOCUS", "FIESTA", "TRANSIT"],
                "TOYOTA": ["TOYOTA", "COROLLA", "YARIS", "AURIS"],
                "SEAT": ["SEAT", "LEON", "IBIZA"],
                "SKODA": ["SKODA", "OCTAVIA", "SUPERB", "FABIA"],
                "OPEL": ["OPEL", "ASTRA", "CORSA", "INSIGNIA"],
                "AUDI": ["AUDI", "A3", "A4", "A6", "Q3", "Q5"],
                "HYUNDAI": ["HYUNDAI", "I20", "I30", "ACCENT", "ELANTRA", "TUCSON"],
                "DACIA": ["DACIA", "DUSTER", "SANDERO", "LODGY", "STEPWAY"],
                "HONDA": ["HONDA", "CIVIC", "ACCORD", "CITY"],
                "KIA": ["KIA", "SPORTAGE", "RIO", "CEED", "CERATO"],
                "PEUGEOT": ["PEUGEOT", "208", "308", "2008", "3008", "5008"],
                "CITROEN": ["CITROEN", "C3", "C4", "C5", "ELYSEE"],
                "NISSAN": ["NISSAN", "QASHQAI", "MICRA", "JUKE"]
            }
            
            found_brand = False
            for b_canonical, aliases in brand_map.items():
                if any(al in title or al in model_upper for al in aliases):
                    brand = b_canonical
                    found_brand = True
                    break
        
        # 2.1 Brand Promotion (If model contains brand but brand field is empty/generic)
        if brand in ["", "STANDART", "UNKNOWN"]:
            for b_name in ["RENAULT", "VOLKSWAGEN", "SEAT", "SKODA", "OPEL", "AUDI", "FIAT", "FORD", "TOYOTA", "HYUNDAI", "MERCEDES", "BMW"]:
                if b_name in model.upper():
                    brand = b_name
                    break

        # 3. Handle Brand-Model Redundancy (e.g. "Volkswagen Volkswagen Passat" -> brand: "VW", model: "Passat")
        if brand and brand in model.upper():
            model = re.sub(brand, "", model, flags=re.IGNORECASE).strip()
        if brand and brand in series.upper():
            series = re.sub(brand, "", series, flags=re.IGNORECASE).strip()

        # 4. KM Normalization
        km_raw = str(raw_data.get("km", "0"))
        km_digits = re.sub(r"\D", "", km_raw)
        km_val = int(km_digits) if km_digits else 0
        
        # 5. Price Normalization
        price_raw = str(raw_data.get("price", "0"))
        price_digits = re.sub(r"\D", "", price_raw)
        price_val = int(price_digits) if price_digits else 0

        # 6. Year Normalization
        year_raw = str(raw_data.get("year", "0"))
        year_digits = re.sub(r"\D", "", year_raw)
        year_val = int(year_digits) if year_digits else 0

        # 7. Engine & Power Normalization
        engine_size = str(raw_data.get("engine_size") or raw_data.get("motor_hacmi") or "").strip()
        horsepower = str(raw_data.get("horsepower") or raw_data.get("motor_gucu") or "").strip()
        
        if engine_size in ["0", "0.0", ""]: engine_size = None
        if horsepower in ["0", "0.0", ""]: horsepower = None

        # 8. Date Normalization
        listing_date = str(raw_data.get("listing_date") or "").strip()
        if not listing_date:
            listing_date = datetime.now().strftime("%d %B %Y") # Default to today if missing

        # 9. Categorical Fields
        fuel = str(raw_data.get("fuel") or raw_data.get("fuel_type") or "Belirtilmemiş").capitalize().strip()
        transmission = str(raw_data.get("transmission") or raw_data.get("gear_type") or "Belirtilmemiş").capitalize().strip()
        body_type = str(raw_data.get("body_type") or raw_data.get("kasa_tipi") or "Belirtilmemiş").capitalize().strip()
        color = str(raw_data.get("color") or "Belirtilmemiş").capitalize().strip()

        # 10. Structural Flags
        changed = [c.lower().strip() for c in raw_data.get("changed", [])]
        painted = [p.lower().strip() for p in raw_data.get("painted", [])]
        
        # 10.1 Standart Cleanup
        if brand.upper() == "STANDART": brand = ""
        if series.upper() == "STANDART": series = ""
        if model.upper() == "STANDART": model = ""
        if fuel.upper() == "STANDART": fuel = "Belirtilmemiş"
        if transmission.upper() == "STANDART": transmission = "Belirtilmemiş"
        if body_type.upper() == "STANDART": body_type = "Belirtilmemiş"
        if color.upper() == "STANDART": color = "Belirtilmemiş"
        
        # 11. Canonical Snapshot
        return {
            "listing_date": listing_date,
            "brand": brand,
            "series": series,
            "model": model,
            "year": year_val,
            "km": km_val,
            "price": price_val,
            "transmission": transmission,
            "gear_type": transmission, # Alias for repository
            "fuel": fuel,
            "fuel_type": fuel, # Alias for repository
            "body_type": body_type,
            "color": color,
            "engine_size": engine_size,
            "horsepower": horsepower,
            "paint_info": raw_data.get("paint_info"),
            "accident_record": raw_data.get("accident_record"),
            "source": raw_data.get("source", "unknown"),
            "url": raw_data.get("url"),
            "image_url": raw_data.get("image_url"),
            "location": raw_data.get("location"),
            "title": raw_data.get("title"),
            "guarantee": raw_data.get("guarantee")
        }

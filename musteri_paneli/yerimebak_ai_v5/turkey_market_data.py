"""
YERİMEBAK AI - Türkiye 2. El Pazarı Veri Modeli
En çok satılan segment ve modeller
"""

TURKEY_TOP_SELLING_MODELS = {
    'b_segment': {
        'name': 'B Segment (Küçük / Şehir İçi)',
        'description': 'Fiyat/performans ve yakıt ekonomisi ile en çok rağbet gören araç grubu',
        'models': [
            {'brand': 'Renault', 'model': 'Clio', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 1},
            {'brand': 'Renault', 'model': 'Symbol', 'years': [2018, 2019, 2020, 2021], 'priority': 2},
            {'brand': 'Volkswagen', 'model': 'Polo', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 3},
            {'brand': 'Hyundai', 'model': 'i20', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 4},
            {'brand': 'Ford', 'model': 'Fiesta', 'years': [2018, 2019, 2020, 2021], 'priority': 5},
            {'brand': 'Opel', 'model': 'Corsa', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 6},
            {'brand': 'Dacia', 'model': 'Sandero', 'years': [2019, 2020, 2021, 2022], 'priority': 7},
            {'brand': 'Peugeot', 'model': '301', 'years': [2018, 2019, 2020, 2021], 'priority': 8},
            {'brand': 'Citroen', 'model': 'C-Elysee', 'years': [2018, 2019, 2020], 'priority': 9},
            {'brand': 'Seat', 'model': 'Ibiza', 'years': [2018, 2019, 2020, 2021], 'priority': 10},
        ]
    },
    
    'c_segment': {
        'name': 'C Segment (Orta Sınıf / Aile)',
        'description': 'Türkiye 2. el pazarındaki en geniş hacimli segment (toplam satışın ~50%)',
        'models': [
            {'brand': 'Fiat', 'model': 'Egea', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 1},
            {'brand': 'Renault', 'model': 'Megane', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 2},
            {'brand': 'Ford', 'model': 'Focus', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 3},
            {'brand': 'Toyota', 'model': 'Corolla', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 4},
            {'brand': 'Opel', 'model': 'Astra', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 5},
            {'brand': 'Fiat', 'model': 'Linea', 'years': [2018, 2019, 2020], 'priority': 6},
            {'brand': 'Volkswagen', 'model': 'Golf', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 7},
            {'brand': 'Honda', 'model': 'Civic', 'years': [2018, 2019, 2020, 2021], 'priority': 8},
            {'brand': 'Renault', 'model': 'Fluence', 'years': [2018, 2019], 'priority': 9},
            {'brand': 'Hyundai', 'model': 'Accent', 'years': [2018, 2019, 2020], 'priority': 10},
        ]
    },
    
    'd_segment': {
        'name': 'D Segment (Üst-Orta / Geniş)',
        'description': 'Prestijli/ferah aile veya iş otomobilleri',
        'models': [
            {'brand': 'Volkswagen', 'model': 'Passat', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 1},
            {'brand': 'BMW', 'model': '3 Series', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 2},
            {'brand': 'Mercedes-Benz', 'model': 'C-Class', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 3},
            {'brand': 'Skoda', 'model': 'Superb', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 4},
            {'brand': 'Audi', 'model': 'A4', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 5},
            {'brand': 'Citroen', 'model': 'C5', 'years': [2018, 2019, 2020], 'priority': 6},
            {'brand': 'Opel', 'model': 'Insignia', 'years': [2018, 2019, 2020, 2021], 'priority': 7},
        ]
    },
    
    'suv': {
        'name': 'SUV / Crossover',
        'description': 'Toplam satışların %56sını oluşturan en güçlü segment',
        'models': [
            {'brand': 'Renault', 'model': 'Duster', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 1},
            {'brand': 'Nissan', 'model': 'Qashqai', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 2},
            {'brand': 'Hyundai', 'model': 'Tucson', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 3},
            {'brand': 'Peugeot', 'model': '2008', 'years': [2019, 2020, 2021, 2022, 2023], 'priority': 4},
            {'brand': 'Peugeot', 'model': '3008', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 5},
            {'brand': 'Volkswagen', 'model': 'T-Roc', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 6},
            {'brand': 'Volkswagen', 'model': 'Taigo', 'years': [2021, 2022, 2023], 'priority': 7},
            {'brand': 'Hyundai', 'model': 'Bayon', 'years': [2021, 2022, 2023], 'priority': 8},
            {'brand': 'Chery', 'model': 'Tiggo 7 Pro', 'years': [2021, 2022, 2023], 'priority': 9},
            {'brand': 'Chery', 'model': 'Tiggo 8 Pro', 'years': [2021, 2022, 2023], 'priority': 10},
            {'brand': 'Togg', 'model': 'T10X', 'years': [2023, 2024], 'priority': 11},
            {'brand': 'Dacia', 'model': 'Sandero Stepway', 'years': [2019, 2020, 2021, 2022, 2023], 'priority': 12},
        ]
    },
    
    'commercial': {
        'name': 'Hafif Ticari / Van',
        'description': 'Hem ticari hem aile aracı olarak kullanılan araçlar',
        'models': [
            {'brand': 'Fiat', 'model': 'Doblo', 'years': [2018, 2019, 2020, 2021, 2022, 2023], 'priority': 1},
            {'brand': 'Ford', 'model': 'Transit Courier', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 2},
            {'brand': 'Ford', 'model': 'Transit', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 3},
            {'brand': 'Fiat', 'model': 'Fiorino', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 4},
            {'brand': 'Volkswagen', 'model': 'Caddy', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 5},
            {'brand': 'Volkswagen', 'model': 'Transporter', 'years': [2017, 2018, 2019, 2020, 2021, 2022], 'priority': 6},
            {'brand': 'Renault', 'model': 'Kangoo', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 7},
            {'brand': 'Peugeot', 'model': 'Partner', 'years': [2018, 2019, 2020, 2021, 2022], 'priority': 8},
        ]
    },
    
    'electric': {
        'name': 'Elektrikli Araçlar',
        'description': '2025 itibarıyla talebi yükselen EV segmenti',
        'models': [
            {'brand': 'Togg', 'model': 'T10X', 'years': [2023, 2024], 'priority': 1},
            {'brand': 'Togg', 'model': 'T10F', 'years': [2024], 'priority': 2},
            {'brand': 'Volvo', 'model': 'EX30', 'years': [2023, 2024], 'priority': 3},
            {'brand': 'Tesla', 'model': 'Model Y', 'years': [2020, 2021, 2022, 2023, 2024], 'priority': 4},
            {'brand': 'Opel', 'model': 'Mokka-e', 'years': [2021, 2022, 2023], 'priority': 5},
            {'brand': 'MG', 'model': 'MG4', 'years': [2022, 2023, 2024], 'priority': 6},
            {'brand': 'BYD', 'model': 'Atto 3', 'years': [2023, 2024], 'priority': 7},
        ]
    }
}

# Marka bazlı top sellers (tüm segmentler genelinde)
TOP_BRANDS_TURKEY = [
    {'brand': 'Volkswagen', 'note': 'Çevrim içi ilanlarda en çok satan marka 2024'},
    {'brand': 'Renault', 'note': 'Clio ve Megane ile güçlü satış'},
    {'brand': 'Fiat', 'note': 'Egea & Doblo ile yüksek hacim'},
    {'brand': 'Ford', 'note': 'Focus & ticari modeller'},
    {'brand': 'BMW', 'note': 'Premium ikinci elde güçlü'},
    {'brand': 'Opel', 'note': 'Astra / hafif ticari'},
    {'brand': 'Peugeot', 'note': 'SUV ve hatch'},
    {'brand': 'Hyundai', 'note': 'i20 / SUV modeller'},
    {'brand': 'Toyota', 'note': 'Corolla / SUV'},
    {'brand': 'Mercedes-Benz', 'note': 'Premium segment'},
    {'brand': 'Audi', 'note': 'Premium segment'},
    {'brand': 'Skoda', 'note': 'D segment güçlü'},
]

def get_top_models_by_segment(segment_key: str, limit: int = 5):
    """Segment bazında en çok satılan modelleri döndürür"""
    if segment_key not in TURKEY_TOP_SELLING_MODELS:
        return []
    
    models = TURKEY_TOP_SELLING_MODELS[segment_key]['models']
    # Priority'ye göre sırala ve limit kadar al
    sorted_models = sorted(models, key=lambda x: x['priority'])[:limit]
    return sorted_models

def get_all_models(limit_per_segment: int = 3):
    """Tüm segmentlerden top modelleri al"""
    all_models = []
    for segment_key, segment_data in TURKEY_TOP_SELLING_MODELS.items():
        models = get_top_models_by_segment(segment_key, limit_per_segment)
        for model in models:
            model['segment'] = segment_key
            model['segment_name'] = segment_data['name']
        all_models.extend(models)
    return all_models

if __name__ == '__main__':
    # Test
    print("🚗 Türkiye 2. El Pazarı - En Çok Satanlar")
    print("=" * 60)
    
    for segment_key, segment_data in TURKEY_TOP_SELLING_MODELS.items():
        print(f"\n{segment_data['name']}")
        print(f"📝 {segment_data['description']}")
        print(f"Toplam Model: {len(segment_data['models'])}")
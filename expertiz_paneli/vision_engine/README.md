# 🚀 Vision Engine - YerimeBak Sistemleri

## 📖 Overview

Vision Engine, YerimeBak Sistemleri'nin **Python Backend**'idir. Araç piyasa değerini analiz etmek için **Robust Architecture** (Dayanıklı Mimari) prensipleriyle tasarlanmıştır.

### 🎯 Mission Statement

> "AI'yı bir 'falcı' olmaktan çıkarıp, Python'un sunduğu soğuk ve gerçek matematiksel verilerin 'sözcüsü' haline getirmek."

---

## 🏗️ Mimarî Yapısı

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter Frontend                         │
│                  (YerimeBak Expertiz)                       │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTP REST API
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server                            │
│                   Port: 8000                                 │
│                  /analyze Endpoint                          │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Collector  │  │Core Engine   │  │AI Commentary │
│              │  │              │  │              │
│• Arabam      │  │• IQR Outlier │  │• Gemini 1.5  │
│• VavaCars    │  │• Volatility  │  │  Flash       │
│• Borusan     │  │• Confidence  │  │              │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └─────────┬───────┴─────────┬───────┘
                 ▼                 ▼
         ┌──────────────┐  ┌──────────────┐
         │Image Analysis│  │Factor Match  │
         │              │  │              │
         │• YOLOv8      │  │• Paint adj.  │
         │• Gemini      │  │• Damage adj. │
         └──────────────┘  └──────────────┘
```

---

## 🔑 Özellikler

### 1. Multi-Source Data Collection
- **Arabam (Piyasa)**: Genel piyasa verileri
- **VavaCars (Nakit Alt Sınır)**: Minimum fiyat referansı
- **Borusan Next (Premium Üst Sınır)**: Premium fiyat referansı
- **Paralel Scraping**: 3 kaynak aynı anda taranır
- **Timeout Yönetimi**: Bir site düşerse diğerleriyle devam eder

### 2. Core Engine (İstatistiksel Beyin)
```python
# IQR (Interquartile Range) Outlier Removal
q1 = np.percentile(prices, 25)
q3 = np.percentile(prices, 75)
iqr = q3 - q1

# Confidence Score (0-100)
confidence = sample_score + cv_score

# Volatility Index
volatility = std_deviation / mean
```

### 3. AI Commentary (Gemini 1.5 Flash)
- **Rol**: Sadece metrikleri yorumlar, KESİNLİKLE fiyat üretmez
- **Girdi**: Python Core Engine'den gelen JSON metrikleri
- **Çıktı**: Profesyonel ekspertiz dili
- **Format**: 
  - Genel Değerlendirme
  - Anahtar Bulgular
  - Piyasa Pozisyonu
  - Öneriler
  - Güven Düzeyi

### 4. Image Analysis (Vision)
- **YOLOv8**: Boyalı/hasarlı parça tespiti
- **Gemini Multimodal**: Görsel anlama ve yorumlama
- **Factor Matching**: `market_avg * 0.95` (sol çamurluk boyalı ise)

### 5. Adjustments Calculator
```python
paint_factor = 1.0 - (len(painted_parts) * 0.03)  # Max -20%
damage_factor = 1.0 - (len(damaged_parts) * 0.10)  # Max -40%
km_factor = 1.0 - ((excess_km / 10000) * 0.02)     # Max -15%

fair_value = base_price * paint_factor * damage_factor * km_factor
```

---

## 📦 Kurulum

### Prerequisites
- Python 3.10+
- pip veya poetry
- Google API Key (Opsiyonel - AI Commentary için)

### Adım 1: Dependency Installation
```bash
cd vision_engine
pip install -r requirements.txt

# Playwright browser setup
playwright install chromium
```

### Adım 2: Environment Variables
`.env` dosyası oluşturun:
```env
GOOGLE_API_KEY=your_gemini_api_key_here
ENVIRONMENT=development
```

### Adım 3: Run Server
```bash
python -m vision_engine.main
# veya
uvicorn vision_engine.main:app --host 0.0.0.0 --port 8000 --reload
```

Server `http://localhost:8000`'de çalışacaktır.

---

## 🔌 API Dokümantasyonu

### Endpoint: `/analyze`
**Method**: `POST`  
**Content-Type**: `application/json`

#### Request Example
```json
{
  "brand": "Volkswagen",
  "model": "Passat",
  "year": 2022,
  "km": 45000,
  "fuel_type": "Benzin",
  "transmission": "Otomatik",
  "location": "İstanbul",
  "images": []
}
```

#### Response Example
```json
{
  "success": true,
  "request": { /* ... */ },
  "market_data": {
    "listings": [ /* 30+ listings */ ],
    "total_sources": 3,
    "scrape_timestamp": "2026-01-30T22:50:00"
  },
  "core_metrics": {
    "avg_price": 850000.0,
    "median_price": 830000.0,
    "std_deviation": 95000.0,
    "min_price": 750000.0,
    "max_price": 950000.0,
    "confidence_score": 85.5,
    "volatility_index": 0.12,
    "iqr_lower_bound": 720000.0,
    "iqr_upper_bound": 980000.0,
    "sample_size": 42
  },
  "ai_commentary": {
    "overall_assessment": "Araç genel olarak iyi bakımlı...",
    "key_findings": [
      "Piyasa ortalaması: 850.000 TL",
      "Volatilite düşük - fiyatlar stabil"
    ],
    "market_position": "Piyasa ortalamasında",
    "recommendations": [
      "Uzman incelemesi önerilir"
    ],
    "confidence_level": "Yüksek"
  },
  "final_recommendation": "🟢 İYİ FİYAT - Piyasa değerinin hafif altında. Alınabilir.",
  "estimated_value": 835000.0,
  "value_range": [780000.0, 890000.0],
  "processing_time_ms": 2450.5
}
```

### Other Endpoints
- `GET /` - Health check
- `GET /health` - System status
- `POST /analyze/quick` - Lightweight analysis
- `GET /stats` - System statistics

---

## 📱 Flutter Entegrasyonu

### VisionEngineService.dart
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class VisionEngineService {
  static const String baseUrl = 'http://localhost:8000';
  
  Future<AnalysisResponse> analyzeVehicle(VehicleRequest request) async {
    final response = await http.post(
      Uri.parse('$baseUrl/analyze'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    
    if (response.statusCode == 200) {
      return AnalysisResponse.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Analysis failed: ${response.body}');
    }
  }
}

// Usage
final result = await VisionEngineService().analyzeVehicle(
  VehicleRequest(
    brand: 'Volkswagen',
    model: 'Passat',
    year: 2022,
    km: 45000,
  ),
);

print('Estimated Value: ${result.estimatedValue} TL');
print('Recommendation: ${result.finalRecommendation}');
```

---

## 🧪 Test Etmek

### 1. API Test (curl)
```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "brand": "Volkswagen",
    "model": "Passat",
    "year": 2022,
    "km": 45000,
    "fuel_type": "Benzin",
    "transmission": "Otomatik"
  }'
```

### 2. Python Test Script
```python
import asyncio
from vision_engine.manager import analyze_vehicle
from vision_engine.models import AnalysisRequest

async def test_analysis():
    request = AnalysisRequest(
        brand="Volkswagen",
        model="Passat",
        year=2022,
        km=45000,
        fuel_type="Benzin",
        transmission="Otomatik"
    )
    
    result = await analyze_vehicle(request)
    
    print(f"✅ Analysis Complete!")
    print(f"Estimated Value: {result.estimated_value:,.0f} TL")
    print(f"Confidence: {result.core_metrics.confidence_score}%")
    print(f"Recommendation: {result.final_recommendation}")

asyncio.run(test_analysis())
```

### 3. Interactive API Documentation
Browser'da açın: `http://localhost:8000/docs`

---

## 🎓 Mimari Prensipler

### 1. Separation of Concerns
- **Collector**: Sadece veri toplar
- **Core Engine**: Sadece istatistik hesaplar
- **AI Commentary**: Sadece metrikleri yorumlar
- **Image Analysis**: Sadece görsel tespit yapar

### 2. Fail-Safe Design
- Bir kaynak düşerse diğerleriyle devam eder
- AI yoksa mock yorum kullanır
- Image analysis zorunlu değil

### 3. Type Safety
- Pydantic V2 ile tüm veri modelleri validated
- Runtime type checking
- Auto-generated API docs

### 4. Async-First
- Tüm I/O operasyonları async
- Playwright async scraping
- Non-blocking API calls

---

## 📊 Performans Metrikleri

- **Ortalama Response Time**: 2-3 saniye
- **Data Sources**: 3 paralel kaynak
- **Confidence Score**: 0-100 arası
- **Outlier Removal**: IQR method
- **Volatility Index**: Coefficient of variation

---

## 🔮 Gelecek Vizyonu

### Seviye 3: Vision Engine Enhancements
1. **Real-time Image Analysis**
   - Flutter camera integration
   - Live paint detection
   - Panel gap measurement

2. **YOLOv8 Custom Model**
   - Türkçe araç parçaları dataset
   - Custom training
   - 95%+ accuracy target

3. **Historical Data Analysis**
   - Price trend tracking
   - Seasonal adjustments
   - Market forecasting

---

## 🛠️ Troubleshooting

### Playwright Installation
```bash
# If browser not found
playwright install chromium
```

### Google API Key
```bash
# AI Commentary için gerekli
export GOOGLE_API_KEY="your_key_here"
```

### CORS Issues
```python
# In main.py, add Flutter app URL to allow_origins
allow_origins=["http://localhost:3000", "file://"]
```

---

## 📝 Lisans

YerimeBak Sistemleri - Internal Use Only

---

## 👥 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Add tests
5. Submit PR

---

**🎉 Vision Engine - "Robust Architecture, Not Guesswork"**
# YerimeBak — Ekspertiz ve Yapay Zekâ Değerleme

Müşteri almak istediği aracın linkini ve bilgilerini gönderir, ödemeyi yapar. Admin talebi bir personele atar. Personel aracı yerinde inceler ve iç, dış ve kurumsal ekspertiz raporunu gönderir. Ardından yapay zekâ raporu analiz eder, piyasa değeri ile bulguların değere etkisini hesaplar. Admin kontrol edip onaylar ve dört rapor birlikte müşteriye gider.

## Klasörler

| Klasör | İçerik |
|---|---|
| `musteri_paneli/yerimebak_ai_v5/` | FastAPI API, merkezi yapay zekâ değerlemesi, ödeme (PayTR), e-posta |
| `musteri_paneli/frontend/` | Müşteri sitesi (Next.js) — www.yerimebak.com.tr |
| `expertiz_paneli/` | Admin ve personel paneli (Flutter web) — admin.yerimebak.com.tr |

## Yapay zekâ değerlemesi nasıl çalışır

1. Personel raporu gönderilince arka plandaki işleyici devreye girer (`workers/ai_analysis_worker.py`).
2. **Piyasa değeri:** DeepSeek, OpenRouter web aramasıyla 3 sorguda benzer ilanları bulur (`services/web_market_reference.py`). Fiyatı kaynak sayfada geçmeyen, tahmin sitesinden gelen, yılı, km'si ya da motoru uymayan ve ağır hasarlı ilanlar elenir. Aynı paketten en az 3 ilan varsa yalnızca o paket kullanılır.
3. **Bulgular:** Personelin boya, değişen, hasar ve tramer bulguları değerden düşülür (`core/ai/inspection_valuation.py`).
4. **Kontrol gerekli:** Az emsal, geniş fiyat aralığı ya da paket eşleşmemesi admin ekranında işaretlenir. Admin piyasa değerini düzeltebilir; yapay zekânın değeri ve admin'in değeri birlikte saklanır.
5. Hiçbir rapor admin onayı olmadan müşteriye gitmez.

Kazıyıcı, Chrome eklentisi ve Streamlit paneli kaldırıldı. Eski halleri `arsiv/docker-surum` etiketinde duruyor:

```sh
git checkout arsiv/docker-surum
```

## Yerelde çalıştırma

```sh
cd musteri_paneli
cp .env.example .env            # DATABASE_URL, SECRET_KEY, OPENROUTER_API_KEY
pip install -r requirements.txt
python -m uvicorn yerimebak_ai_v5.main:app --port 8000
```

## Testler

```sh
cd musteri_paneli
pytest tests/unit
# Uçtan uca (boş bir PostgreSQL ister, her çalıştırmada sıfırlanır):
TEST_DATABASE_URL=postgresql://kullanici:sifre@localhost:5432/test_db SECRET_KEY=test pytest tests/integration
```

Flutter: `cd expertiz_paneli && flutter analyze && flutter test`

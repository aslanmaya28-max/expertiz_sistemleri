# Ilan Analizi Giris Kanallari Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mobil paylasim, webde manuel link girisi ve Chrome eklentisini ayni merkezi ilan analizi hattina baglamak; sonuclari musteri panelindeki `Analizlerim` bolumunde gostermek.

**Architecture:** FastAPI tarafinda `analysis_intake` odakli ortak servis ve endpoint eklenecek; URL tabanli girisler burada kuyruga alinacak, mevcut kredi gecmisi analiz arsivi olarak genisletilecek. Next.js paneline manuel link formu eklenecek, Flutter tarafinda paylasilan URL'yi yakalayan ince bir servis ve kisa onay akisi kurulacak.

**Tech Stack:** FastAPI, Python unittest, Next.js/TypeScript, Flutter/Dart, mevcut `PaymentService`, mevcut musteri paneli API yardimcilari.

---

## File Map

- Create `musteri_paneli/yerimebak_ai_v5/services/analysis_intake_service.py`: URL tabanli analiz girislerini dogrular, kuyruk kaydi hazirlar ve kaynak bilgisini standartlastirir.
- Create `musteri_paneli/yerimebak_ai_v5/api/v1/endpoints/analysis_intake.py`: auth korumali manuel/mobil URL giris endpoint'i.
- Modify `musteri_paneli/yerimebak_ai_v5/api/v1/router.py`: yeni router'i kaydeder.
- Modify `musteri_paneli/yerimebak_ai_v5/services/payment_service.py`: analiz gecmisi kaydini kaynak/durum alanlariyla uyumlu hale getirir.
- Create `musteri_paneli/tests/unit/test_analysis_intake_service.py`: URL intake davranislari.
- Create `musteri_paneli/tests/unit/test_analysis_intake_api.py`: endpoint davranislari.
- Modify `musteri_paneli/frontend/src/lib/api.ts`: manuel link girisi icin tipler ve API fonksiyonu.
- Create `musteri_paneli/frontend/src/app/arac-analiz/page.tsx`: link yapistirma ekrani.
- Modify `musteri_paneli/frontend/src/app/panel/page.tsx`: `Analizlerim` kartlarinda kaynak/durum sunumu.
- Modify `expertiz_paneli/pubspec.yaml`: mobil paylasim paketi.
- Create `expertiz_paneli/lib/services/shared_listing_intake_service.dart`: paylasilan URL'yi normalize edip backend'e yollar.
- Modify `expertiz_paneli/lib/main.dart`: paylasim listener'ini baslatir.
- Create `expertiz_paneli/test/shared_listing_intake_service_test.dart`: URL yakalama/mesaj davranisi.

### Task 1: Ortak analiz intake servisi

**Files:**
- Create: `musteri_paneli/yerimebak_ai_v5/services/analysis_intake_service.py`
- Test: `musteri_paneli/tests/unit/test_analysis_intake_service.py`

- [ ] **Step 1: Write the failing test**

```python
import unittest

from yerimebak_ai_v5.services.analysis_intake_service import AnalysisIntakeService


class AnalysisIntakeServiceTests(unittest.TestCase):
    def test_builds_queue_payload_for_mobile_share_url(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="https://www.sahibinden.com/ilan/vasita-otomobil-test-123",
            source="mobile_share",
        )

        self.assertEqual(payload["source"], "mobile_share")
        self.assertEqual(payload["status"], "queued")
        self.assertEqual(payload["url"], "https://www.sahibinden.com/ilan/vasita-otomobil-test-123")

    def test_rejects_unsupported_source(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="https://example.com/car",
                source="unknown",
            )
```

- [ ] **Step 2: Run test to verify it fails**

Run:
`python -m unittest tests.unit.test_analysis_intake_service -v`

Expected: FAIL because `analysis_intake_service` does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
from urllib.parse import urlparse


class AnalysisIntakeService:
    allowed_sources = {"mobile_share", "manual_paste", "chrome_extension"}

    def build_url_intake(self, url: str, source: str) -> dict:
        normalized = url.strip()
        parsed = urlparse(normalized)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError("Gecersiz URL")
        if source not in self.allowed_sources:
            raise ValueError("Gecersiz kaynak")
        return {"url": normalized, "source": source, "status": "queued"}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
`python -m unittest tests.unit.test_analysis_intake_service -v`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add musteri_paneli/yerimebak_ai_v5/services/analysis_intake_service.py musteri_paneli/tests/unit/test_analysis_intake_service.py
git commit -m "feat: add analysis intake service"
```

### Task 2: Backend endpoint ve merkezi kayit

**Files:**
- Create: `musteri_paneli/yerimebak_ai_v5/api/v1/endpoints/analysis_intake.py`
- Modify: `musteri_paneli/yerimebak_ai_v5/api/v1/router.py`
- Modify: `musteri_paneli/yerimebak_ai_v5/services/payment_service.py`
- Test: `musteri_paneli/tests/unit/test_analysis_intake_api.py`

- [ ] **Step 1: Write the failing test**

```python
import unittest
from unittest.mock import patch

from yerimebak_ai_v5.api.v1.endpoints.analysis_intake import create_url_analysis, UrlAnalysisRequest


class AnalysisIntakeApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_manual_paste_creates_queued_history_entry(self):
        fake_user = {"id": 7}
        with patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_payment_service") as payment_factory:
            payment_factory.return_value.record_queued_analysis.return_value = {
                "success": True,
                "history_id": "hist-1",
            }

            result = await create_url_analysis(
                UrlAnalysisRequest(url="https://www.sahibinden.com/ilan/1", source="manual_paste"),
                user=fake_user,
            )

        self.assertEqual(result["status"], "queued")
        self.assertEqual(result["history_id"], "hist-1")
```

- [ ] **Step 2: Run test to verify it fails**

Run:
`python -m unittest tests.unit.test_analysis_intake_api -v`

Expected: FAIL because endpoint does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```python
class UrlAnalysisRequest(BaseModel):
    url: str
    source: str = "manual_paste"


@router.post("/url")
async def create_url_analysis(
    request: UrlAnalysisRequest,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    intake = get_analysis_intake_service().build_url_intake(request.url, request.source)
    payment = get_payment_service()
    queued = payment.record_queued_analysis(user["id"], intake)
    return {"success": True, "status": intake["status"], "history_id": queued["history_id"]}
```

`PaymentService.record_queued_analysis()` once `analysis_history` tablosuna `vehicle_json={"url": ..., "source": ..., "status": "queued"}` ve `valuation_json={"credits_deducted": 0}` yazar; kredi bu adimda dusmez.

- [ ] **Step 4: Run test to verify it passes**

Run:
`python -m unittest tests.unit.test_analysis_intake_api -v`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add musteri_paneli/yerimebak_ai_v5/api/v1/endpoints/analysis_intake.py musteri_paneli/yerimebak_ai_v5/api/v1/router.py musteri_paneli/yerimebak_ai_v5/services/payment_service.py musteri_paneli/tests/unit/test_analysis_intake_api.py
git commit -m "feat: add url analysis intake endpoint"
```

### Task 3: Web panelinde manuel link girisi

**Files:**
- Modify: `musteri_paneli/frontend/src/lib/api.ts`
- Create: `musteri_paneli/frontend/src/app/arac-analiz/page.tsx`
- Modify: `musteri_paneli/frontend/src/app/panel/page.tsx`

- [ ] **Step 1: Write the failing behavior expectation**

```tsx
// Expected UI behavior:
// submitting a URL calls createUrlAnalysis({ url, source: "manual_paste" })
// success message says the analysis was queued
// panel history renders source and queued/completed state
```

- [ ] **Step 2: Implement minimal API helper**

```ts
export interface CreateUrlAnalysisPayload {
  url: string;
  source?: "manual_paste" | "mobile_share";
}

export function createUrlAnalysis(payload: CreateUrlAnalysisPayload): Promise<{ success: boolean; status: string; history_id: string }> {
  return fetchAPI("/analysis-intake/url", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}
```

- [ ] **Step 3: Implement minimal page**

```tsx
"use client";

export default function AracAnalizPage() {
  // form state
  // submit createUrlAnalysis({ url, source: "manual_paste" })
  // render concise success/error state
}
```

- [ ] **Step 4: Extend panel rendering**

`AnalysisHistoryItem` verisinden `vehicle_json.source` ve `vehicle_json.status` okunur; kart satirinda kaynak ve durum etiketi gosterilir.

- [ ] **Step 5: Verify**

Run:
`npm run build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add musteri_paneli/frontend/src/lib/api.ts musteri_paneli/frontend/src/app/arac-analiz/page.tsx musteri_paneli/frontend/src/app/panel/page.tsx
git commit -m "feat: add manual listing analysis entry"
```

### Task 4: Flutter mobil paylasim girisi

**Files:**
- Modify: `expertiz_paneli/pubspec.yaml`
- Create: `expertiz_paneli/lib/services/shared_listing_intake_service.dart`
- Modify: `expertiz_paneli/lib/main.dart`
- Test: `expertiz_paneli/test/shared_listing_intake_service_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yerimebak_sistemleri/services/shared_listing_intake_service.dart';

void main() {
  test('builds mobile share payload from url text', () {
    final payload = SharedListingIntakeService.buildPayload(
      'https://www.sahibinden.com/ilan/1',
    );

    expect(payload['source'], 'mobile_share');
    expect(payload['url'], 'https://www.sahibinden.com/ilan/1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
`flutter test test/shared_listing_intake_service_test.dart`

Expected: FAIL because service does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
class SharedListingIntakeService {
  static Map<String, String> buildPayload(String rawText) {
    final url = rawText.trim();
    return {'url': url, 'source': 'mobile_share'};
  }
}
```

- [ ] **Step 4: Add share package and app wiring**

`receive_sharing_intent` benzeri mevcut, uyumlu bir paket eklenir; `main.dart` icinde gelen text event'i alinip backend'e gonderilir ve kullaniciya yalnizca `Ilan alindi, analiz tamamlaninca panelinizde gorunecek.` mesaji gosterilir.

- [ ] **Step 5: Verify**

Run:
`flutter test test/shared_listing_intake_service_test.dart`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add expertiz_paneli/pubspec.yaml expertiz_paneli/lib/services/shared_listing_intake_service.dart expertiz_paneli/lib/main.dart expertiz_paneli/test/shared_listing_intake_service_test.dart
git commit -m "feat: add mobile share analysis intake"
```

### Task 5: Full verification

**Files:**
- No new files

- [ ] **Step 1: Run focused backend tests**

Run:
`python -m unittest tests.unit.test_analysis_intake_service tests.unit.test_analysis_intake_api -v`

Expected: PASS.

- [ ] **Step 2: Run web build**

Run:
`npm run build`

Expected: PASS.

- [ ] **Step 3: Run Flutter verification**

Run:
`flutter analyze`

Expected: PASS.

Run:
`flutter test`

Expected: PASS.

- [ ] **Step 4: Commit any final adjustments**

```bash
git add .
git commit -m "chore: verify listing analysis entry channels"
```

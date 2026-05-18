# Yeni Sistem Isimlendirme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eski `yerimebak_ai_test` ve `expertiz_sistemi` izlerini yeni `yerimebak_sistemleri` catısı altında teknik ve gorunen isimlerde standart hale getirmek.

**Architecture:** Klasor yapisi zaten `yerimebak_sistemleri/musteri_paneli` ve `yerimebak_sistemleri/expertiz_paneli` olarak ayrildi. Bu plan Flutter paket/import adlarini, platform uygulama adlarini, backend kaynak etiketini ve dokuman basliklarini gunceller; Docker veri volume adlari mevcut DB verisini korumak icin eski isimlerde kalir.

**Tech Stack:** Flutter/Dart, FastAPI/Python, Docker Compose, Markdown docs.

---

### Task 1: Flutter Teknik Paket Adini Degistir

**Files:**
- Modify: `expertiz_paneli/pubspec.yaml`
- Modify: `expertiz_paneli/lib/**/*.dart`
- Modify: `expertiz_paneli/test/**/*.dart`

- [ ] **Step 1: Replace package identity**

Change `name: expertiz_sistemi` to `name: yerimebak_sistemleri`.

- [ ] **Step 2: Replace Dart imports**

Replace every `package:expertiz_sistemi/` import with `package:yerimebak_sistemleri/`.

- [ ] **Step 3: Verify analyzer**

Run: `flutter analyze lib test`
Expected: `No issues found!`

### Task 2: Platform Uygulama Adlarini Degistir

**Files:**
- Modify: `expertiz_paneli/android/app/build.gradle.kts`
- Modify: `expertiz_paneli/android/app/src/main/AndroidManifest.xml`
- Modify: `expertiz_paneli/android/app/src/main/kotlin/.../MainActivity.kt`
- Modify: `expertiz_paneli/ios/Runner/Info.plist`
- Modify: `expertiz_paneli/web/manifest.json`
- Modify: `expertiz_paneli/linux/**`
- Modify: `expertiz_paneli/windows/**`
- Modify: `expertiz_paneli/macos/**`

- [ ] **Step 1: Use new technical id**

Replace `expertiz_sistemi` with `yerimebak_sistemleri` in build/product names.

- [ ] **Step 2: Use new visible app name**

Replace `Expertiz Sistemi` and `YerimeBak Expertiz Sistemi` visible product labels with `YerimeBak Sistemleri`.

- [ ] **Step 3: Keep Android package path compilable**

If Android namespace changes to `com.example.yerimebak_sistemleri`, move `MainActivity.kt` into the matching folder path and update the package declaration.

### Task 3: Backend ve Dokuman Kaynak Etiketlerini Degistir

**Files:**
- Modify: `musteri_paneli/yerimebak_ai_v5/services/expertiz_service.py`
- Modify: `musteri_paneli/docs/**/*.md`
- Modify: `expertiz_paneli/docs/**/*.md`
- Modify: `expertiz_paneli/plans/**/*.md`
- Modify: `expertiz_paneli/README.md`
- Modify: `README.md`

- [ ] **Step 1: Backend source tag**

Change `"source": "yerimebak_ai_test"` to `"source": "yerimebak_sistemleri"`.

- [ ] **Step 2: Docs wording**

Replace legacy project names in live documentation with the new system name. Archive docs can be updated when the old path/name appears as current truth.

- [ ] **Step 3: Preserve DB volume names**

Do not rename `yerimebak_ai_test_postgres_data`, `yerimebak_ai_test_redis_data`, `yerimebak_ai_test_app_data`, or `yerimebak_ai_test_worker_data` in `docker-compose.yml`.

### Task 4: Verification and Commits

**Files:**
- Verify customer repo: `musteri_paneli`
- Verify expertiz repo: `expertiz_paneli`

- [ ] **Step 1: Customer backend checks**

Run: `python -m py_compile yerimebak_ai_v5/services/expertiz_service.py`
Expected: exit code 0.

- [ ] **Step 2: Customer unit tests**

Run: `python -m unittest tests.unit.test_scraper_backfill_planner tests.unit.test_scraper_worker_backfill tests.unit.test_market_coverage_service tests.unit.test_market_coverage_api -v`
Expected: `Ran 9 tests ... OK`.

- [ ] **Step 3: Flutter checks**

Run: `flutter analyze lib test`
Expected: `No issues found!`

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit per repo**

Commit customer repo changes with `chore: rename customer system references`.
Commit expertiz repo changes with `chore: rename expertiz app to yerimebak sistemleri`.

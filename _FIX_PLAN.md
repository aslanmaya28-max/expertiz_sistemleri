# KRİTİK HATA DÜZELTME PLANI — 13/13

## Sıralama Stratejisi (Bağımlılıklara Göre)

### FASE 1: SQL Şema & Migration Fix'leri (Bug 1-7, 12)
Önce veritabanı şeması düzeltilmeli, çünkü diğer katmanlar buna bağımlı.

- [x] Bug 1  — evidence_rpc_functions.sql: raporlar → reports, musteri_id → user_id
- [x] Bug 2  — evidence_rpc_functions.sql: Aynı fix get_evidence_summary_stats içinde
- [x] Bug 3  — evidence_rpc_functions.sql: reasoning TEXT → JSONB cast
- [x] Bug 4  — status_workflow.sql: audit_logs INSERT şema uyumu
- [x] Bug 5  — status_workflow.sql: Role kontrolü field_staff ile uyumlu
- [x] Bug 6  — status_workflow.sql: NULL UUID FK referansı handling
- [x] Bug 7  — status_workflow.sql: customer_reports → reports RLS fix
- [x] Bug 12 — status_workflow.sql: reports.customer_id → user_id

### FASE 2: Python Service Fix'leri (Bug 8, 9, 11, 13)
Sonra Python kodlarındaki hatalar.

- [x] Bug 8  — auth_service.py: finally: pass → return_connection()
- [x] Bug 9  — database_config.py: autocommit=False + reset in pool return
- [x] Bug 11 — expertiz_service.py: datetime.utcnow() → datetime.now(timezone.utc)
- [x] Bug 13 — personnel_service.py: UUID vs SERIAL tip uyumsuzluğu

### FASE 3: Konfigürasyon Fix'leri (Bug 10)
- [x] Bug 10 — .gitignore: node_modules/ ekle

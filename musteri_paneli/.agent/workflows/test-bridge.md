---
description: Forensic Pipeline ve Entegrasyon Köprüsü testi.
---

Bu iş akışı, AI Orchestrator ve Digital Notary sistemini test eder.

1. Entegrasyon köprüsü testini çalıştırın:
// turbo
```powershell
python yerimebak_ai_v5/core/integration_bridge.py
```

2. Çıktıda "Evidence Package ... Vaulted" mesajını ve JSON çıktısını kontrol edin.
3. Vault dizinindeki yeni kayıtları doğrulayın:
```powershell
ls yerimebak_ai_v5/data/vault/
```

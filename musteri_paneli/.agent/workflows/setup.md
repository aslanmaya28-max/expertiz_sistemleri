---
description: Projeyi ilk çalışmaya hazır hale getirmek için gerekli kurulum adımları.
---

Bu iş akışı, projenin bağımlılıklarını yükler ve ortamı hazırlar.

1. Sanal ortam oluşturun (eğer yoksa):
```powershell
python -m venv venv
```

2. Sanal ortamı aktif edin:
```powershell
.\venv\Scripts\Activate.ps1
```

3. Bağımlılıkları yükleyin:
// turbo
```powershell
pip install -r requirements.txt
# Requirements.txt içerisinde fastapi ve uvicorn bulunmaktadır.
```

4. Veri dizinlerinin varlığını kontrol edin:
```powershell
mkdir -p yerimebak_ai_v5/data/vault
```

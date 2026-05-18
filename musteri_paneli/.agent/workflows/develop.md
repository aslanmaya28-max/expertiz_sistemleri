---
description: SaaS Dashboard ve Live Server'ı başlatma iş akışı.
---

Bu iş akışı, Flask tabanlı canlı sunucuyu başlatır.

1. Ana dizinde olduğunuzdan emin olun.
2. Sunucuyu başlatın:
// turbo
```powershell
python yerimebak_ai_v5/main.py
```
Veya:
```powershell
uvicorn yerimebak_ai_v5.main:app --reload
```

3. Tarayıcıdan şu adrese gidin:
`http://127.0.0.1:8000`

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Path setup
BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

def test_model(model_name, api_key, provider="OPENROUTER"):
    if not api_key:
        return False, "API Key bulunamadı."
    
    import openai
    base_url = "https://openrouter.ai/api/v1"
    
    try:
        client = openai.OpenAI(
            api_key=api_key,
            base_url=base_url
        )
        response = client.chat.completions.create(
            model=model_name,
            messages=[{"role": "user", "content": "Test. Sadece 'BAŞARILI' yaz."}],
            max_tokens=10
        )
        content = response.choices[0].message.content
        if content:
            return True, f"✅ {model_name} aktif! Yanıt: {content.strip()}"
        return False, f"⚠️ {model_name} boş yanıt döndürdü."
    except Exception as e:
        return False, f"❌ {model_name} hatası: {str(e)}"

if __name__ == "__main__":
    print("🛡️  YERİMEBAK AI - ÜÇLÜ MOTOR DOĞRULAMA")
    print("======================================")
    
    or_key = os.getenv("OPENROUTER_API_KEY")

    import openai
    print("📋 Erişilebilir OpenRouter Modelleri (Free):")
    try:
        client = openai.OpenAI(api_key=or_key, base_url="https://openrouter.ai/api/v1")
        available = client.models.list()
        count = 0
        for m in available.data:
            if ":free" in m.id or "free" in m.id.lower():
                print(f" - {m.id}")
                count += 1
            if count >= 10: break
    except Exception as le:
        print(f" - Modeller listelenemedi: {le}")
    
    # Primary
    p_model = os.getenv("PRIMARY_MODEL", "google/gemma-3-27b-it:free")
    print(f"\n1. PRIMARY ENGINE ({p_model})")
    p_ok, p_msg = test_model(p_model, or_key)
    print(p_msg)
    
    # Secondary
    s_model = os.getenv("SECONDARY_MODEL", "stepfun/step-3.5-flash:free")
    print(f"\n2. SECONDARY ENGINE ({s_model})")
    s_ok, s_msg = test_model(s_model, or_key)
    print(s_msg)
    
    # Fallback
    f_model = os.getenv("FALLBACK_MODEL", "qwen/qwen3-next-80b-a3b-instruct:free")
    print(f"\n3. FALLBACK ENGINE ({f_model})")
    f_ok, f_msg = test_model(f_model, or_key)
    print(f_msg)
    
    print("\n" + "="*40)
    if p_ok and s_ok and f_ok:
        print("✨ TÜM SİSTEMLER (1. 2. ve 3.) HAZIR!")
    elif p_ok or s_ok or f_ok:
        active_motors = [m for ok, m in [(p_ok, "Primary"), (s_ok, "Secondary"), (f_ok, "Fallback")] if ok]
        print(f"✅ SİSTEM ÇALIŞIR (Aktif motorlar: {', '.join(active_motors)})")
        print("💡 AnalizServisi otomatik failover ile çalışan motora geçiş yapacaktır.")
    else:
        print("❌ KRİTİK HATA: Hiçbir AI motoruna erişilemiyor!")

"""039: kullanıcı mesajlarında ASCII Türkçe yazımına dönüşü yakalayan kaynak denetimi.

İstisnalar bağlamla sınırlıdır: yorum/docstring, logger/print, SQL, JSON anahtarı,
hata kodu ve f-string ifadeleri mesaj sayılmaz. Bunlar kullanıcı metni değildir;
makine sözleşmesi ve kalıcı değerler değiştirilmemelidir. Yapay zekâ istemleri,
main.py açılış kilidi ve zaten düzeltilmiş e-posta konuları bu taramanın dışındadır.
"""
import ast
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2] / "yerimebak_ai_v5"
FILES = (
    "api/v1/endpoints/analysis.py", "api/v1/endpoints/auth.py", "api/v1/endpoints/expertiz.py",
    "services/account_service.py", "services/auth_service.py", "services/checkout_service.py",
    "services/customer_service.py", "services/dispatch_service.py", "services/expertiz_service.py",
    "services/invoice_export.py", "services/media_service.py", "services/payment_service.py",
    "services/paytr_service.py", "services/personnel_service.py", "services/pricing_service.py",
    "services/refund_service.py",
)
ASCII_TURKCE = re.compile(
    r"\b(?:gecersiz|gecerli|bulunamadi|basarili|basarisiz|kullanici\w*|islem|sifre\w*|"
    r"odeme\w*|gonder\w*|olustur\w*|degil|dogrula\w*|lutfen|musteri\w*|gorev|"
    r"siparis|henuz|yayinlan\w*|kayitli\w*|kaydi|yuklen\w*|yukleyin|baglanti\w*|"
    r"icermelidir|iceriyor|icerebilir|icindir|icin|suresi|surecindeki|dolmus|"
    r"olmalidir|olmali|gecici|buyuk|kucuk|hatali|farkli|onaylanmalidir|"
    r"kosullari|kullanim|aydinlatma|hesabiniz\w*|hesabi|devre disi|birakilmis|"
    r"yapilandirma\w*|tanimlanmamis|artik|secimi|secilen|secin|ilce|aracin|"
    r"arac|bulundugu|paylasin|simulasyonu|kapali|su an|atanmis|atanmamis|"
    r"atamasi|kaldirilamaz|guncellenemez|adima|gecemez|degistir\w*|bolum|bos|"
    r"fotograf|fotografi|numarasi|baska|kullanicida|sayfasi|baslatilamadi|"
    r"ulasilamadi|yapilamadi|yapilamaz|tamamlanmis|tamamlanamadi|edilmis|"
    r"kismi|kullanilmis|kapanmis|guncellenecek|adi|fiyati|sayi|araliginda|"
    r"orani|aylik|arasinda|yalnizca|degeri|deger|degerleme|duzeltilebilir|"
    r"hesaplanamadi|degisti|onayi|resmi rapor|hatasi|secenekler|cok|acik|altyapisi)\b",
)
# re.IGNORECASE, Python'da i/ı/İ'yi eşler: doğru "bulunamadı" da hatalı görünürdü.
# Yalnız ASCII büyük harfleri küçültür, Türkçe harfleri ve sözcük sınırlarını koruruz.
ASCII_KUCUK = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz")


def _parcalar(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        yield node.lineno, node.value
    elif isinstance(node, ast.JoinedStr):
        for value in node.values:
            if isinstance(value, ast.Constant):
                yield from _parcalar(value)
            # FormattedValue içindeki alan/kod/hesaplama bir metin sabiti değildir.
    elif isinstance(node, (ast.BoolOp, ast.BinOp)):
        for value in ast.iter_child_nodes(node):
            yield from _parcalar(value)


def _mesajlar(source):
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            name = node.func.id if isinstance(node.func, ast.Name) else ""
            if name in {"_error", "_hata", "ValueError", "PaytrError", "HTTPException"}:
                args = node.args[1:2] if name == "HTTPException" else node.args[:1]
                for arg in args:
                    yield from _parcalar(arg)
                for keyword in node.keywords:
                    if keyword.arg == "detail":
                        yield from _parcalar(keyword.value)
        elif isinstance(node, ast.Dict):
            for key, value in zip(node.keys, node.values):
                if isinstance(key, ast.Constant) and key.value in {"error", "message", "aciklama"}:
                    yield from _parcalar(value)
        elif isinstance(node, ast.FunctionDef) and node.name == "_validate_password_strength":
            for child in ast.walk(node):
                if isinstance(child, ast.Return):
                    yield from _parcalar(child.value)
        elif isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "bonus" for t in node.targets):
            for child in ast.walk(node.value):
                if isinstance(child, ast.JoinedStr):
                    yield from _parcalar(child)


def _hatalar(source):
    return [(line, text) for line, text in _mesajlar(source)
            if ASCII_TURKCE.search(text.translate(ASCII_KUCUK))
            or re.search(r"\b(?:Iptal|Iade|Il)\b", text)]


@pytest.mark.parametrize("filename", FILES)
def test_kullanici_mesajlarinda_ascii_turkce_yok(filename):
    errors = _hatalar((ROOT / filename).read_text(encoding="utf-8-sig"))
    assert not errors, "\n".join(f"{filename}:{line}: {text}" for line, text in errors)


def test_tarama_log_kod_sql_ve_fstring_alanini_degistirmez():
    source = '''
# Gecersiz sifre
logger.warning("Gecersiz sifre")
sql = "SELECT kullanici FROM users"
result = {"code": "bulunamadi", "error": "Geçersiz şifre; kullanıcı bulunamadı, aracın kaydı boş"}
result = {"error": f"Geçersiz alan: {data['kullanici']}"}
result = {"error": "Resmi yükleyin"}  # resim sözcüğünün belirtme hâli doğrudur.
'''
    assert _hatalar(source) == []


def test_tarama_birlesik_dogrulama_ve_hata_metinlerini_yakalar():
    source = '''
raise ValueError("Gecersiz e-posta")
return_value = {"message": f"Kayit basarili. {count} kredi"}
_error("Sifre " "gecersiz", 400, "kod_degismez")
'''
    assert [text for _, text in _hatalar(source)] == ["Gecersiz e-posta", "Kayit basarili. ", "Sifre gecersiz"]

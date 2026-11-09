# Yerinde ekspertiz — sunucu sözleşmesi (Claude, 9 Kasım 2026)

036 (müşteri formları) ve 037 (yönetim/saha paneli) bu sözleşmeye göre yazılır. Uç noktaları Claude sunucuda yazar
(`degerleme-web-kaynak`). Alan adları değişirse bu dosya güncellenir ve köprüden bildirilir.

## Kararlar (kullanıcı)
- Hizmet 81 ilde açılabilir; **pilot il İstanbul**. Testler başka illerden de yapılabilmeli.
- Her il için durum: `acik` (herkes), `test` (yalnız yönetici ve test kullanıcısı), `kapali`.
- Kurumsal firma modeli: aracı müşterinin seçtiği anlaşmalı firmanın personeli inceler. Randevuyu **müşteri** satıcıyla
  ayarlar; firma görev öncesi satıcıyı arar.
- Araç yerinde bulunamazsa: hizmet bedeli iade edilmez (ödeme öncesi ayrı onay), **firma paket ücreti iade edilir**,
  firma %25 saha payını alır.

## 1. Hizmet bölgesi
`GET /api/v1/expertiz/service-area` (herkese açık; `Authorization` varsa kullanıcıya göre hesaplar)
```json
{
  "pilot": "İstanbul",
  "tester": false,
  "cities": [
    {"il": "İstanbul", "durum": "acik", "talep_acabilir": true},
    {"il": "Ankara",   "durum": "test", "talep_acabilir": false},
    {"il": "Adana",    "durum": "kapali", "talep_acabilir": false}
  ]
}
```
- `cities` 81 ilin tamamı, alfabetik (Türkçe). `talep_acabilir` sunucuda hesaplanır; istemci kendi kuralı yazmaz.
- Genel ayar `APP_EXPERTIZ_ENABLED=false` iken yalnız yönetici/test kullanıcısı için `talep_acabilir` true olabilir.

Yönetim: `GET /api/v1/expertiz/admin/service-area` → aynı biçim + `guncellenme`;
`PUT /api/v1/expertiz/admin/service-area` gövde `{"cities": [{"il": "Ankara", "durum": "test"}]}` (yalnız gönderilen
iller değişir; geçersiz il/durum 422).

Test kullanıcısı: `POST /api/v1/expertiz/admin/customers/{customer_id}/tester` gövde `{"tester": true}` →
`{"success": true, "tester": true}`. Müşteri listesi/detayı `tester` alanını döner.

## 2. Talep (ödeme başlatma) — yeni alanlar
`POST /api/v1/expertiz/requests` (ödemeli talep; PayTR) gövdesine eklenir:
| Alan | Tür | Kural |
|---|---|---|
| `appointment_at` | string, yerel tarih-saat `YYYY-MM-DDTHH:MM` (İstanbul saati) | zorunlu; en erken şimdi + 2 saat, en geç 30 gün |
| `address` | string | zorunlu, 10–300 karakter (açık adres / buluşma noktası) |
| `seller_name` | string | isteğe bağlı, ≤ 80 |
| `seller_phone` | string | zorunlu; Türkiye cep/sabit, rakamlar 10–11 hane (`05xx…`, `+90…` kabul) |
| `not_found_accepted` | bool | zorunlu `true`: "Araç belirtilen adreste bulunamazsa hizmet bedeli iade edilmez; kurumsal ekspertiz paket ücreti iade edilir." |
| `city` | string | 81 ilden biri; o il için `talep_acabilir` değilse **422** `{"code": "il_kapali"}` |
Hata biçimi mevcut: `{"detail": {"message": "...", "code": "..."}}`. Kodlar: `il_kapali`, `randevu_gecersiz`,
`adres_eksik`, `satici_telefon_gecersiz`, `bulunamama_onayi_gerekli`.

Bu alanlar talep kaydında `talep.randevu` = `{"tarih_saat", "adres", "satici_adi", "satici_telefon"}` ve
`talep.bulunamama_onayi = true` olarak saklanır; müşteri talep listesi, yönetim talep detayı ve saha görevi bunları döner
(`randevu` nesnesi). Satıcı telefonu yalnız yönetici ve atanan saha personeline gider; müşteri listesinde maskelenmez
(müşteri kendisi girdi).

## 3. Firma modeli
- Personel kaydı `firm_id` taşır (`POST/PUT` personel gövdesinde, `GET` yanıtında `firm_id`, `firm_name`).
- `GET /admin/requests/{id}/candidates`: talepte firma varsa o firmanın personeli **en üstte**, ardından firmasız
  personel (YerimeBak koordinatörü); **başka firmanın personeli listelenmez**. Yanıtta `firm_id`; her adayda `firm_id`,
  `firm_name`. `assign` başka firmanın personeline 409 `firma_uyusmuyor`; firmasız personele izin verilir.
- Finans özeti hak edişi firma bazında da döner: `firmalar: [{firm_id, firm_name, is_sayisi, hakedis_tl}]`.

## 4. Araç yerinde bulunamadı
Saha: `POST /api/v1/expertiz/personnel/tasks/{id}/not-found` gövde `{"note": "..."}` (zorunlu, ≥ 10 karakter) →
görev `vehicle_not_found` durumuna geçer, yöneticiye bildirim.
Yönetim: `POST /api/v1/expertiz/admin/requests/{id}/not-found-refund` gövde `{"reason": "..."}` →
`{"success": true, "refund_tl": <paket ücreti>, "kept_tl": <hizmet bedeli + KDV>, "status": "cancelled"}`;
PayTR kısmi iade (paket ücreti). Firma payı tahakkuk eder. Müşteriye bildirim + e-posta.
Talep detayında `durum_kodu` yeni değer: `vehicle_not_found`.

## 5. Ödemesiz talep yalnız test için
`POST /api/v1/expertiz/requests/unpaid` artık yalnız **yönetici ve test kullanıcısına** açık (diğerlerine 403
`odemesiz_talep_yetkisi_yok`). Müşteri sitede de uygulamada da `POST /api/v1/expertiz/requests` ile PayTR ödemesine gider.
Site formu: `service-area` yanıtındaki `tester` true ise "Ödemesiz test talebi" seçeneği gösterilebilir; değilse
yalnız ödemeli akış. Aynı yeni alanlar (bölüm 2) ödemesiz talepte de zorunlu.

## 6. (kaldırıldı) — yerine bölüm 7

## 7. Kontrol merkezi (kullanıcı kararı, 9 Kasım 2026)
Saha personeli müşteriye ya da satıcıya **doğrudan bağlanmaz**; yalnız kontrol merkezine bağlanır. Müşteri ve satıcıyla
bağlantıyı kontrol merkezi kurar. Firmasız (YerimeBak) personel de olur; bölüm 3 kuralı geçerli.
- Personel uçları (`/personnel/tasks`, adımlar, `/report`, `/submit`): `customer` yalnız `{"name": "Ayse M."}`;
  `randevu` içinde `satici_telefon` **yok**. Liste yanıtında `kontrol_merkezi` = `{"telefon","calisma_saatleri","tanimli"}`.
- `POST /personnel/tasks/{id}/control-note` `{"note"}` → kontrol merkezine not (yöneticilere bildirim).
- `GET /control-center` (oturum açık herkes) → `{"telefon","calisma_saatleri","tanimli"}`.
- `PUT /admin/control-center` `{"telefon","calisma_saatleri"}` (422 `telefon_gecersiz`).
- `GET /admin/control-center/tasks` → `{"ayarlar", "gorevler": [<yönetici talep görünümü> + "son_iletisim"]}`;
  açık görevler randevu saatine göre (randevusuz olanlar sonda). Numaralar burada: `customer.phone`,
  `randevu.satici_telefon`, `assignment.personnel_phone`.
- `GET|POST /admin/requests/{id}/contact-log`: kayıt `{"hedef": musteri|satici|personel, "sonuc":
  ulasildi|ulasilamadi|mesaj_birakildi|baglandi, "note"}`; liste `kayitlar` (personel notları `hedef=kontrol_merkezi`,
  `sonuc=not`).

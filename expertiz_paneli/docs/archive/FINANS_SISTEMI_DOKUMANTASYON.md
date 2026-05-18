# Merkezi Finans Sistemi - Dokümantasyon

Bu dokümantasyon, Uzmanlık Sistemi'ne eklenen yeni Merkezi Finans Sistemi'nin kullanımını ve entegrasyonunu açıklar.

## 📋 İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Sistem Bileşenleri](#sistem-bileşenleri)
3. [Veri Modelleri](#veri-modelleri)
4. [Finans Servisi](#finans-servisi)
5. [Müşteri Ödeme Süreci](#müşteri-ödeme-süreci)
6. [Admin Finans Dashboard](#admin-finans-dashboard)
7. [Entegrasyon Adımları](#entegrasyon-adımları)
8. [Test Rehberi](#test-rehberi)
9. [API Referansı](#api-referansı)

---

## 🎯 Genel Bakış

Merkezi Finans Sistemi, müşteri ödemelerini, personel hakedişlerini ve finansal raporlamayı yöneten kapsamlı bir çözümdür.

### Temel Özellikler

- ✅ Müşteri ödeme takibi (Mock ödeme sistemi)
- ✅ Otomatik %25 personel komisyonu hesaplama
- ✅ Personel hakediş yönetimi
- ✅ Finansal dashboard ve raporlama
- ✅ Ödeme durumu görselleştirmesi
- ✅ Rapor kilidi sistemi (isPaid)

---

## 🏗️ Sistem Bileşenleri

### 1. Backend & Model
- **Dosya**: `lib/models/finance/finance_model.dart`
- **Modeller**:
  - `Odeme`: Müşteri ödemelerini takip eder
  - `PersonelHakedis`: Personel komisyonlarını yönetir

### 2. Finans Servisi
- **Dosya**: `lib/services/finance_service.dart`
- **Fonksiyonlar**:
  - Ödeme işlemleri
  - Hakediş yönetimi
  - Finansal raporlama
  - Veri kalıcılığı (SharedPreferences)

### 3. Müşteri Paneli
- **Dosya**: `lib/screens/musteri_odeme_sayfasi.dart`
- **Özellikler**:
  - Ödeme formu
  - Ödeme yöntemi seçimi
  - Mock ödeme işlemi
  - Başarılı ödeme ekranı

### 4. Admin Dashboard
- **Dosya**: `lib/screens/admin_finans_dashboard.dart`
- **Özellikler**:
  - Finansal özet kartları
  - Son ödemeler listesi
  - Personel hakedişleri
  - Ödeme yöntemi dağılımı

### 5. Rapor Entegrasyonu
- **Dosya**: `lib/models/arac_rapor_model.dart`
- **Değişiklikler**:
  - `isPaid` alanı eklendi
  - Ödeme durumu getter'ları eklendi
  - Görsel göstergeler eklendi

---

## 📊 Veri Modelleri

### Odeme Modeli

```dart
class Odeme {
  final String id;
  final double amount;              // Ödeme tutarı
  final String customerID;          // Müşteri ID
  final String staffID;            // Personel ID
  final String reportID;           // Rapor ID
  final double commission;         // Komisyon oranı (%25)
  final String status;             // 'Paid', 'Pending'
  final DateTime olusturmaTarihi;
  final DateTime? odemeTarihi;
  final String odemeYontemi;      // 'kredi_karti', 'havale', 'nakit'
  final String? referansNo;
}
```

**Önemli Getter'lar:**
- `isPaid`: Ödendi mi?
- `komisyonTutari`: Komisyon tutarı (amount * 0.25)
- `netTutar`: Net tutar (amount - komisyon)
- `formatliTutar`: Formatlı tutar string'i

### PersonelHakedis Modeli

```dart
class PersonelHakedis {
  final String id;
  final String personelID;
  final String odemeID;
  final String reportID;
  final double hakedisTutari;
  final DateTime kazanimTarihi;
  final String? odemeTarihi;
  final String durum;             // 'bekleniyor', 'odendi', 'iptal'
}
```

---

## 🔧 Finans Servisi

### Temel Fonksiyonlar

#### 1. Müşteri Ödeme İşlemi

```dart
final odeme = await FinanceService.musteriOdemeYap(
  customerID: 'musteri_123',
  staffID: 'personel_456',
  reportID: 'rapor_789',
  amount: 6500.0,
  odemeYontemi: 'kredi_karti',
);
```

**Bu fonksiyon şunları yapar:**
1. Mock ödeme işlemi gerçekleştirir (2 saniye)
2. Ödeme kaydı oluşturur
3. Personel hakedişi hesaplar (%25)
4. Hakediş kaydı oluşturur
5. `Odeme` nesnesi döndürür

#### 2. Finansal Özet Alma

```dart
final ozet = await FinanceService.getFinansalOzet();
print('Toplam Ciro: ${ozet['toplamCiro']}');
print('Net Gelir: ${ozet['netGelir']}');
print('Hakediş Borcu: ${ozet['toplamHakedisBorcu']}');
```

**Dönen Değerler:**
- `toplamCiro`: Toplam ödenen tutar
- `toplamKomisyon`: Toplam komisyon tutarı
- `netGelir`: Ciro - Komisyon
- `toplamHakedisBorcu`: Bekleyen hakedişler
- `odenenHakedisler`: Ödenen hakedişler
- `toplamOdemeSayisi`: Toplam ödeme sayısı
- `bekleyenOdemeSayisi`: Bekleyen ödeme sayısı

#### 3. Rapor Ödeme Durumu Kontrolü

```dart
bool odendiMi = await FinanceService.raporOdendiMi('rapor_789');
```

#### 4. Personel Hakedişlerini Getir

```dart
final hakedisler = await FinanceService.getPersonelHakedisleri('personel_456');
```

---

## 💳 Müşteri Ödeme Süreci

### Adım 1: Ödeme Sayfasına Git

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => MusteriOdemeSayfasi(
      rapor: aracRapor,
      customerID: 'musteri_123',
      staffID: 'personel_456',
      onOdemeBasarili: () {
        // Ödeme başarılı olduğunda yapılacaklar
        setState(() {
          rapor.isPaid = true;
        });
      },
    ),
  ),
);
```

### Adım 2: Ödeme Formu

Müşteri şunları görür:
- Rapor bilgileri (araç, plaka, paket)
- Ödeme özeti (hizmet bedeli, komisyon, toplam)
- Ödeme yöntemi seçimi (Kredi Kartı, Havale, Nakit)
- Güvenlik notu
- Ödeme butonu

### Adım 3: Ödeme İşlemi

1. Müşteri "Öde" butonuna basar
2. Mock ödeme işlemi başlar (2 saniye)
3. Ödeme kaydı oluşturulur
4. Personel hakedişi otomatik hesaplanır
5. Başarılı ödeme ekranı gösterilir

### Adım 4: Ödeme Sonrası

- Raporun `isPaid` durumu `true` olur
- Rapor kilidi açılır
- PDF indirme butonu aktif olur
- Personel hakedişi bekleyen hakedişlere eklenir

---

## 📈 Admin Finans Dashboard

### Özellikler

#### 1. Finansal Özet Kartları

- **Toplam Ciro**: Tüm ödemelerin toplamı
- **Net Gelir**: Ciro - Komisyon
- **Komisyon**: Toplam komisyon tutarı (%25)
- **Hakediş Borcu**: Personellere ödenmesi gereken tutar

#### 2. İstatistikler

- Toplam ödeme sayısı
- Bekleyen ödeme sayısı
- Ödenen hakedişler
- Bekleyen hakedişler

#### 3. Son Ödemeler

Son 5 ödemenin listesi:
- Ödeme tutarı
- Tarih
- Durum (Ödendi/Beklemede)

#### 4. Personel Hakedişleri

Personel bazlı hakediş özeti:
- Personel ID
- Bekleyen hakediş tutarı

#### 5. Ödeme Yöntemi Dağılımı

- Kredi Kartı
- Havale/EFT
- Nakit
- Yüzde dağılımı

### Dashboard'a Erişim

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const AdminFinansDashboard(),
  ),
);
```

---

## 🔗 Entegrasyon Adımları

### 1. Rapor Modelini Güncelle

Rapor modelinize `isPaid` alanını ekleyin:

```dart
class AracRapor {
  // ... diğer alanlar
  final bool isPaid;
  
  AracRapor({
    // ... diğer parametreler
    this.isPaid = false,
  });
  
  // Getter'lar
  String get odemeDurumu => isPaid ? 'Ödendi' : 'Ödenmedi';
  Color get odemeDurumuRengi => isPaid ? Colors.green : Colors.red;
  IconData get odemeDurumuIkonu => isPaid ? Icons.check_circle : Icons.payment;
}
```

### 2. Rapor Listesine Ödeme Durumu Ekle

Rapor kartlarında ödeme durumunu gösterin:

```dart
Widget _raporKarti(AracRapor rapor) {
  return Card(
    child: ListTile(
      leading: Stack(
        children: [
          _raporIkon(rapor.raporTipi),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              rapor.odemeDurumuIkonu,
              size: 16,
              color: rapor.odemeDurumuRengi,
            ),
          ),
        ],
      ),
      title: Text('${rapor.marka} ${rapor.model}'),
      trailing: Chip(
        label: Text(rapor.odemeDurumu),
        backgroundColor: rapor.odemeDurumuRengi.withOpacity(0.1),
      ),
    ),
  );
}
```

### 3. Ödeme Butonu Ekle

Ödenmemiş raporlar için ödeme butonu ekleyin:

```dart
if (!rapor.isPaid) {
  ElevatedButton(
    onPressed: () => _odemeYap(rapor),
    child: Text('Ödeme Yap'),
  );
}
```

### 4. PDF İndirme Kontrolü

PDF indirme butonunu sadece ödenmiş raporlar için gösterin:

```dart
if (rapor.isPaid && rapor.durum == 'Onaylandı') {
  ElevatedButton(
    onPressed: () => _pdfIndir(rapor),
    child: Text('PDF İndir'),
  );
}
```

---

## 🧪 Test Rehberi

### Test Senaryoları

#### 1. Müşteri Ödeme Testi

```dart
// Test: Ödeme işlemi
test('Müşteri ödemesi başarılı olmalı', () async {
  final odeme = await FinanceService.musteriOdemeYap(
    customerID: 'test_musteri',
    staffID: 'test_personel',
    reportID: 'test_rapor',
    amount: 6500.0,
    odemeYontemi: 'kredi_karti',
  );
  
  expect(odeme, isNotNull);
  expect(odeme!.status, 'Paid');
  expect(odeme.amount, 6500.0);
  expect(odeme.komisyonTutari, 1625.0); // 6500 * 0.25
});
```

#### 2. Komisyon Hesaplama Testi

```dart
test('Komisyon doğru hesaplanmalı', () {
  final odeme = Odeme(
    id: 'test',
    amount: 10000.0,
    customerID: 'test',
    staffID: 'test',
    reportID: 'test',
    commission: 25.0,
    status: 'Pending',
    olusturmaTarihi: DateTime.now(),
    odemeYontemi: 'kredi_karti',
  );
  
  expect(odeme.komisyonTutari, 2500.0);
  expect(odeme.netTutar, 7500.0);
});
```

#### 3. Hakediş Oluşturma Testi

```dart
test('Ödeme sonrası hakediş oluşturulmalı', () async {
  await FinanceService.musteriOdemeYap(
    customerID: 'test_musteri',
    staffID: 'test_personel',
    reportID: 'test_rapor',
    amount: 6500.0,
    odemeYontemi: 'kredi_karti',
  );
  
  final hakedisler = await FinanceService.getPersonelHakedisleri('test_personel');
  expect(hakedisler.length, 1);
  expect(hakedisler[0].hakedisTutari, 1625.0);
});
```

### Manuel Test Adımları

1. **Müşteri Ödeme Testi**
   - Raporlarım sayfasına gidin
   - Ödenmemiş bir rapora tıklayın
   - "Ödeme Yap" butonuna basın
   - Ödeme formunu doldurun
   - Ödemeyi tamamlayın
   - Raporun ödendiğini doğrulayın

2. **Admin Dashboard Testi**
   - Admin paneline gidin
   - Finans Dashboard'a tıklayın
   - Finansal özet kartlarını kontrol edin
   - Son ödemeler listesini inceleyin
   - Personel hakedişlerini kontrol edin

3. **Rapor Kilidi Testi**
   - Ödenmemiş bir rapor oluşturun
   - PDF indirme butonunun pasif olduğunu doğrulayın
   - Ödeme yapın
   - PDF indirme butonunun aktif olduğunu doğrulayın

---

## 📚 API Referansı

### FinanceService

#### Ödeme İşlemleri

| Fonksiyon | Parametreler | Dönen Değer | Açıklama |
|-----------|-------------|-------------|-----------|
| `musteriOdemeYap` | customerID, staffID, reportID, amount, odemeYontemi | `Future<Odeme?>` | Müşteri ödemesi yapar |
| `odemeEkle` | `Odeme` | `Future<bool>` | Ödeme kaydı ekler |
| `odemeGuncelle` | `Odeme` | `Future<bool>` | Ödeme günceller |
| `getOdemeler` | - | `Future<List<Odeme>>` | Tüm ödemeleri getirir |
| `getMusteriOdemeleri` | customerID | `Future<List<Odeme>>` | Müşteri ödemelerini getirir |

#### Hakediş İşlemleri

| Fonksiyon | Parametreler | Dönen Değer | Açıklama |
|-----------|-------------|-------------|-----------|
| `hakedisEkle` | `PersonelHakedis` | `Future<bool>` | Hakediş ekler |
| `getHakedisler` | - | `Future<List<PersonelHakedis>>` | Tüm hakedişleri getirir |
| `getPersonelHakedisleri` | personelID | `Future<List<PersonelHakedis>>` | Personel hakedişlerini getirir |
| `personelHakedisiOde` | hakedisID | `Future<bool>` | Hakedişi öder |

#### Raporlama

| Fonksiyon | Parametreler | Dönen Değer | Açıklama |
|-----------|-------------|-------------|-----------|
| `getFinansalOzet` | - | `Future<Map<String, dynamic>>` | Finansal özet getirir |
| `getToplamCiro` | - | `Future<double>` | Toplam ciroyu hesaplar |
| `getToplamHakedisBorcu` | - | `Future<double>` | Hakediş borcunu hesaplar |
| `raporOdendiMi` | reportID | `Future<bool>` | Rapor ödendi mi kontrol eder |

---

## 🎨 Görsel Göstergeler

### Ödeme Durumu Renkleri

| Durum | Renk | İkon |
|-------|------|------|
| Ödendi | Yeşil | `Icons.check_circle` |
| Ödenmedi | Kırmızı | `Icons.payment` |
| Beklemede | Turuncu | `Icons.pending` |

### Rapor Durumu Renkleri

| Durum | Renk |
|-------|------|
| OdemeBekliyor | Turuncu |
| Islemde | Mavi |
| Tamamlandi | Yeşil |
| Iptal | Kırmızı |

---

## 💡 İpuçları ve En İyi Uygulamalar

1. **Ödeme Validasyonu**
   - Her zaman ödeme tutarını doğrulayın
   - Müşteri ve personel ID'lerini kontrol edin
   - Rapor ID'sinin geçerli olduğunu doğrulayın

2. **Hata Yönetimi**
   - Tüm async işlemleri try-catch bloğuna alın
   - Kullanıcıya anlamlı hata mesajları gösterin
   - Hataları loglayın

3. **Performans**
   - Büyük veri setleri için pagination kullanın
   - Önbellekleme mekanizmaları uygulayın
   - Gereksiz yeniden render'lerden kaçının

4. **Güvenlik**
   - Gerçek ödeme sistemlerinde SSL kullanın
   - Hassas verileri şifreleyin
   - Yetkilendirme kontrolü yapın

---

## 🐛 Sorun Giderme

### Ödeme Kaydedilmiyor

**Sorun**: Ödeme yapıldıktan sonra kayıt görünmüyor

**Çözüm**:
1. SharedPreferences'in düzgün çalıştığını kontrol edin
2. `FinanceService.odemeEkle` fonksiyonunun `true` döndürdüğünü doğrulayın
3. Console log'larını kontrol edin

### Hakediş Hesaplanmıyor

**Sorun**: Ödeme sonrası hakediş oluşturulmuyor

**Çözüm**:
1. Komisyon oranının %25 olduğunu kontrol edin
2. Personel ID'sinin doğru olduğunu doğrulayın
3. `FinanceService.hakedisEkle` fonksiyonunu kontrol edin

### Rapor Kilidi Açılmıyor

**Sorun**: Ödeme sonrası rapor hala kilitli

**Çözüm**:
1. `isPaid` alanının `true` olarak güncellendiğini kontrol edin
2. `setState` fonksiyonunun çağrıldığını doğrulayın
3. Rapor modelinin doğru güncellendiğini kontrol edin

---

## 📞 Destek

Sorularınız için:
- GitHub Issues: [Proje Repo]
- Email: destek@uzmanlik-sistemi.com
- Dokümantasyon: [Ana Dokümantasyon]

---

## 📝 Değişiklik Geçmişi

### v1.0.0 (2026-01-08)
- ✅ İlk sürüm
- ✅ Ödeme sistemi
- ✅ Hakediş yönetimi
- ✅ Admin dashboard
- ✅ Rapor entegrasyonu

---

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.

---

**Son Güncelleme**: 2026-01-08
**Sürüm**: 1.0.0

# Merkezi Finans Sistemi - Hızlı Başlangıç

Bu kılavuz, Merkezi Finans Sistemi'ni hızlıca entegre etmenize yardımcı olur.

## ⚡ 5 Dakikada Entegrasyon

### 1. Ödeme Sayfasına Git

Müşteri raporları sayfasında, ödenmemiş raporlar için ödeme butonu ekleyin:

```dart
// lib/screens/musteri_raporlarim.dart

import 'musteri_odeme_sayfasi.dart';

// Rapor detayında ödeme butonu
if (!rapor.isPaid) {
  ElevatedButton(
    onPressed: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusteriOdemeSayfasi(
            rapor: rapor,
            customerID: 'musteri_123',
            staffID: 'personel_456',
            onOdemeBasarili: () {
              setState(() {
                rapor.isPaid = true;
              });
            },
          ),
        ),
      );
      
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ödeme başarılı!')),
        );
      }
    },
    child: Text('Ödeme Yap'),
  );
}
```

### 2. Admin Dashboard'a Erişim

Admin paneline finans dashboard linki ekleyin:

```dart
// lib/screens/admin_paneli.dart

import 'admin_finans_dashboard.dart';

// Admin menüsünde
ListTile(
  leading: Icon(Icons.account_balance_wallet),
  title: Text('Finans Dashboard'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminFinansDashboard(),
      ),
    );
  },
),
```

### 3. Rapor Modelini Güncelle

Rapor modelinize `isPaid` alanını ekleyin:

```dart
// lib/models/arac_rapor_model.dart

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

### 4. Rapor Listesine Görsel Göstergeler Ekle

Rapor kartlarında ödeme durumunu gösterin:

```dart
// Rapor kartı tasarımı
Widget _raporKarti(AracRapor rapor) {
  return Card(
    child: ListTile(
      leading: Stack(
        children: [
          Icon(Icons.description),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                rapor.odemeDurumuIkonu,
                size: 16,
                color: rapor.odemeDurumuRengi,
              ),
            ),
          ),
        ],
      ),
      title: Text('${rapor.marka} ${rapor.model}'),
      subtitle: Text(rapor.odemeDurumu),
      trailing: Chip(
        label: Text(rapor.odemeDurumu),
        backgroundColor: rapor.odemeDurumuRengi.withOpacity(0.1),
      ),
    ),
  );
}
```

---

## 🔧 Temel Kullanım

### Ödeme İşlemi

```dart
// Müşteri ödemesi yap
final odeme = await FinanceService.musteriOdemeYap(
  customerID: 'musteri_123',
  staffID: 'personel_456',
  reportID: 'rapor_789',
  amount: 6500.0,
  odemeYontemi: 'kredi_karti',
);

if (odeme != null) {
  print('Ödeme başarılı!');
  print('Komisyon: ${odeme.formatliKomisyon}');
  print('Net Tutar: ${odeme.formatliNet}');
}
```

### Finansal Özet Alma

```dart
// Finansal özet getir
final ozet = await FinanceService.getFinansalOzet();

print('Toplam Ciro: ${ozet['toplamCiro']} TL');
print('Net Gelir: ${ozet['netGelir']} TL');
print('Hakediş Borcu: ${ozet['toplamHakedisBorcu']} TL');
```

### Personel Hakedişlerini Getir

```dart
// Personel hakedişlerini getir
final hakedisler = await FinanceService.getPersonelHakedisleri('personel_456');

for (var hakedis in hakedisler) {
  print('Hakediş: ${hakedis.formatliTutar}');
  print('Durum: ${hakedis.durumText}');
}
```

---

## 🎨 Görsel Özelleştirme

### Renkleri Değiştirme

```dart
// Ödeme durumu renkleri
Color get odemeDurumuRengi {
  if (isPaid) return Colors.green;
  return Colors.red;
}

// Veya özel renkler
Color get odemeDurumuRengi {
  if (isPaid) return Color(0xFF4CAF50); // Özel yeşil
  return Color(0xFFF44336); // Özel kırmızı
}
```

### İkonları Değiştirme

```dart
IconData get odemeDurumuIkonu {
  if (isPaid) return Icons.check_circle;
  return Icons.lock; // Kilit ikonu
}
```

---

## 📊 Dashboard Widget'ları

### Basit Finansal Özet Kartı

```dart
Widget _finansKarti(String baslik, String deger, IconData ikon, Color renk) {
  return Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(ikon, color: renk, size: 32),
          SizedBox(height: 8),
          Text(
            deger,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: renk,
            ),
          ),
          Text(baslik),
        ],
      ),
    ),
  );
}

// Kullanım
_finansKarti('Toplam Ciro', '50,000 TL', Icons.trending_up, Colors.green)
```

---

## 🧪 Hızlı Test

### Test 1: Ödeme İşlemi

```dart
void testOdeme() async {
  final odeme = await FinanceService.musteriOdemeYap(
    customerID: 'test',
    staffID: 'test',
    reportID: 'test',
    amount: 1000.0,
    odemeYontemi: 'kredi_karti',
  );
  
  assert(odeme != null);
  assert(odeme!.status == 'Paid');
  assert(odeme!.amount == 1000.0);
  assert(odeme!.komisyonTutari == 250.0); // 1000 * 0.25
}
```

### Test 2: Rapor Ödeme Durumu

```dart
void testRaporOdemeDurumu() async {
  final odendiMi = await FinanceService.raporOdendiMi('rapor_123');
  
  assert(odendiMi == true || odendiMi == false);
}
```

---

## 🐛 Yaygın Sorunlar

### Sorun: Ödeme kaydedilmiyor

**Çözüm**:
```dart
// SharedPreferences'in düzgün çalıştığını kontrol edin
final prefs = await SharedPreferences.getInstance();
print('SharedPreferences çalışıyor: ${prefs != null}');
```

### Sorun: Hakediş hesaplanmıyor

**Çözüm**:
```dart
// Komisyon oranını kontrol edin
final odeme = Odeme(
  amount: 1000.0,
  commission: 25.0, // %25 olmalı
  // ... diğer alanlar
);

print('Komisyon: ${odeme.komisyonTutari}'); // 250.0 olmalı
```

### Sorun: Rapor kilidi açılmıyor

**Çözüm**:
```dart
// setState'i çağırdığınızdan emin olun
setState(() {
  rapor.isPaid = true;
});

// Veya onOdemeBasarili callback'ini kullanın
MusteriOdemeSayfasi(
  onOdemeBasarili: () {
    setState(() {
      rapor.isPaid = true;
    });
  },
),
```

---

## 📚 Ek Kaynaklar

- [Tam Dokümantasyon](FINANS_SISTEMI_DOKUMANTASYON.md)
- [API Referansı](FINANS_SISTEMI_DOKUMANTASYON.md#api-referansı)
- [Test Rehberi](FINANS_SISTEMI_DOKUMANTASYON.md#test-rehberi)

---

## 💡 İpuçları

1. **Her zaman async/await kullanın**
   ```dart
   final odeme = await FinanceService.musteriOdemeYap(...);
   ```

2. **Hata yönetimi yapın**
   ```dart
   try {
     final odeme = await FinanceService.musteriOdemeYap(...);
   } catch (e) {
     print('Hata: $e');
   }
   ```

3. **Kullanıcıya bildirim gösterin**
   ```dart
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(content: Text('Ödeme başarılı!')),
   );
   ```

4. **Loading gösterin**
   ```dart
   setState(() {
     _isLoading = true;
   });
   
   final odeme = await FinanceService.musteriOdemeYap(...);
   
   setState(() {
     _isLoading = false;
   });
   ```

---

## 🎯 Sonraki Adımlar

1. ✅ Ödeme sayfasını entegre et
2. ✅ Admin dashboard'a erişim ekle
3. ✅ Rapor modelini güncelle
4. ✅ Görsel göstergeler ekle
5. ✅ Test et
6. ✅ Deploy et

---

**İyi kodlamalar! 🚀**

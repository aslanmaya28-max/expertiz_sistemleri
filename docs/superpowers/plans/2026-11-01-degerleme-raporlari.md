# Değerleme raporları uygulama planı

Amaç: Kullanıcının ayrıntılı 007 şartnamesindeki kalıcı, tekrar açılabilir ve doğrulanabilir raporu uygulamak.
Mimari: analysis_history üzerinde ek sütunlar; tam sonuç ve kimlik kredi işlemi içinde yazılır. UUID başına PostgreSQL işlem kilidi arama öncesinde alınır. PDF kayıtlı anlık görüntüden üretilir. Mevcut mühür ve doğrulama hız sınırı paylaşılır.
Sınırlar: Form/prefill, değerleme hesabı ve dış arama mantığı değişmez; eski kayıtlar korunur; yalnız bu dal, push yok.

- [x] 1. PostgreSQL bütünleşme testleri: kayıt, sahiplik, eski kayıt, eşzamanlı tekrar, hata ve geri alma.
- [x] 2. Eklemeli şema, atomik ödeme/rapor kaydı ve tekrar kilidi; liste/detay uçları.
- [x] 3. Paylaşılan font arama, Türkçe PDF, mevcut doğrulamada tür desteği; PDF ve doğrulama testleri.
- [x] 4. Ortak sonuç bileşeni, rapor liste/detay sayfaları, panel bağlantıları, UUID gönderimi.
- [x] 5. Zorunlu tüm Python/site testleri, görsel PDF kontrolü ve bağımsız inceleme.
- [ ] 6. Türkçe commit: Git worktree index.lock yazma izni nedeniyle engellendi.

Kontroller: Aynı UUID farklı kullanıcılarda bağımsız; yetersiz kredi tekrar dönüşünü engellemez; başarısız işlem bakiye ve rapor bırakmaz; uzun metin/URL PDF taşırmaz; eski rapor tam rapor gibi sunulmaz.

Doğrulama: Python 222 test, site 9 test ve TypeScript kontrolü geçti. Normal iki sayfalık ve uzun içerikli dört sayfalık PDF görsel olarak incelendi.

İnceleme düzeltmesi: Bekleyen UUID kilitleri küçük iş bağlantı havuzunu tüketebiliyordu. İki bağlantılı havuzla hata yeniden üretildi; kilit için havuz dışı bağlantı kullanıldı ve aynı test geçti. UUID içeren her işlem tamamlanana kadar ek bir PostgreSQL bağlantısı kullanır; hata ve başarı yollarında bağlantı kapatılır.

Teslim engeli: `git add` sırasında `.git/worktrees/codex-007-raporlarim-pdf-dogrulama/index.lock` oluşturulamadı (`Permission denied`). Değişiklikler çalışma kopyasında hazır; köprü test kapısının commit etmesi gerekiyor.

import 'package:flutter_riverpod/flutter_riverpod.dart';

const bulunamamaOnayi =
    'Araç belirtilen adreste bulunamazsa hizmet bedeli iade edilmez; kurumsal ekspertiz paket ücreti iade edilir.';
const randevuAciklamasi =
    'Randevuyu satıcıyla siz ayarlarsınız; anlaşmalı firmamız gelmeden önce satıcıyı arar.';

// UTC nesneleri burada İstanbul duvar saatini taşır; cihazın saat dilimi kullanılmaz.
DateTime istanbulSaati(DateTime an) => an.toUtc().add(const Duration(hours: 3));
final randevuSimdiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
DateTime ilkRandevu(DateTime simdi) {
  final min = istanbulSaati(simdi).add(const Duration(hours: 2));
  final dakika = DateTime.utc(
    min.year,
    min.month,
    min.day,
    min.hour,
    min.minute,
  );
  return dakika.isBefore(min) ? dakika.add(const Duration(minutes: 1)) : dakika;
}

String randevuDegeri(DateTime wall) {
  String iki(int v) => v.toString().padLeft(2, '0');
  return '${wall.year}-${iki(wall.month)}-${iki(wall.day)}T${iki(wall.hour)}:${iki(wall.minute)}';
}

DateTime? randevuOku(String raw) {
  final ofsetli = RegExp(
    r'(Z|[+-]\d\d:?\d\d)$',
    caseSensitive: false,
  ).hasMatch(raw);
  // Ofsetsiz API değeri İstanbul duvar saatidir. Önce cihazın yerel saatinde
  // ayrıştırmak DST boşluklarında saati değiştirebildiği için UTC olarak oku.
  final parsed = DateTime.tryParse(ofsetli ? raw : '${raw}Z');
  if (parsed == null) return null;
  if (ofsetli) {
    return istanbulSaati(parsed);
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
  );
}

String randevuMetni(String raw) {
  final d = randevuOku(raw);
  if (d == null) return '—';
  String iki(int v) => v.toString().padLeft(2, '0');
  return '${iki(d.day)}.${iki(d.month)}.${d.year} ${iki(d.hour)}:${iki(d.minute)} · İstanbul saati';
}

String? randevuHatasi(String raw, DateTime simdi) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(raw)) {
    return 'Randevu tarihi ve saatini seçin.';
  }
  final d = randevuOku(raw);
  if (d == null ||
      randevuDegeri(d) != raw ||
      d.isBefore(ilkRandevu(simdi)) ||
      d.isAfter(istanbulSaati(simdi).add(const Duration(days: 30)))) {
    return 'Randevu en erken 2 saat sonra, en geç 30 gün içinde olmalı.';
  }
  return null;
}

String? saticiTelefonHatasi(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('90') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  } else if (digits.length == 10 && !digits.startsWith('0')) {
    digits = '0$digits';
  }
  return RegExp(r'^0\d{10}$').hasMatch(digits)
      ? null
      : 'Geçerli bir Türkiye cep veya sabit telefon numarası girin.';
}

const talepHataAlanlari = {
  'il_kapali': 'il',
  'randevu_gecersiz': 'zaman',
  'adres_eksik': 'adres',
  'satici_telefon_gecersiz': 'satici_telefon',
  'bulunamama_onayi_gerekli': 'bulunamama',
};
const talepHataMetinleri = {
  'il_kapali': 'Bu ilde henüz hizmet yok.',
  'randevu_gecersiz':
      'Randevu en erken 2 saat sonra, en geç 30 gün içinde olmalı.',
  'adres_eksik': 'Açık adres / buluşma noktası 10–300 karakter olmalı.',
  'satici_telefon_gecersiz':
      'Geçerli bir Türkiye cep veya sabit telefon numarası girin.',
  'bulunamama_onayi_gerekli':
      'Araç adreste bulunamazsa uygulanacak koşulları onaylayın.',
};

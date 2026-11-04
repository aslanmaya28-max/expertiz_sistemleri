abstract final class FormRules {
  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Geçerli bir e-posta adresi girin.';
  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 && digits.length <= 15
        ? null
        : 'Geçerli bir telefon numarası girin.';
  }

  static String? password(String? value) {
    final p = value ?? '';
    if (p.length < 8 ||
        p.length > 128 ||
        !RegExp(r'[A-Z]').hasMatch(p) ||
        !RegExp(r'[a-z]').hasMatch(p) ||
        !RegExp(r'[0-9]').hasMatch(p)) {
      return 'Şifre 8–128 karakter, en az bir büyük harf, küçük harf ve rakam içermeli.';
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak_sistemleri/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Kaydedilmemiş tema ilk açılışta koyudur', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    expect(provider.themeMode, ThemeMode.dark);
    await Future<void>.delayed(Duration.zero);
    expect(provider.themeMode, ThemeMode.dark);
    provider.dispose();
  });
  test('İlk yükleme kullanıcının hemen yaptığı açık tema seçimini ezmez',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.light);
    await Future<void>.delayed(Duration.zero);
    expect(provider.themeMode, ThemeMode.light);
    provider.dispose();
  });
  test('Ayarlar ekranındaki kayıtlı sistem tercihi korunur', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
    final provider = ThemeProvider();
    await Future<void>.delayed(Duration.zero);
    expect(provider.themeMode, ThemeMode.system);
    provider.dispose();
  });
  test('Açık tema seçimi sonraki oturuma taşınır', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = ThemeProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.setThemeMode(ThemeMode.light);
    final restored = ThemeProvider();
    await Future<void>.delayed(Duration.zero);
    expect(restored.themeMode, ThemeMode.light);
    provider.dispose();
    restored.dispose();
  });
}


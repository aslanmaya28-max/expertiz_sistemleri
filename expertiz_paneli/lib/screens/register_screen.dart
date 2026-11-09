/// REGISTER SCREEN - SUPABASE AUTH + PROFILES
///
/// AuthServicePro KULLANMAZ - direkt Supabase Auth + profiles kullanır
/// Kayıt sonrası UserProvider üzerinden oturum açılır
library;

import 'package:flutter/material.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import 'package:yerimebak_sistemleri/core/widgets/yerimebak_logo.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/user_provider.dart';
import '../customer/customer_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonController = TextEditingController();
  final _sifreController = TextEditingController();
  bool _isLoading = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _adSoyadController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Kullanım koşullarını kabul etmelisiniz.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.registerCustomer(
        email: _emailController.text.trim(),
        password: _sifreController.text,
        fullName: _adSoyadController.text.trim(),
        phone: _telefonController.text.trim(),
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hesabınız oluşturuldu.'),
            backgroundColor: context.renkler.birincilMetin,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CustomerDashboard()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userProvider.error ?? 'Giriş yapılamadı'),
            backgroundColor: context.renkler.uyari,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt hatası: $e'),
          backgroundColor: context.renkler.tehlike,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const YerimeBakLogo(height: 40),
              const SizedBox(height: 24),
              Text('Müşteri hesabı oluşturun', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              YbGirdi(
                controller: _adSoyadController,
                etiket: 'Ad Soyad',
                validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 16),
              YbGirdi(
                controller: _emailController,
                etiket: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@')
                    ? 'Geçerli e-posta girin'
                    : null,
              ),
              const SizedBox(height: 16),
              YbGirdi(
                controller: _telefonController,
                etiket: 'Telefon',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              YbGirdi(
                controller: _sifreController,
                etiket: 'Şifre',
                obscureText: true,
                validator: (v) {
                  if (v == null ||
                      v.length < 8 ||
                      v.length > 128 ||
                      !RegExp(r'[A-Z]').hasMatch(v) ||
                      !RegExp(r'[a-z]').hasMatch(v) ||
                      !RegExp(r'[0-9]').hasMatch(v)) {
                    return '8-128 karakter, büyük harf, küçük harf ve rakam gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: _isLoading
                    ? null
                    : (value) =>
                        setState(() => _termsAccepted = value ?? false),
                title: const Text(
                    'Kullanım koşullarını okudum ve kabul ediyorum; KVKK aydınlatma metnini okudum.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Wrap(children: [
                TextButton(
                  onPressed: () => launchUrl(
                      Uri.parse(
                          'https://www.yerimebak.com.tr/kullanim-kosullari'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Kullanım Koşulları'),
                ),
                TextButton(
                  onPressed: () => launchUrl(
                      Uri.parse('https://www.yerimebak.com.tr/kvkk'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('KVKK Aydınlatma Metni'),
                ),
              ]),
              YbButon(metin: 'Kayıt Ol', onPressed: _register, yukleniyor: _isLoading, tamGenislik: true),
            ],
          ),
        ),
      ))),
    );
  }
}

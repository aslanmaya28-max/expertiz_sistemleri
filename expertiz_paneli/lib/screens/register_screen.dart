/// REGISTER SCREEN - SUPABASE AUTH + PROFILES
///
/// AuthServicePro KULLANMAZ - direkt Supabase Auth + profiles kullanır
/// Kayıt sonrası UserProvider üzerinden oturum açılır
library;

import 'package:flutter/material.dart';
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
        const SnackBar(content: Text('Kullanım koşullarını kabul etmelisiniz.')),
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
          const SnackBar(
            content: Text('Kayıt başarılı! Hoş geldiniz.'),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayıt hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıt Ol')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _adSoyadController,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                validator: (v) => v == null || v.isEmpty ? 'Zorunlu' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-posta'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Geçerli e-posta girin' : null,
              ),
              TextFormField(
                controller: _telefonController,
                decoration: const InputDecoration(labelText: 'Telefon'),
                keyboardType: TextInputType.phone,
              ),
              TextFormField(
                controller: _sifreController,
                decoration: const InputDecoration(labelText: 'Şifre'),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.length < 8 || v.length > 128 ||
                      !RegExp(r'[A-Z]').hasMatch(v) || !RegExp(r'[a-z]').hasMatch(v) ||
                      !RegExp(r'[0-9]').hasMatch(v)) {
                    return '8-128 karakter, büyük harf, küçük harf ve rakam gerekli';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: _isLoading ? null : (value) => setState(() => _termsAccepted = value ?? false),
                title: const Text('Kullanım koşullarını okudum ve kabul ediyorum; KVKK aydınlatma metnini okudum.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              Wrap(children: [
                TextButton(
                  onPressed: () => launchUrl(Uri.parse('https://www.yerimebak.com.tr/kullanim-kosullari'), mode: LaunchMode.externalApplication),
                  child: const Text('Kullanım Koşulları'),
                ),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse('https://www.yerimebak.com.tr/kvkk'), mode: LaunchMode.externalApplication),
                  child: const Text('KVKK Aydınlatma Metni'),
                ),
              ]),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

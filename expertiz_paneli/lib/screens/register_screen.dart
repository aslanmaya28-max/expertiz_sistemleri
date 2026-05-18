/// REGISTER SCREEN - SUPABASE AUTH + PROFILES
///
/// AuthServicePro KULLANMAZ - direkt Supabase Auth + profiles kullanır
/// Kayıt sonrası UserProvider üzerinden oturum açılır
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final success = await userProvider.registerCustomer(
        email: _emailController.text.trim(),
        password: _sifreController.text,
        fullName: _adSoyadController.text.trim(),
        phone: _telefonController.text.trim(),
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
        Navigator.pushReplacementNamed(context, '/login');
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
                validator: (v) =>
                    v == null || v.length < 6 ? 'En az 6 karakter' : null,
              ),
              const SizedBox(height: 20),
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

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../core/widgets/yerimebak_logo.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:yerimebak_sistemleri/providers/user_provider.dart';
import 'package:yerimebak_sistemleri/screens/register_screen.dart';
import '../core/widgets/glass_card.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/constants/yerimebak_colors.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- PERSONEL / ADMIN GİRİŞİ ---
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    // UserProvider Kullanımı - SINGLE SOURCE OF TRUTH
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;

      // AuthWrapper'ı tetiklemek için kök dizine (home) dön
      Navigator.pushReplacementNamed(context, '/');
      
      final user = userProvider.currentUser;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hoşgeldiniz ${user?.fullName ?? "Kullanıcı"}'),
          backgroundColor: YerimeBakColors.cyberNeonTurquoise,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.error ?? 'Giriş başarısız'),
          backgroundColor: YerimeBakColors.red,
        ),
      );
    }
  }

  // --- YENİ TASARIM YAPISI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FuturisticTheme.loginBgStart,
              FuturisticTheme.loginBgEnd,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive Logic: Desktop (Row) vs Mobile (Column)
                if (constraints.maxWidth > 900) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sol Taraf: Logo + Login Form
                      SizedBox(
                        width: 420,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLogo(),
                                                        const SizedBox(height: 32),
                            _buildLoginForm(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 60),
                      // Sağ Taraf: Bilgi Paneli
                      SizedBox(
                        width: 500,
                        height: 600, // Fixed height to match design balance
                        child: _buildInfoPanel(),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo(),
                                            const SizedBox(height: 32),
                      _buildLoginForm(),
                      const SizedBox(height: 30),
                      _buildInfoPanel(),
                    ],
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // 1. LOGO BİLEŞENİ (Y Harfi)
  Widget _buildLogo() {
    return const YerimeBakLogo(height: 84, onDark: true);
  }

  // 2. LOGIN FORM (SOL)
  Widget _buildLoginForm() {
    return GlassCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Giriş Yap",
              style: TextStyle(
                color: FuturisticTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 24),
             
            // 🔒 DÜZELTİLDİ (B12): TextField → FormField/TextFormField
            // _formKey.currentState!.validate() artık gerçek validasyon yapar.
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                hintText: "Kullanıcı adı veya e-posta",
              ),
              style: const TextStyle(color: FuturisticTheme.textPrimary),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'E-posta veya kullanıcı adı gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: "•••••••",
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              style: const TextStyle(color: FuturisticTheme.textPrimary),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Şifre gerekli';
                }
                return null;
              },
            ),

            
            const SizedBox(height: 16),
            
            // Remember Me & Forgot Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val!),
                    ),
                    const Text("Beni Hatırla"),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("Şifremi Unuttum"),
                )
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Login Button
            InkWell(
              onTap: _isLoading ? null : _handleLogin,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: FuturisticTheme.accentCyan.withValues(alpha: 0.5)),
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.accentCyan.withValues(alpha: 0.2),
                      FuturisticTheme.accentCyan.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                     BoxShadow(
                       color: FuturisticTheme.accentCyan.withValues(alpha: 0.15),
                       blurRadius: 15,
                       spreadRadius: 0,
                     )
                  ]
                ),
                child: Center(
                  child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                      "Giriş Yap",
                      style: TextStyle(
                        color: FuturisticTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        shadows: [Shadow(color: FuturisticTheme.accentCyan, blurRadius: 10)]
                      ),
                    ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Register Button
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Hesabınız yok mu? ',
                    style: TextStyle(color: FuturisticTheme.textSecondary),
                  ),
                  Text(
                    'Kayıt Ol',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. INFO PANEL (SAĞ)
  Widget _buildInfoPanel() {
    return Container(
      decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(20),
         border: Border.all(
           color: FuturisticTheme.accentCyan.withValues(alpha: 0.3),
           width: 1
         ),
        color: FuturisticTheme.loginBgStart.withValues(alpha: 0.4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                 padding: const EdgeInsets.all(20),
                 child: Row(
                   children: [
                     const YerimeBakLogo(height: 36, onDark: true)
                   ],
                 ),
              ),
              const Divider(color: Colors.white10),
              
              // Sections
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildInfoSection(
                      title: "YerimeBak Nedir?",
                      description: [
                        "Araç alım satımında güvenilir oto ekspertiz çözümü sunar.",
                        "Profesyonel incelemeyi ileri teknoloji ile bir araya getirir.",
                        "Hızlı, detaylı ve tarafsız raporlar oluşturur"
                      ],
                      icon: Icons.car_repair,
                    ),
                    const SizedBox(height: 25),
                     _buildInfoSection(
                      title: "Nasıl Çalışır?",
                      description: [
                        "1. Ekspertiz talebi oluşturun",
                        "2. Uzman ekibimiz aracınızı detaylıca incelesin",
                        "3. Kapsamlı raporu çevrimiçi olarak görüntüleyin.",
                        "Tüm süreç şeffaf, hızlı ve güvenilirdir."
                      ],
                      icon: Icons.search,
                    ),
                    const SizedBox(height: 25),
                     _buildInfoSection(
                      title: "Neden YerimeBak?",
                      description: [
                        "Güvenilirlik ve şeffaflık önceliğimiz",
                        "Son teknoloji diagnostic cihazlar ve uzman ekibimizle en ince detaylar bile gözden kaçmaz.",
                        "Raporlarınıza her yerden, her zaman ulaşabilirsiniz"
                      ],
                      icon: Icons.verified_user,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<String> description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight
        )
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FuturisticTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...description.map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Icon(
                          _getIconForText(text),
                          color: FuturisticTheme.accentCyan,
                          size: 14
                        ),
                      ),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: FuturisticTheme.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Large Icon on the right
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: FuturisticTheme.accentCyan.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: FuturisticTheme.accentCyan.withValues(alpha: 0.1), blurRadius: 10)
              ]
            ),
            child: Icon(icon, color: FuturisticTheme.accentCyan, size: 32),
          )
        ],
      ),
    );
  }

  IconData _getIconForText(String text) {
     if (text.startsWith("1") || text.startsWith("2") || text.startsWith("3")) return Icons.arrow_right;
     if (text.startsWith("Güvenilirlik")) return Icons.star;
     return Icons.check_circle_outline;
  }
}

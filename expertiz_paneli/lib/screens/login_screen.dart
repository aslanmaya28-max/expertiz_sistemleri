import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/user_provider.dart';
import '../core/widgets/yerimebak_logo.dart';
import '../bilesenler/bilesenler.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false, _obscurePassword = true, _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.go('/');
      YbBildirim.goster(context, 'Oturum açıldı.', tur: YbRozetTuru.basari);
    } else {
      YbBildirim.goster(context, userProvider.error ?? 'Giriş başarısız',
          tur: YbRozetTuru.tehlike);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(children: [
            Expanded(flex: 5, child: _brand(wide: true)),
            Expanded(
                flex: 6,
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(PanelOlcu.sayfa),
                        child: _form())))
          ]);
        }
        return SingleChildScrollView(
            child: Column(children: [
          _brand(wide: false),
          Padding(padding: const EdgeInsets.all(Olcu.s24), child: _form())
        ]));
      }));

  Widget _brand({required bool wide}) {
    final colors = context.renkler;
    final light = Theme.of(context).brightness == Brightness.light;
    // Marka bandı iki temada da koyu yeşil: koyu temada rapor yeşili, açık temada marka bandı
    final band = light ? colors.markaBandi : colors.raporKoyu;
    final soluk = YbRenkler.acik.markaBandiMetin;
    Widget madde(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Olcu.s16),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colors.beyaz.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: YbRenkler.acik.markaBandiVurgu)),
          const SizedBox(width: Olcu.s12),
          Expanded(
              child: Text(text,
                  style: Yazilar.govdeKucuk.copyWith(color: colors.beyaz))),
        ]));
    final content = Padding(
        padding: EdgeInsets.all(wide ? PanelOlcu.sayfa * 2 : Olcu.s28),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            children: [
              const YerimeBakLogo(height: 40, onDark: true),
              SizedBox(height: wide ? Olcu.s28 * 2 : Olcu.s20),
              Text('Operasyonun her adımı,\ntek bir yerde.',
                  style: Yazilar.baslik1.copyWith(
                      color: colors.beyaz,
                      height: 1.25,
                      fontSize: wide ? 34 : 25,
                      letterSpacing: -0.6)),
              const SizedBox(height: Olcu.s16),
              Text(
                  'Ekspertiz taleplerini, saha ekibini ve müşteri süreçlerini güvenle yönetin.',
                  style: Yazilar.govdeKucuk.copyWith(color: soluk)),
              if (wide) ...[
                const SizedBox(height: Olcu.s28 + Olcu.s12),
                madde(LucideIcons.headset, 'Kontrol merkezi: randevular ve saha iletişimi tek ekranda'),
                madde(LucideIcons.carFront, 'Talepler, personel ataması ve rapor onayı'),
                madde(LucideIcons.chartLine, 'Müşteri, değerleme ve kredi satışı özeti'),
              ],
            ]));
    return Container(width: double.infinity, color: band, child: content);
  }

  Widget _form() => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
              key: _formKey,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Yönetim ve saha paneli',
                        style: Yazilar.baslik2
                            .copyWith(color: context.renkler.metin)),
                    const SizedBox(height: Olcu.s8),
                    Text('Hesabınızla devam edin.',
                        style: Yazilar.govdeKucuk
                            .copyWith(color: context.renkler.metinIkincil)),
                    const SizedBox(height: Olcu.s28),
                    YbGirdi(
                        etiket: 'Kullanıcı adı veya e-posta',
                        controller: _emailController,
                        prefixIcon: const Icon(LucideIcons.userRound),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'E-posta veya kullanıcı adı gerekli'
                                : null),
                    const SizedBox(height: Olcu.s20),
                    YbGirdi(
                        etiket: 'Şifre',
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        prefixIcon: const Icon(LucideIcons.lockKeyhole),
                        suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Şifreyi göster'
                                : 'Şifreyi gizle',
                            icon: Icon(_obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword)),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Şifre gerekli'
                                : null),
                    const SizedBox(height: Olcu.s12),
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Checkbox(
                                value: _rememberMe,
                                onChanged: (value) => setState(
                                    () => _rememberMe = value ?? false)),
                            const Text('Beni hatırla')
                          ]),
                          TextButton(
                              onPressed: () {},
                              child: const Text('Şifremi unuttum'))
                        ]),
                    const SizedBox(height: Olcu.s24),
                    YbButon(
                        metin: 'Giriş yap',
                        onPressed: _handleLogin,
                        yukleniyor: _isLoading,
                        tamGenislik: true),
                    const SizedBox(height: Olcu.s16),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const RegisterScreen())),
                        child: const Text('Hesabınız yok mu? Kayıt ol')),
                  ]))));
}


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
            Expanded(
                flex: 5,
                child: LayoutBuilder(
                    builder: (context, size) => SingleChildScrollView(
                        child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minHeight: size.maxHeight),
                            child: _brand(wide: true))))),
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
    final vurgu = YbRenkler.acik.markaBandiVurgu;
    // Kurucuların motivasyon yazısı (kullanıcı metni; değiştirilmeden gösterilir)
    const satirlar = [
      'Seni anlamayacaklar; anlamak için de uğraşmayacaklar.',
      'Fikirlerin, betona çarpar gibi çarpıp dağılacak yüzlerinde.',
      'Sen susup, yoluna bakacaksın...',
      'Cebindeki umutlara sıkı sıkıya sarılıp, inandığın hiçbir tutkunun peşini bırakmayacaksın ve başaracaksın!',
      'İşte o zaman, sadece sana inananlarla yan yana olacaksın.',
    ];
    final yazi = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: const EdgeInsets.only(bottom: Olcu.s16),
                  child: Icon(LucideIcons.quote, size: 34, color: vurgu))),
          for (final satir in satirlar)
            Padding(
                padding: const EdgeInsets.only(bottom: Olcu.s8),
                child: Text(satir,
                    style: TextStyle(
                        fontSize: 19,
                        height: 1.55,
                        letterSpacing: -0.1,
                        color: colors.beyaz,
                        fontWeight: FontWeight.w400))),
          const SizedBox(height: Olcu.s20),
          Align(
              alignment: Alignment.centerRight,
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(width: 40, height: 2, color: vurgu),
                const SizedBox(height: Olcu.s12),
                Text('Maya Teknoloji ve Dijital Hizmetler',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.beyaz)),
                const SizedBox(height: Olcu.s4),
                Text('Kurucular: Ali ASLAN & Meliha ASLAN',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: soluk)),
              ])),
        ]));
    final content = Padding(
        padding: EdgeInsets.all(wide ? PanelOlcu.sayfa * 2 : Olcu.s28),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
            children: [
              const YerimeBakLogo(height: 40, onDark: true),
              // Telefonda form öne çıksın diye yazı yalnız geniş ekranda
              if (wide) ...[
                const SizedBox(height: Olcu.s28 * 2),
                yazi,
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

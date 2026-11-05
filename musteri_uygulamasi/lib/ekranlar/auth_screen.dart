import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../api/providers.dart';
import '../bilesenler/ortak.dart';
import '../oturum/form_rules.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';
import '../bilesenler/marka.dart';
import '../bilesenler/kart.dart';

enum AuthMode { login, register, forgot }

class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode mode;
  const AuthScreen(this.mode, {super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      surname = TextEditingController(),
      phone = TextEditingController();
  bool terms = false, sent = false;
  @override
  void dispose() {
    for (final c in [email, password, name, surname, phone]) {
      c.dispose();
    }
    super.dispose();
  }

  String get title => switch (widget.mode) {
    AuthMode.login => 'Giriş yap',
    AuthMode.register => 'Kayıt ol',
    AuthMode.forgot => 'Şifremi unuttum',
  };
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final account = ref.read(accountRepositoryProvider),
        session = ref.read(sessionProvider);
    switch (widget.mode) {
      case AuthMode.login:
        await session.login(email.text, password.text);
      case AuthMode.register:
        if (!terms) {
          throw const ApiFailure(
            'Kullanım Koşulları ve KVKK Aydınlatma Metni onaylanmalıdır.',
          );
        }
        await session.register({
          'email': email.text.trim(),
          'password': password.text,
          'full_name': '${name.text.trim()} ${surname.text.trim()}',
          'phone': phone.text.trim(),
          'terms_accepted': terms,
        });
      case AuthMode.forgot:
        await account.forgotPassword(email.text);
        if (mounted) setState(() => sent = true);
    }
    password.clear();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).brightness == Brightness.light
                  ? YbRenkler.of(context).markaBandi
                  : YbRenkler.of(context).zemin,
              padding: const EdgeInsets.all(Olcu.s28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Marka(bant: Theme.of(context).brightness == Brightness.light),
                  const SizedBox(height: Olcu.s24),
                  Text(
                    'Araç almadan önce doğru bilgiye ulaşın.',
                    style: Yazilar.baslik1.copyWith(
                      color: Theme.of(context).brightness == Brightness.light
                          ? YbRenkler.of(context).beyaz
                          : YbRenkler.of(context).metin,
                    ),
                  ),
                ],
              ),
            ),
            PageBody(
              child: Kart(
                child: AutofillGroup(
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title, style: Yazilar.baslik1),
                        const SizedBox(height: Olcu.s24),
                        if (widget.mode == AuthMode.forgot && sent) ...[
                          const Text(
                            'Bu e-posta adresi kayıtlıysa şifre sıfırlama bağlantısı gönderildi.',
                          ),
                          TextButton(
                            onPressed: () => context.go('/giris'),
                            child: const Text('Girişe dön'),
                          ),
                        ] else ...[
                          if (widget.mode == AuthMode.register) ...[
                            FormFieldView('Ad', name),
                            FormFieldView('Soyad', surname),
                          ],
                          FormFieldView(
                            'E-posta',
                            email,
                            keyboard: TextInputType.emailAddress,
                            validator: FormRules.email,
                          ),
                          if (widget.mode == AuthMode.register)
                            FormFieldView(
                              'Telefon',
                              phone,
                              keyboard: TextInputType.phone,
                              validator: FormRules.phone,
                            ),
                          if (widget.mode != AuthMode.forgot)
                            FormFieldView(
                              'Şifre',
                              password,
                              password: true,
                              validator: widget.mode == AuthMode.register
                                  ? FormRules.password
                                  : null,
                            ),
                          if (widget.mode == AuthMode.register) ...[
                            const Text(
                              'En az 8 karakter; bir büyük harf, küçük harf ve rakam.',
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: terms,
                              onChanged: (v) =>
                                  setState(() => terms = v ?? false),
                              title: const Text(
                                'Kullanım Koşulları’nı kabul ediyorum; KVKK Aydınlatma Metni’ni okudum.',
                              ),
                            ),
                            Wrap(
                              spacing: Olcu.s8,
                              children: [
                                TextButton(
                                  onPressed: () => ref
                                      .read(platformProvider)
                                      .openLink(
                                        'https://www.yerimebak.com.tr/kullanim-kosullari',
                                      ),
                                  child: const Text('Kullanım Koşulları'),
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(platformProvider)
                                      .openLink(
                                        'https://www.yerimebak.com.tr/kvkk',
                                      ),
                                  child: const Text('KVKK'),
                                ),
                              ],
                            ),
                          ],
                          if (ref.watch(sessionProvider).error != null)
                            Text(ref.watch(sessionProvider).error!),
                          const SizedBox(height: Olcu.s16),
                          ActionButton(title, submit),
                          if (widget.mode == AuthMode.login) ...[
                            TextButton(
                              onPressed: () => context.go('/kayit'),
                              child: const Text('Hesap oluştur'),
                            ),
                            TextButton(
                              onPressed: () => context.go('/sifremi-unuttum'),
                              child: const Text('Şifremi unuttum'),
                            ),
                          ] else
                            TextButton(
                              onPressed: () => context.go('/giris'),
                              child: const Text('Giriş yap'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

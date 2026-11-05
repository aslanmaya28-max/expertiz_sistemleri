import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_client.dart';
import '../api/providers.dart' hide themeModeProvider;
import '../tema/gorunum.dart';
import '../bilesenler/liste_satiri.dart';
import '../bilesenler/ikincil_buton.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../bilesenler/ortak.dart';
import '../oturum/form_rules.dart';
import '../tema/olculer.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user,
        config = ref.watch(configProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        child: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel('Hesap bilgileri', [
                ValueLine('Ad soyad', user?.name ?? ''),
                ValueLine('E-posta', user?.email ?? ''),
                ValueLine('Telefon', user?.phone ?? ''),
                ListeSatiri(
                  'Bilgilerimi düzenle',
                  ikon: LucideIcons.userPen,
                  onTap: () => context.push('/profil/duzenle'),
                ),
                ListeSatiri(
                  'Şifremi değiştir',
                  ikon: LucideIcons.lockKeyhole,
                  onTap: () => context.push('/profil/sifre'),
                ),
                ListeSatiri(
                  'Kredi geçmişi',
                  ikon: LucideIcons.history,
                  onTap: () => context.push('/profil/gecmis'),
                ),
              ]),
              Panel('Hizmetler ve bildirimler', [
                ListeSatiri(
                  'Taleplerim',
                  ikon: LucideIcons.clipboardList,
                  onTap: () => context.push('/talepler'),
                ),
                ListeSatiri(
                  'Ekspertiz raporlarım',
                  ikon: LucideIcons.fileCheck,
                  onTap: () => context.push('/ekspertiz-raporlari'),
                ),
                ListeSatiri(
                  'Bildirimler',
                  ikon: LucideIcons.bell,
                  onTap: () => context.push('/bildirimler'),
                ),
              ]),
              Panel('Görünüm', [
                DropdownButtonFormField<ThemeMode>(
                  initialValue: ref.watch(themeModeProvider),
                  decoration: const InputDecoration(labelText: 'Tema'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Sistem'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Açık'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Koyu'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v != null) {
                      try {
                        await ref.read(themeModeProvider.notifier).sec(v);
                      } catch (e) {
                        if (context.mounted) showMessage(context, e.toString());
                      }
                    }
                  },
                ),
              ]),
              Panel('Destek ve yasal bilgiler', [
                for (final entry in const {
                  'Gizlilik Politikası': 'gizlilik',
                  'KVKK Aydınlatma Metni': 'kvkk',
                  'Kullanım Koşulları': 'kullanim-kosullari',
                }.entries)
                  IkincilButon(
                    entry.key,
                    () => ref
                        .read(platformProvider)
                        .openLink(
                          'https://www.yerimebak.com.tr/${entry.value}',
                        ),
                  ),
                IkincilButon(
                  'Destek: ${config?.supportEmail ?? 'destek@yerimebak.com.tr'}',
                  () => ref
                      .read(platformProvider)
                      .openLink(
                        Uri(
                          scheme: 'mailto',
                          path:
                              config?.supportEmail ?? 'destek@yerimebak.com.tr',
                        ).toString(),
                      ),
                ),
                Text(
                  'Uygulama sürümü: ${ref.watch(versionProvider).valueOrNull ?? '—'}',
                ),
              ]),
              if (config?.available == true)
                ActionButton(
                  'Hesabımı sil',
                  () async => context.push('/profil/sil'),
                  destructive: true,
                ),
              const SizedBox(height: Olcu.s12),
              ActionButton('Çıkış yap', ref.read(sessionProvider).logout),
            ],
          ),
        ),
      ),
    );
  }
}

enum EditMode { profile, password, delete }

class AccountEditScreen extends ConsumerStatefulWidget {
  final EditMode mode;
  const AccountEditScreen(this.mode, {super.key});
  @override
  ConsumerState<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends ConsumerState<AccountEditScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController(),
      nextPassword = TextEditingController(),
      confirmation = TextEditingController();
  bool agreed = false;
  @override
  void initState() {
    super.initState();
    final user = ref.read(sessionProvider).user;
    name.text = user?.name ?? '';
    phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    for (final c in [name, phone, password, nextPassword, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  String get title => switch (widget.mode) {
    EditMode.profile => 'Bilgilerimi düzenle',
    EditMode.password => 'Şifremi değiştir',
    EditMode.delete => 'Hesabımı sil',
  };
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    switch (widget.mode) {
      case EditMode.profile:
        await ref.read(sessionProvider).updateProfile(name.text, phone.text);
      case EditMode.password:
        await ref
            .read(accountRepositoryProvider)
            .changePassword(password.text, nextPassword.text);
      case EditMode.delete:
        if (!agreed) {
          throw const ApiFailure(
            'Hesap silme ve kredi sıfırlama onayı gerekiyor.',
          );
        }
        await ref.read(sessionProvider).deleteAccount(password.text);
    }
    password.clear();
    nextPassword.clear();
    confirmation.clear();
    if (mounted) {
      showMessage(
        context,
        widget.mode == EditMode.delete
            ? 'Hesabınız silindi.'
            : 'Bilgileriniz güncellendi.',
      );
      if (widget.mode != EditMode.delete) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final deletionAvailable =
        ref.watch(configProvider).valueOrNull?.available == true;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        child: PageBody(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.mode == EditMode.profile) ...[
                  FormFieldView('Ad soyad', name),
                  FormFieldView(
                    'Telefon',
                    phone,
                    keyboard: TextInputType.phone,
                    validator: FormRules.phone,
                  ),
                ] else ...[
                  if (widget.mode == EditMode.delete) ...[
                    const Text(
                      'Kişisel bilgileriniz anonimleştirilir, oturumunuz kapatılır ve kalan kredileriniz sıfırlanır. İşlem geri alınamaz. Muhasebe kayıtları yasal saklama için, raporlar müşteri iletişim alanları anonimleştirilerek tutulur.',
                    ),
                    ActionButton(
                      'Silme ve saklama ayrıntıları',
                      () => ref
                          .read(platformProvider)
                          .openLink('https://www.yerimebak.com.tr/hesap-silme'),
                    ),
                  ],
                  FormFieldView('Mevcut şifre', password, password: true),
                  if (widget.mode == EditMode.password) ...[
                    FormFieldView(
                      'Yeni şifre',
                      nextPassword,
                      password: true,
                      validator: FormRules.password,
                    ),
                    FormFieldView(
                      'Yeni şifreyi tekrar girin',
                      confirmation,
                      password: true,
                      validator: (v) => v != nextPassword.text
                          ? 'Şifreler eşleşmiyor.'
                          : null,
                    ),
                  ],
                  if (widget.mode == EditMode.delete)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreed,
                      onChanged: (v) => setState(() => agreed = v ?? false),
                      title: const Text(
                        'Hesabımın silinmesini ve kalan kredilerimin sıfırlanmasını onaylıyorum.',
                      ),
                    ),
                ],
                const SizedBox(height: Olcu.s16),
                if (widget.mode != EditMode.delete || deletionAvailable)
                  ActionButton(
                    widget.mode == EditMode.delete
                        ? 'Hesabımı kalıcı olarak sil'
                        : 'Kaydet',
                    widget.mode == EditMode.delete && !agreed ? null : submit,
                    destructive: widget.mode == EditMode.delete,
                  )
                else
                  const Text(
                    'Bu sunucuda hesap silme henüz kullanılamıyor. Destek ile iletişime geçin.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditHistoryScreen extends ConsumerWidget {
  const CreditHistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Kredi geçmişi')),
    body: SingleChildScrollView(
      child: PageBody(
        child: ref
            .watch(historyProvider)
            .when(
              data: (entries) => Panel('Kredi geçmişi', [
                const Text(
                  'Analizlerde kullanılan krediler aşağıda listelenir.',
                ),
                if (entries.isEmpty)
                  const Text('Henüz kredi kullanım kaydı yok.'),
                for (final entry in entries)
                  ValueLine(
                    entry.description,
                    '${dateText(entry.createdAt)} • ${entry.amount == null ? 'Kredi miktarı belirtilmemiş' : '${entry.amount} kredi'}',
                  ),
              ]),
              error: (e, _) =>
                  FailureView(e, () => ref.invalidate(historyProvider)),
              loading: () => const LoadingView(),
            ),
      ),
    ),
  );
}

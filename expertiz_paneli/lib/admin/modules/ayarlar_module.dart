/// AYARLAR MODULE
///
/// Tema, yeni rapor uyarıları, şifre değiştirme ve sistem bilgileri.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yerimebak_sistemleri/tema/renkler.dart';
import 'package:yerimebak_sistemleri/bilesenler/bilesenler.dart';
import '../../core/widgets/sifre_degistir_dialog.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/yerimebak_expertiz_api_service.dart';
import '../services/admin_preferences.dart';
import '../widgets/hizmet_ayarlari.dart';

/// Ayarlar Module
class AyarlarModule extends StatefulWidget {
  const AyarlarModule({super.key, this.apiService});

  /// Testlerde sahte servis vermek için.
  final YerimebakExpertizApiService? apiService;

  @override
  State<AyarlarModule> createState() => _AyarlarModuleState();
}

class _AyarlarModuleState extends State<AyarlarModule> {
  late final YerimebakExpertizApiService _api;
  bool? _newReportAlerts;
  final _bolumAnahtarlari = <String, GlobalKey>{
    for (final ad in [
      'Görünüm',
      'Bildirimler',
      'Yerinde Ekspertiz',
      'Güvenlik',
      'Sistem Bilgileri'
    ])
      ad: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    AdminPreferences.newReportAlertsEnabled().then((value) {
      if (mounted) setState(() => _newReportAlerts = value);
    });
  }

  Future<void> _setNewReportAlerts(bool value) async {
    setState(() => _newReportAlerts = value);
    try {
      await AdminPreferences.setNewReportAlertsEnabled(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _newReportAlerts = !value);
      _showMessage('Ayar kaydedilemedi: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => SifreDegistirDialog(api: _api),
    );
    if (changed == true) _showMessage('Şifreniz değiştirildi');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = context.renkler.metin;
    final subColor = context.renkler.metinIkincil;
    final cardColor = context.renkler.yuzey;

    final icerik = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sistem Ayarları',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),

          // TEMA AYARLARI
          _section(
            'Görünüm',
            cardColor,
            textColor,
            [
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildThemeCard(
                      'Açık',
                      'Açık renk teması',
                      LucideIcons.sun,
                      context.renkler.yuzeyIkincil,
                      context.renkler.metin,
                      !isDarkMode,
                      () => themeProvider.setThemeMode(ThemeMode.light)),
                  _buildThemeCard(
                      'Koyu',
                      'Koyu renk teması',
                      LucideIcons.moon,
                      context.renkler.yuzeyIkincil,
                      context.renkler.metin,
                      isDarkMode,
                      () => themeProvider.setThemeMode(ThemeMode.dark)),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text('Cihaz temasını kullan',
                    style: TextStyle(color: textColor)),
                subtitle: Text('Sistemin aydınlık/koyu ayarını takip et',
                    style: TextStyle(color: subColor)),
                value: themeProvider.themeMode == ThemeMode.system,
                onChanged: (val) => themeProvider.setThemeMode(
                  val
                      ? ThemeMode.system
                      : (isDarkMode ? ThemeMode.dark : ThemeMode.light),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // BİLDİRİMLER
          _section(
            'Bildirimler',
            cardColor,
            textColor,
            [
              SwitchListTile(
                title: Text('Yeni rapor uyarıları',
                    style: TextStyle(color: textColor)),
                subtitle: Text(
                  'Bir rapor onay beklemeye düştüğünde ana sayfada uyarı ve titreşim göster',
                  style: TextStyle(color: subColor),
                ),
                value: _newReportAlerts ?? true,
                onChanged:
                    _newReportAlerts == null ? null : _setNewReportAlerts,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // YERİNDE EKSPERTİZ (037): hizmet bölgeleri ve kontrol merkezi — tıklanınca yüklenir
          _section(
            'Yerinde Ekspertiz',
            cardColor,
            textColor,
            [
              ListTile(
                key: const Key('ayar-hizmet-bolgeleri'),
                leading: Icon(LucideIcons.map, color: subColor),
                title: Text('Hizmet bölgeleri',
                    style: TextStyle(color: textColor)),
                subtitle: Text(
                    '81 il için Açık / Test / Kapalı (pilot: İstanbul)',
                    style: TextStyle(color: subColor)),
                trailing: Icon(LucideIcons.chevronRight,
                    color: context.renkler.metinIkincil),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => HizmetBolgeleriSayfasi(api: _api)),
                ),
              ),
              ListTile(
                key: const Key('ayar-kontrol-merkezi'),
                leading: Icon(LucideIcons.headset, color: subColor),
                title:
                    Text('Kontrol merkezi', style: TextStyle(color: textColor)),
                subtitle: Text(
                    'Saha personelinin aradığı telefon ve çalışma saatleri',
                    style: TextStyle(color: subColor)),
                trailing: Icon(LucideIcons.chevronRight,
                    color: context.renkler.metinIkincil),
                onTap: () async {
                  final kaydedildi = await kontrolMerkeziAyariAc(context, _api);
                  if (kaydedildi == true) {
                    _showMessage('Kontrol merkezi kaydedildi');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // GÜVENLİK
          _section(
            'Güvenlik',
            cardColor,
            textColor,
            [
              ListTile(
                leading: Icon(LucideIcons.lock, color: subColor),
                title:
                    Text('Şifre Değiştir', style: TextStyle(color: textColor)),
                subtitle: Text('Merkezi hesap şifrenizi güncelleyin',
                    style: TextStyle(color: subColor)),
                trailing: Icon(LucideIcons.chevronRight,
                    color: context.renkler.metinIkincil),
                onTap: _openChangePassword,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // SİSTEM BİLGİLERİ
          _section(
            'Sistem Bilgileri',
            cardColor,
            textColor,
            [
              ListTile(
                leading: Icon(LucideIcons.languages, color: subColor),
                title: Text('Dil', style: TextStyle(color: textColor)),
                subtitle: const Text('Türkçe'),
              ),
              ListTile(
                leading: Icon(LucideIcons.info, color: subColor),
                title: Text('Versiyon', style: TextStyle(color: textColor)),
                subtitle: const Text('v1.0.0'),
              ),
              ListTile(
                leading: Icon(LucideIcons.cloud, color: subColor),
                title: Text('Merkezi API', style: TextStyle(color: textColor)),
                subtitle: Text(_api.baseUrl),
              ),
            ],
          ),
        ],
      ),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 900) return icerik;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 204,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 16),
              child: Column(children: [
                for (final ad in _bolumAnahtarlari.keys)
                  ListTile(
                      title: Text(ad),
                      onTap: () {
                        final hedef = _bolumAnahtarlari[ad]?.currentContext;
                        if (hedef != null) {
                          Scrollable.ensureVisible(hedef,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180));
                        }
                      }),
              ]),
            )),
        Expanded(child: icerik),
      ]);
    });
  }

  Widget _section(
      String title, Color cardColor, Color? textColor, List<Widget> children) {
    return YbKart(
      key: _bolumAnahtarlari[title],
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Color foreground,
    bool selected,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 145,
        constraints: const BoxConstraints(minHeight: 145),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: selected
                  ? context.renkler.birincil
                  : context.renkler.kenarlik,
              width: selected ? 1.5 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: foreground),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: TextStyle(
                      color: foreground.withValues(alpha: 0.7), fontSize: 13),
                  textAlign: TextAlign.center),
              if (selected) ...[
                const SizedBox(height: 5),
                Icon(LucideIcons.circleCheck,
                    color: context.renkler.birincil, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mevcut + yeni şifre ile merkezi hesap şifresini değiştirir.

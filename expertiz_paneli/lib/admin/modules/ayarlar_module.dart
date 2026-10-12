/// AYARLAR MODULE
///
/// Tema, yeni rapor uyarıları, şifre değiştirme ve sistem bilgileri.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/yerimebak_expertiz_api_service.dart';
import '../services/admin_preferences.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _SifreDegistirDialog(api: _api),
    );
    if (changed == true) _showMessage('Şifreniz değiştirildi');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor = isDarkMode ? Colors.white : Colors.grey[800];
    final subColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sistem Ayarları', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),

          // TEMA AYARLARI
          _section(
            'Tema Ayarları',
            cardColor,
            textColor,
            [
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildThemeCard('☀️ Aydınlık Mod', 'Açık renk teması', Icons.light_mode, Colors.blue[100]!,
                      Colors.black, !isDarkMode, () => themeProvider.setThemeMode(ThemeMode.light)),
                  _buildThemeCard('🌙 Gece Modu', 'Koyu renk teması', Icons.dark_mode, Colors.grey[900]!,
                      Colors.white, isDarkMode, () => themeProvider.setThemeMode(ThemeMode.dark)),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text('Cihaz temasını kullan', style: TextStyle(color: textColor)),
                subtitle: Text('Sistemin aydınlık/koyu ayarını takip et', style: TextStyle(color: subColor)),
                value: themeProvider.themeMode == ThemeMode.system,
                onChanged: (val) => themeProvider.setThemeMode(
                  val ? ThemeMode.system : (isDarkMode ? ThemeMode.dark : ThemeMode.light),
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
                title: Text('Yeni rapor uyarıları', style: TextStyle(color: textColor)),
                subtitle: Text(
                  'Bir rapor onay beklemeye düştüğünde Dashboard\'da uyarı ve titreşim göster',
                  style: TextStyle(color: subColor),
                ),
                value: _newReportAlerts ?? true,
                onChanged: _newReportAlerts == null ? null : _setNewReportAlerts,
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
                leading: Icon(Icons.lock, color: subColor),
                title: Text('Şifre Değiştir', style: TextStyle(color: textColor)),
                subtitle: Text('Merkezi hesap şifrenizi güncelleyin', style: TextStyle(color: subColor)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
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
                leading: Icon(Icons.language, color: subColor),
                title: Text('Dil', style: TextStyle(color: textColor)),
                subtitle: const Text('Türkçe'),
              ),
              ListTile(
                leading: Icon(Icons.info, color: subColor),
                title: Text('Versiyon', style: TextStyle(color: textColor)),
                subtitle: const Text('v1.0.0'),
              ),
              ListTile(
                leading: Icon(Icons.cloud, color: subColor),
                title: Text('Merkezi API', style: TextStyle(color: textColor)),
                subtitle: Text(_api.baseUrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Color cardColor, Color? textColor, List<Widget> children) {
    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145,
        constraints: const BoxConstraints(minHeight: 145),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: selected ? Border.all(color: Colors.blue, width: 3) : null,
          boxShadow: selected ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10)] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: foreground),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(color: foreground, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 5),
              Text(subtitle,
                  style: TextStyle(color: foreground.withValues(alpha: 0.7), fontSize: 10),
                  textAlign: TextAlign.center),
              if (selected) ...[
                const SizedBox(height: 5),
                const Icon(Icons.check_circle, color: Colors.blue, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Mevcut + yeni şifre ile merkezi hesap şifresini değiştirir.
class _SifreDegistirDialog extends StatefulWidget {
  const _SifreDegistirDialog({required this.api});

  final YerimebakExpertizApiService api;

  @override
  State<_SifreDegistirDialog> createState() => _SifreDegistirDialogState();
}

class _SifreDegistirDialogState extends State<_SifreDegistirDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  /// Backend kuralıyla aynı: en az 8 karakter, büyük harf, küçük harf, rakam.
  static String? _validateNew(String? value) {
    final v = value ?? '';
    if (v.length < 8) return 'En az 8 karakter';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'En az bir büyük harf';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'En az bir küçük harf';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'En az bir rakam';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Şifre Değiştir'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut şifre'),
              validator: (v) => (v ?? '').isEmpty ? 'Zorunlu' : null,
            ),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni şifre'),
              validator: (v) {
                final error = _validateNew(v);
                if (error != null) return error;
                return v == _current.text ? 'Mevcut şifreden farklı olmalı' : null;
              },
            ),
            TextFormField(
              controller: _repeat,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
              validator: (v) => v != _new.text ? 'Şifreler eşleşmiyor' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Şifre değiştirme penceresi (admin Ayarlar ve personel paneli).
library;

import 'package:flutter/material.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

class SifreDegistirDialog extends StatefulWidget {
  const SifreDegistirDialog({super.key, required this.api, this.zorunlu = false});

  final YerimebakExpertizApiService api;

  /// İlk girişte geçici şifre: pencere kapatılamaz, "Vazgeç" yok.
  final bool zorunlu;

  @override
  State<SifreDegistirDialog> createState() => SifreDegistirDialogState();
}

class SifreDegistirDialogState extends State<SifreDegistirDialog> {
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
    final dialog = AlertDialog(
      title: Text(widget.zorunlu ? 'Geçici şifrenizi değiştirin' : 'Şifre Değiştir'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.zorunlu)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Güvenliğiniz için admin tarafından verilen geçici şifreyi kendi şifrenizle değiştirmeniz gerekiyor.'),
              ),
            TextFormField(
              key: const Key('currentPasswordField'),
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut şifre'),
              validator: (v) => (v ?? '').isEmpty ? 'Zorunlu' : null,
            ),
            TextFormField(
              key: const Key('newPasswordField'),
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
              key: const Key('repeatPasswordField'),
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
        if (!widget.zorunlu)
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
    return widget.zorunlu ? PopScope(canPop: false, child: dialog) : dialog;
  }
}

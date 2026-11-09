import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../bilesenler/bilesenler.dart';
import '../tema/renkler.dart';

/// Yönlendirme ve uygulama hatalarını ortak tema ile sunar.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.error, this.details});
  final String error;
  final String? details;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: YbKart(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(LucideIcons.circleAlert, size: 32, color: context.renkler.tehlike),
        const SizedBox(height: 16),
        Text('Bir hata oluştu', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(error, textAlign: TextAlign.center, style: TextStyle(color: context.renkler.metinIkincil)),
        if (details != null) ...[
          const SizedBox(height: 16),
          SelectableText(details!, style: TextStyle(color: context.renkler.metinGovde)),
        ],
        const SizedBox(height: 24),
        YbButon(metin: 'Ana Sayfaya Dön', ikon: LucideIcons.house, onPressed: () => context.go('/')),
      ])),
    ))),
  );
}

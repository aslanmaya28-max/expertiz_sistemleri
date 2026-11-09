import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Yerinde ekspertiz talebi artık yalnız müşteri sitesinden (ve Android uygulamasından) açılır (037).
///
/// Talep formu il durumu, randevu (tarih-saat, adres, satıcı) ve "araç adreste yoksa paket iadesi"
/// onayı ister; bu eski panel formu bu alanları içermediği için sunucu reddeder. Ekran siteye yönlendirir.
const String kEkspertizTalepAdresi = 'https://www.yerimebak.com.tr/ekspertiz-talebi';

class CreateRequestScreen extends StatelessWidget {
  const CreateRequestScreen({super.key, this.baglantiAc});

  /// Testlerde bağlantıyı yakalamak için.
  final Future<bool> Function(Uri uri)? baglantiAc;

  Future<void> _ac(BuildContext context) async {
    final uri = Uri.parse(kEkspertizTalepAdresi);
    bool acildi;
    try {
      acildi = await (baglantiAc?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank'));
    } catch (_) {
      acildi = false;
    }
    if (!acildi && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sayfa açılamadı. Tarayıcıda $kEkspertizTalepAdresi adresini açın.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yerinde ekspertiz talebi')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available, size: 48),
                  const SizedBox(height: 12),
                  Text('Talebinizi web sitemizden oluşturun',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Randevu saati, aracın adresi ve satıcı bilgisiyle talep oluşturma ve ödeme '
                    'yerimebak.com.tr üzerinden yapılır. Talebinizin durumu burada da görünmeye devam eder.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('ekspertiz-talebi-siteye-git'),
                    onPressed: () => _ac(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Talep sayfasını aç'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';
import 'acilir_liste.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';

typedef LinkAction = Future<void> Function(String url);
bool safeWeb(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      ['https', 'http'].contains(uri.scheme) &&
      uri.hasAuthority &&
      uri.userInfo.isEmpty;
}

class SourceLinks extends StatelessWidget {
  final List<String> urls;
  final LinkAction onLink;
  const SourceLinks(this.urls, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) => AcilirListe(
    children: [
      for (final url in urls.where(safeWeb))
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(Olcu.ikincilButon, Olcu.ikincilButon),
          ),
          onPressed: () async {
            try {
              await onLink(url);
            } catch (e) {
              if (context.mounted) showMessage(context, e.toString());
            }
          },
          child: Text(Uri.parse(url).host),
        ),
    ],
  );
}

class ListingEvidence extends StatelessWidget {
  final List<Json> listings;
  final LinkAction onLink;
  const ListingEvidence(this.listings, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) => AcilirListe(
    children: [
      for (final item in listings)
        Container(
          margin: const EdgeInsets.only(bottom: Olcu.s8),
          padding: const EdgeInsets.all(Olcu.s12),
          decoration: BoxDecoration(
            color: YbRenkler.of(context).yuzey,
            border: Border.all(color: YbRenkler.of(context).raporKenar),
            borderRadius: BorderRadius.circular(Olcu.butonKose),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueLine(
                text(item['site']).isEmpty ? 'Kaynak ilan' : text(item['site']),
                '${item['yil'] ?? 'Yıl belirtilmemiş'} • ${item['km'] == null ? 'Km belirtilmemiş' : '${number(item['km'])} km'} • ${money(item['fiyat'])}',
              ),
              if (item['duzeltilmisFiyat'] != null &&
                  item['duzeltilmisFiyat'] != item['fiyat'])
                ValueLine('Bu araca göre', money(item['duzeltilmisFiyat'])),
              SourceLinks([text(item['url'])], onLink),
            ],
          ),
        ),
    ],
  );
}

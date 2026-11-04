import 'package:flutter/material.dart';
import '../api/models.dart';
import 'ortak.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final url in urls.where(safeWeb))
        TextButton(
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in listings)
        Column(
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
    ],
  );
}

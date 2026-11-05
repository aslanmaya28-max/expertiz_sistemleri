import 'package:flutter/material.dart';
import '../api/models.dart';
import '../tema/olculer.dart';
import 'ortak.dart';
import 'acilir_liste.dart';
import 'rapor_kaynaklar.dart';

const _groups = {
  'mekanik_motor': 'Mekanik ve motor',
  'elektronik': 'Elektronik ve sensör',
  'trim_kasa': 'Trim, şasi ve kasa',
};
const _priority = {'yuksek': 0, 'orta': 1, 'dusuk': 2};
List<Widget> _grouped(List<Json> entries, Widget Function(Json) child) {
  if (!entries.every((r) => _groups.containsKey(r['kategori']))) {
    return entries.map(child).toList();
  }
  return [
    for (final key in _groups.keys)
      if (entries.any((e) => e['kategori'] == key)) ...[
        Text(_groups[key]!),
        ...(entries.where((r) => r['kategori'] == key).toList()..sort(
              (a, b) => (_priority[a['onem']] ?? 3).compareTo(
                _priority[b['onem']] ?? 3,
              ),
            ))
            .map(child),
      ],
  ];
}

class ModelFindings extends StatelessWidget {
  final ReportSnapshot snapshot;
  final LinkAction onLink;
  const ModelFindings(this.snapshot, this.onLink, {super.key});
  @override
  Widget build(BuildContext context) {
    final raw = snapshot.raw, model = object(raw['modelRiskleri']);
    final risks = objects(
      model['riskler'],
    ).where((r) => ['yuksek', 'orta'].contains(r['guven'])).toList();
    final complaints = objects(raw['kullaniciSikayetleri']);
    final critical = [
      ...risks.where((r) => r['onem'] == 'yuksek'),
      ...(complaints.where((r) => r['onem'] == 'yuksek').toList()..sort(
        (a, b) =>
            integer(b['kaynakSayisi']).compareTo(integer(a['kaynakSayisi'])),
      )),
    ].take(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (critical.isNotEmpty)
          Panel('Bu araçta en çok dikkat etmeniz gerekenler', [
            BulletList(critical.map((r) => text(r['baslik'])).toList()),
          ]),
        if (raw['modelRiskleri'] is Map)
          Panel('Modelin bilinen sorunları', [
            const Text(
              'Arıza teşhisi değildir; araç sürümü, şasi numarası ve servis kayıtlarıyla doğrulayın.',
            ),
            if (risks.isEmpty)
              Text(
                text(model['mesaj']).isEmpty
                    ? 'Bu model/motor için kaynağı doğrulanmış bilinen sorun bulunamadı.'
                    : text(model['mesaj']),
              ),
            AcilirListe(
              children: _grouped(
                risks,
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: Olcu.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text(r['baslik']),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (r['onem'] != null)
                        Text('Önem: ${_importance(r['onem'])}'),
                      if (r['guven'] == 'yuksek') const Text('Resmî kaynak'),
                      if (text(r['aciklama']).isNotEmpty)
                        Text(text(r['aciklama'])),
                      if (text(r['etkiledigi']).isNotEmpty)
                        ValueLine('Kimleri etkiler', text(r['etkiledigi'])),
                      if (strings(r['belirtiler']).isNotEmpty)
                        ValueLine(
                          'Belirtiler',
                          strings(r['belirtiler']).join('; '),
                        ),
                      ValueLine('Nasıl kontrol edilir', text(r['kontrol'])),
                      ValueLine(
                        'Tahmini masraf',
                        r['tahminiMaliyet'] is Map
                            ? '${money(object(r['tahminiMaliyet'])['min'])} – ${money(object(r['tahminiMaliyet'])['max'])}'
                            : 'Kaynakta belirtilmemiş',
                      ),
                      SourceLinks(strings(r['kaynaklar']), onLink),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        if (raw.containsKey('kullaniciSikayetleri'))
          Panel('Kullanıcıların en sık şikâyet ettiği konular', [
            const Text(
              'Forum ve kullanıcı yorumlarından derlenmiştir; kullanıcı beyanıdır, arıza teşhisi değildir.',
            ),
            if (complaints.isEmpty)
              const Text(
                'Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.',
              ),
            AcilirListe(
              children: _grouped(
                complaints,
                (r) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text(r['baslik']),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (r['onem'] != null)
                      Text('Önem: ${_importance(r['onem'])}'),
                    Text(text(r['aciklama'])),
                    Text(
                      '${integer(r['kaynakSayisi'])} farklı kaynakta geçiyor',
                    ),
                    SourceLinks(strings(r['kaynaklar']), onLink),
                  ],
                ),
              ),
            ),
          ]),
        if (objects(raw['bakim']).isNotEmpty)
          Panel('Bu kilometrede doğrulanacak bakımlar', [
            Text(
              '${number(snapshot.vehicle['km'])} km ve ${snapshot.vehicle['yil'] ?? '—'} model araç için işlemlerin son yapıldığı tarih ve kilometreyi servis faturalarından kontrol edin; üreticinin araç sürümüne özel bakım planını esas alın.',
            ),
            BulletList(
              objects(raw['bakim'])
                  .map(
                    (r) =>
                        '${text(r['baslik'])}${text(r['kontrol']).isNotEmpty && r['kontrol'] != 'Tarih, kilometre ve servis faturalarını karşılaştırın.' ? ' (kontrol: ${r['kontrol']})' : ''}',
                  )
                  .toList(),
            ),
          ]),
        if (strings(raw['saticiSorulari']).isNotEmpty)
          Panel('Satıcıya sorulacak sorular', [
            BulletList(strings(raw['saticiSorulari'])),
          ]),
      ],
    );
  }

  String _importance(dynamic value) =>
      const {'yuksek': 'Yüksek', 'orta': 'Orta', 'dusuk': 'Düşük'}[value] ??
      text(value);
}

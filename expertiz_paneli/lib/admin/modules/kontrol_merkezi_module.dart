/// KONTROL MERKEZİ MODULE (037; kullanıcı kararı 9 Kasım 2026)
///
/// Saha personeli müşteriye ya da satıcıya doğrudan bağlanmaz; yalnız kontrol merkezine bağlanır.
/// Müşteri ve satıcıyla bağlantıyı bu ekrandan kontrol merkezi kurar: açık görevler randevu saatine göre,
/// her birinde Müşteriyi / Satıcıyı / Personeli ara ve arama sonucu kaydı. Veri:
/// `GET /expertiz/admin/control-center/tasks`, `POST|GET /expertiz/admin/requests/{id}/contact-log`.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../tema/renkler.dart';
import '../../bilesenler/bilesenler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

typedef TelefonAcici = Future<bool> Function(Uri uri);

const _sonucEtiketleri = {
  'ulasildi': 'Ulaşıldı',
  'ulasilamadi': 'Ulaşılamadı',
  'mesaj_birakildi': 'Mesaj bırakıldı',
  'baglandi': 'Personelle bağlandı',
};
const _hedefEtiketleri = {
  'musteri': 'Müşteri',
  'satici': 'Satıcı',
  'personel': 'Personel',
  'kontrol_merkezi': 'Saha notu',
};
// Personel yola çıktıysa randevu yaklaşması uyarı sayılmaz.
const _yoldaVeSonrasi = {
  'on_the_way',
  'at_vehicle',
  'at_corporate',
  'in_progress',
  'submitted'
};

class KontrolMerkeziModule extends StatefulWidget {
  const KontrolMerkeziModule(
      {super.key, this.apiService, this.telefonAc, this.simdi});

  final YerimebakExpertizApiService? apiService;

  /// Testlerde `tel:` bağlantısını taklit etmek için.
  final TelefonAcici? telefonAc;

  /// Testlerde saati sabitlemek için (İstanbul saati).
  final DateTime Function()? simdi;

  @override
  State<KontrolMerkeziModule> createState() => _KontrolMerkeziModuleState();
}

class _KontrolMerkeziModuleState extends State<KontrolMerkeziModule> {
  late final YerimebakExpertizApiService _api;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _ayarlar = const {};
  List<Map<String, dynamic>> _gorevler = const [];
  String _arama = '';
  bool _yalnizAcil = false;
  int _sayfa = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final yanit = await _api.getControlCenterTasks();
      if (!mounted) return;
      setState(() {
        _ayarlar =
            Map<String, dynamic>.from(yanit['ayarlar'] as Map? ?? const {});
        _gorevler = (yanit['gorevler'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  DateTime _istanbulSimdi() {
    if (widget.simdi != null) return widget.simdi!();
    // İstanbul UTC+3 (yaz saati yok).
    final utc = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
  }

  static DateTime? _randevuZamani(Map<String, dynamic> gorev) {
    final metin = (gorev['randevu'] as Map?)?['tarih_saat']?.toString() ?? '';
    return DateTime.tryParse(metin);
  }

  static String _iki(int n) => n.toString().padLeft(2, '0');

  static String randevuMetni(Map<String, dynamic> gorev) {
    final zaman = _randevuZamani(gorev);
    if (zaman == null) return 'Randevu yok';
    return '${_iki(zaman.day)}.${_iki(zaman.month)}.${zaman.year} ${_iki(zaman.hour)}:${_iki(zaman.minute)}';
  }

  bool _gecikmeRiski(Map<String, dynamic> gorev) {
    final zaman = _randevuZamani(gorev);
    if (zaman == null) return false;
    final kalan = zaman.difference(_istanbulSimdi());
    return kalan.inMinutes < 60 &&
        !_yoldaVeSonrasi.contains(gorev['stage']?.toString());
  }

  Future<void> _ara(
      Map<String, dynamic> gorev, String hedef, String telefon) async {
    final ac = widget.telefonAc ?? (uri) => launchUrl(uri);
    await ac(Uri(scheme: 'tel', path: telefon));
    if (!mounted) return;
    await _sonucKaydet(gorev, hedef);
  }

  Future<void> _sonucKaydet(Map<String, dynamic> gorev, String hedef) async {
    var sonuc = 'ulasildi';
    final notController = TextEditingController();
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => YbDiyalog(
          baslik: '${_hedefEtiketleri[hedef]} araması — sonuç',
          eylemler: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Kaydet')),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: sonuc,
                onChanged: (v) => setDialogState(() => sonuc = v ?? sonuc),
                child: Column(
                  children: [
                    for (final e in _sonucEtiketleri.entries)
                      RadioListTile<String>(
                          value: e.key, title: Text(e.value), dense: true),
                  ],
                ),
              ),
              TextField(
                controller: notController,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Not (isteğe bağlı)'),
              ),
            ],
          ),
        ),
      ),
    );
    if (kaydet != true) return;
    try {
      await _api.addContactLog(gorev['id'].toString(),
          target: hedef, result: sonuc, note: notController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Arama kaydedildi')));
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _gecmis(Map<String, dynamic> gorev) async {
    List<Map<String, dynamic>> kayitlar = const [];
    String? hata;
    try {
      final yanit = await _api.getContactLog(gorev['id'].toString());
      kayitlar = (yanit['kayitlar'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      hata = e.toString();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => YbDiyalog(
        baslik: 'İletişim geçmişi',
        eylemler: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text('Kapat'))
        ],
        child: SizedBox(
          width: 420,
          child: hata != null
              ? Text(hata)
              : kayitlar.isEmpty
                  ? Text('Henüz kayıt yok.')
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final k in kayitlar)
                          ListTile(
                            dense: true,
                            title: Text(
                                '${_hedefEtiketleri[k['hedef']] ?? k['hedef']} · '
                                '${_sonucEtiketleri[k['sonuc']] ?? (k['sonuc'] == 'not' ? 'Not' : k['sonuc'])}'),
                            subtitle: Text([
                              if ((k['note'] ?? '').toString().isNotEmpty)
                                k['note'].toString(),
                              '${k['actor_name'] ?? ''} · ${k['created_at'] ?? ''}',
                            ].join('\n')),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ListView(padding: const EdgeInsets.all(20), children: const [
        YbIskelet(height: 100),
        SizedBox(height: 12),
        YbIskelet(height: 100)
      ]);
    }
    if (_error != null) {
      return YbBosDurum(
          mesaj: _error!, eylem: 'Tekrar dene', onPressed: _yukle);
    }
    final telefon = _ayarlar['telefon']?.toString() ?? '';
    final gorunen = _gorevler.where((gorev) {
      if (_yalnizAcil && !_gecikmeRiski(gorev)) return false;
      return _arama.trim().isEmpty ||
          gorev.toString().toLowerCase().contains(_arama.trim().toLowerCase());
    }).toList()
      ..sort((a, b) {
        final first = _randevuZamani(a);
        final second = _randevuZamani(b);
        if (first == null) return second == null ? 0 : 1;
        return second == null ? -1 : first.compareTo(second);
      });
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Kontrol merkezi',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 4),
          Text(
            telefon.isEmpty
                ? 'Kontrol merkezi numarası girilmedi: saha personelinin "Kontrol merkezini ara" düğmesi pasif. Ayarlar → Kontrol merkezi.'
                : 'Saha personeli bu numarayı arar: $telefon'
                    '${(_ayarlar['calisma_saatleri'] ?? '').toString().isEmpty ? '' : ' · ${_ayarlar['calisma_saatleri']}'}',
            key: const Key('kontrol-merkezi-numara'),
            style: TextStyle(
                color: telefon.isEmpty ? context.renkler.uyari : null),
          ),
          SizedBox(height: 4),
          Text(
              'Personel müşteriye ya da satıcıya doğrudan bağlanmaz; bağlantıyı buradan siz kurarsınız.'),
          SizedBox(height: 16),
          YbArama(
              ipucu: 'Araç, müşteri, firma veya personel ara',
              onChanged: (value) => setState(() => _arama = value)),
          const SizedBox(height: 12),
          Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                    label: const Text('1 saatten az kaldı'),
                    selected: _yalnizAcil,
                    onSelected: (value) => setState(() => _yalnizAcil = value)),
                Text('${gorunen.length} açık görev · Randevu saatine göre',
                    style: TextStyle(color: context.renkler.metinIkincil)),
                IconButton(
                    tooltip: 'Yenile',
                    onPressed: _yukle,
                    icon: const Icon(LucideIcons.refreshCw)),
              ]),
          const SizedBox(height: 16),
          if (gorunen.isEmpty)
            YbBosDurum(
                mesaj: _gorevler.isEmpty
                    ? 'Açık görev yok.'
                    : 'Süzgece uyan görev yok.'),
          if (gorunen.isNotEmpty)
            LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth >= 1000
                    ? _gorevTablosu(gorunen)
                    : Column(children: [
                        for (final gorev in gorunen) _gorevKarti(gorev)
                      ])),
        ],
      ),
    );
  }

  Widget _gorevTablosu(List<Map<String, dynamic>> gorevler) => YbTablo(
        sayfa: _sayfa,
        onPageChanged: (value) => setState(() => _sayfa = value),
        columns: const [
          DataColumn(label: Text('Randevu')),
          DataColumn(label: Text('Araç / konum')),
          DataColumn(label: Text('Firma / personel')),
          DataColumn(label: Text('Durum')),
          DataColumn(label: Text('İletişim')),
          DataColumn(label: Text('Ayrıntı')),
        ],
        rows: gorevler.map((gorev) {
          final arac = gorev['vehicle'] as Map? ?? const {};
          final atama = gorev['assignment'] as Map? ?? const {};
          final musteri = gorev['customer'] as Map? ?? const {};
          final randevu = gorev['randevu'] as Map? ?? const {};
          final risk = _gecikmeRiski(gorev);
          return DataRow(cells: [
            DataCell(Text(randevuMetni(gorev))),
            DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((arac['title'] ?? 'Araç').toString()),
                  Text('${gorev['city'] ?? ''} / ${gorev['district'] ?? ''}',
                      style: TextStyle(color: context.renkler.metinIkincil)),
                ])),
            DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((gorev['firm_name'] ?? '-').toString()),
                  Text((atama['personnel_name'] ?? 'Atanmadı').toString(),
                      style: TextStyle(color: context.renkler.metinIkincil)),
                ])),
            DataCell(Tooltip(
              message: risk
                  ? 'Randevuya 1 saatten az kaldı, personel yola çıkmadı'
                  : '',
              child: YbRozet(
                  risk
                      ? '1 saatten az kaldı'
                      : (gorev['stage_label'] ?? gorev['stage'] ?? '')
                          .toString(),
                  tur: risk ? YbRozetTuru.uyari : YbRozetTuru.bilgi),
            )),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              for (final (hedef, etiket, telefon) in <(String, String, String)>[
                (
                  'musteri',
                  'Müşteriyi ara',
                  (musteri['phone'] ?? '').toString()
                ),
                (
                  'satici',
                  'Satıcıyı ara',
                  (randevu['satici_telefon'] ?? '').toString()
                ),
                (
                  'personel',
                  'Personeli ara',
                  (atama['personnel_phone'] ?? '').toString()
                ),
              ])
                Tooltip(
                    message: etiket,
                    child: TextButton(
                      key: Key('ara-$hedef-${gorev['id']}'),
                      onPressed: telefon.isEmpty
                          ? null
                          : () => _ara(gorev, hedef, telefon),
                      style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero),
                      child: Icon(
                          hedef == 'musteri'
                              ? LucideIcons.user
                              : hedef == 'satici'
                                  ? LucideIcons.phone
                                  : LucideIcons.headset,
                          size: 20),
                    )),
            ])),
            DataCell(IconButton(
                tooltip: 'Görev ayrıntısı',
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                          alignment: Alignment.centerRight,
                          insetPadding: const EdgeInsets.all(20),
                          child: SizedBox(
                              width: 480,
                              child: SingleChildScrollView(
                                  child: _gorevKarti(gorev)))),
                    ))),
          ]);
        }).toList(),
      );

  Widget _gorevKarti(Map<String, dynamic> gorev) {
    final musteri =
        Map<String, dynamic>.from(gorev['customer'] as Map? ?? const {});
    final randevu =
        Map<String, dynamic>.from(gorev['randevu'] as Map? ?? const {});
    final atama =
        Map<String, dynamic>.from(gorev['assignment'] as Map? ?? const {});
    final arac =
        Map<String, dynamic>.from(gorev['vehicle'] as Map? ?? const {});
    final son = gorev['son_iletisim'] is Map
        ? Map<String, dynamic>.from(gorev['son_iletisim'] as Map)
        : null;
    final risk = _gecikmeRiski(gorev);
    final dugmeler = <(String, String, String)>[
      ('musteri', 'Müşteriyi ara', musteri['phone']?.toString() ?? ''),
      ('satici', 'Satıcıyı ara', randevu['satici_telefon']?.toString() ?? ''),
      ('personel', 'Personeli ara', atama['personnel_phone']?.toString() ?? ''),
    ];
    return YbKart(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      key: Key('kontrol-gorev-${gorev['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(randevuMetni(gorev),
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(arac['title']?.toString() ?? 'Araç'),
                  YbRozet(
                      gorev['stage_label']?.toString() ??
                          gorev['stage']?.toString() ??
                          '',
                      tur: YbRozetTuru.bilgi),
                  if (risk)
                    const YbRozet(
                        'Randevuya 1 saatten az kaldı, personel yola çıkmadı',
                        tur: YbRozetTuru.uyari),
                  if (gorev['durum_kodu'] == 'vehicle_not_found')
                    const YbRozet('Araç adreste bulunamadı',
                        tur: YbRozetTuru.uyari),
                ]),
            SizedBox(height: 6),
            Text([
              randevu['adres'],
              '${gorev['city'] ?? ''} / ${gorev['district'] ?? ''}'
            ].where((e) => (e ?? '').toString().trim().isNotEmpty).join(' · ')),
            Text(
                'Müşteri: ${musteri['name'] ?? '-'} · Satıcı: ${randevu['satici_adi']?.toString().isNotEmpty == true ? randevu['satici_adi'] : '-'}'),
            Text(
                'Firma: ${gorev['firm_name'] ?? '-'} · Personel: ${atama['personnel_name']?.toString().isNotEmpty == true ? atama['personnel_name'] : 'atanmadı'}'),
            if (son != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Son iletişim: ${_hedefEtiketleri[son['hedef']] ?? son['hedef']} · '
                  '${_sonucEtiketleri[son['sonuc']] ?? (son['sonuc'] == 'not' ? 'Not' : son['sonuc'])}'
                  '${(son['note'] ?? '').toString().isEmpty ? '' : ' — ${son['note']}'}',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (hedef, etiket, telefon) in dugmeler)
                FilledButton.tonalIcon(
                  key: Key('ara-$hedef-${gorev['id']}'),
                  onPressed: telefon.isEmpty
                      ? null
                      : () => _ara(gorev, hedef, telefon),
                  icon: Icon(LucideIcons.phone),
                  label: Text(etiket),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              OutlinedButton.icon(
                onPressed: () => _gecmis(gorev),
                icon: Icon(LucideIcons.history),
                label: Text('Geçmiş'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

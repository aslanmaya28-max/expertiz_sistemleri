/// KONTROL MERKEZİ MODULE (037; kullanıcı kararı 9 Kasım 2026)
///
/// Saha personeli müşteriye ya da satıcıya doğrudan bağlanmaz; yalnız kontrol merkezine bağlanır.
/// Müşteri ve satıcıyla bağlantıyı bu ekrandan kontrol merkezi kurar: açık görevler randevu saatine göre,
/// her birinde Müşteriyi / Satıcıyı / Personeli ara ve arama sonucu kaydı. Veri:
/// `GET /expertiz/admin/control-center/tasks`, `POST|GET /expertiz/admin/requests/{id}/contact-log`.
library;

import 'package:flutter/material.dart';
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
const _yoldaVeSonrasi = {'on_the_way', 'at_vehicle', 'at_corporate', 'in_progress', 'submitted'};

class KontrolMerkeziModule extends StatefulWidget {
  const KontrolMerkeziModule({super.key, this.apiService, this.telefonAc, this.simdi});

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
        _ayarlar = Map<String, dynamic>.from(yanit['ayarlar'] as Map? ?? const {});
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
    return kalan.inMinutes < 60 && !_yoldaVeSonrasi.contains(gorev['stage']?.toString());
  }

  Future<void> _ara(Map<String, dynamic> gorev, String hedef, String telefon) async {
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
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_hedefEtiketleri[hedef]} araması — sonuç'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: sonuc,
                onChanged: (v) => setDialogState(() => sonuc = v ?? sonuc),
                child: Column(
                  children: [
                    for (final e in _sonucEtiketleri.entries)
                      RadioListTile<String>(value: e.key, title: Text(e.value), dense: true),
                  ],
                ),
              ),
              TextField(
                controller: notController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (kaydet != true) return;
    try {
      await _api.addContactLog(gorev['id'].toString(), target: hedef, result: sonuc, note: notController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arama kaydedildi')));
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _gecmis(Map<String, dynamic> gorev) async {
    List<Map<String, dynamic>> kayitlar = const [];
    String? hata;
    try {
      final yanit = await _api.getContactLog(gorev['id'].toString());
      kayitlar = (yanit['kayitlar'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      hata = e.toString();
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İletişim geçmişi'),
        content: SizedBox(
          width: 420,
          child: hata != null
              ? Text(hata)
              : kayitlar.isEmpty
                  ? const Text('Henüz kayıt yok.')
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final k in kayitlar)
                          ListTile(
                            dense: true,
                            title: Text('${_hedefEtiketleri[k['hedef']] ?? k['hedef']} · '
                                '${_sonucEtiketleri[k['sonuc']] ?? (k['sonuc'] == 'not' ? 'Not' : k['sonuc'])}'),
                            subtitle: Text([
                              if ((k['note'] ?? '').toString().isNotEmpty) k['note'].toString(),
                              '${k['actor_name'] ?? ''} · ${k['created_at'] ?? ''}',
                            ].join('\n')),
                          ),
                      ],
                    ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
        ]),
      );
    }
    final telefon = _ayarlar['telefon']?.toString() ?? '';
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Kontrol merkezi', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            telefon.isEmpty
                ? 'Kontrol merkezi numarası girilmedi: saha personelinin "Kontrol merkezini ara" düğmesi pasif. Ayarlar → Kontrol merkezi.'
                : 'Saha personeli bu numarayı arar: $telefon'
                    '${(_ayarlar['calisma_saatleri'] ?? '').toString().isEmpty ? '' : ' · ${_ayarlar['calisma_saatleri']}'}',
            key: const Key('kontrol-merkezi-numara'),
            style: TextStyle(color: telefon.isEmpty ? Colors.deepOrange : null),
          ),
          const SizedBox(height: 4),
          const Text('Personel müşteriye ya da satıcıya doğrudan bağlanmaz; bağlantıyı buradan siz kurarsınız.'),
          const SizedBox(height: 16),
          if (_gorevler.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Açık görev yok.'))),
          for (final gorev in _gorevler) _gorevKarti(gorev),
        ],
      ),
    );
  }

  Widget _gorevKarti(Map<String, dynamic> gorev) {
    final musteri = Map<String, dynamic>.from(gorev['customer'] as Map? ?? const {});
    final randevu = Map<String, dynamic>.from(gorev['randevu'] as Map? ?? const {});
    final atama = Map<String, dynamic>.from(gorev['assignment'] as Map? ?? const {});
    final arac = Map<String, dynamic>.from(gorev['vehicle'] as Map? ?? const {});
    final son = gorev['son_iletisim'] is Map ? Map<String, dynamic>.from(gorev['son_iletisim'] as Map) : null;
    final risk = _gecikmeRiski(gorev);
    final dugmeler = <(String, String, String)>[
      ('musteri', 'Müşteriyi ara', musteri['phone']?.toString() ?? ''),
      ('satici', 'Satıcıyı ara', randevu['satici_telefon']?.toString() ?? ''),
      ('personel', 'Personeli ara', atama['personnel_phone']?.toString() ?? ''),
    ];
    return Card(
      key: Key('kontrol-gorev-${gorev['id']}'),
      color: risk ? Colors.orange.shade50 : null,
      shape: risk
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange.shade700, width: 1.5))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(randevuMetni(gorev), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Text(arac['title']?.toString() ?? 'Araç'),
              Chip(label: Text(gorev['stage_label']?.toString() ?? gorev['stage']?.toString() ?? '')),
              if (risk)
                Text('Randevuya 1 saatten az kaldı, personel yola çıkmadı',
                    style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
              if (gorev['durum_kodu'] == 'vehicle_not_found')
                const Text('Araç adreste bulunamadı', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            Text([randevu['adres'], '${gorev['city'] ?? ''} / ${gorev['district'] ?? ''}']
                .where((e) => (e ?? '').toString().trim().isNotEmpty)
                .join(' · ')),
            Text('Müşteri: ${musteri['name'] ?? '-'} · Satıcı: ${randevu['satici_adi']?.toString().isNotEmpty == true ? randevu['satici_adi'] : '-'}'),
            Text('Firma: ${gorev['firm_name'] ?? '-'} · Personel: ${atama['personnel_name']?.toString().isNotEmpty == true ? atama['personnel_name'] : 'atanmadı'}'),
            if (son != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Son iletişim: ${_hedefEtiketleri[son['hedef']] ?? son['hedef']} · '
                  '${_sonucEtiketleri[son['sonuc']] ?? (son['sonuc'] == 'not' ? 'Not' : son['sonuc'])}'
                  '${(son['note'] ?? '').toString().isEmpty ? '' : ' — ${son['note']}'}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (hedef, etiket, telefon) in dugmeler)
                FilledButton.tonalIcon(
                  key: Key('ara-$hedef-${gorev['id']}'),
                  onPressed: telefon.isEmpty ? null : () => _ara(gorev, hedef, telefon),
                  icon: const Icon(Icons.call),
                  label: Text(etiket),
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              OutlinedButton.icon(
                onPressed: () => _gecmis(gorev),
                icon: const Icon(Icons.history),
                label: const Text('Geçmiş'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

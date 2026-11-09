/// Yerinde ekspertiz ayarları (037; sözleşme 2026-11-09): hizmet bölgeleri ve kontrol merkezi.
library;

import 'package:flutter/material.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

const durumEtiketleri = {'acik': 'Açık', 'test': 'Test', 'kapali': 'Kapalı'};

/// Kontrol merkezi telefonu ve çalışma saatleri penceresi. Kaydedilirse true döner.
Future<bool?> kontrolMerkeziAyariAc(BuildContext context, YerimebakExpertizApiService api) {
  return showDialog<bool>(context: context, builder: (_) => _KontrolMerkeziAyari(api: api));
}

class _KontrolMerkeziAyari extends StatefulWidget {
  const _KontrolMerkeziAyari({required this.api});
  final YerimebakExpertizApiService api;

  @override
  State<_KontrolMerkeziAyari> createState() => _KontrolMerkeziAyariState();
}

class _KontrolMerkeziAyariState extends State<_KontrolMerkeziAyari> {
  final _telefon = TextEditingController();
  final _saatler = TextEditingController();
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    widget.api.getControlCenter().then((a) {
      if (!mounted) return;
      setState(() {
        _telefon.text = a['telefon']?.toString() ?? '';
        _saatler.text = a['calisma_saatleri']?.toString() ?? '';
        _yukleniyor = false;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _yukleniyor = false);
    });
  }

  @override
  void dispose() {
    _telefon.dispose();
    _saatler.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      await widget.api.updateControlCenter(phone: _telefon.text, hours: _saatler.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kontrol merkezi'),
      content: _yukleniyor
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Saha personeli müşteriye ya da satıcıya doğrudan bağlanmaz; bu numarayı arar.'),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefon,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Kontrol merkezi telefonu', hintText: '0850 … ya da 05xx …'),
                ),
                TextField(
                  controller: _saatler,
                  decoration: const InputDecoration(labelText: 'Çalışma saatleri', hintText: 'Her gün 08.00–20.00'),
                ),
                if (_hata != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hata!, style: const TextStyle(color: Colors.red))),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: _yukleniyor || _kaydediliyor ? null : _kaydet, child: const Text('Kaydet')),
      ],
    );
  }
}

/// 81 il için hizmet durumu: Açık (herkes), Test (yönetici ve test kullanıcısı), Kapalı.
class HizmetBolgeleriSayfasi extends StatefulWidget {
  const HizmetBolgeleriSayfasi({super.key, required this.api});
  final YerimebakExpertizApiService api;

  @override
  State<HizmetBolgeleriSayfasi> createState() => _HizmetBolgeleriSayfasiState();
}

class _HizmetBolgeleriSayfasiState extends State<HizmetBolgeleriSayfasi> {
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  String? _hata;
  String _arama = '';
  String _pilot = 'İstanbul';
  Map<String, String> _kayitli = {};
  Map<String, String> _durum = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final yanit = await widget.api.getServiceArea();
      final iller = <String, String>{
        for (final c in (yanit['cities'] as List? ?? const []).whereType<Map>())
          c['il'].toString(): c['durum']?.toString() ?? 'kapali',
      };
      if (!mounted) return;
      setState(() {
        _pilot = yanit['pilot']?.toString() ?? _pilot;
        _kayitli = Map.of(iller);
        _durum = Map.of(iller);
        _yukleniyor = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = e.toString();
          _yukleniyor = false;
        });
      }
    }
  }

  Map<String, String> get _degisenler =>
      {for (final e in _durum.entries) if (_kayitli[e.key] != e.value) e.key: e.value};

  Future<void> _kaydet() async {
    final degisen = _degisenler;
    if (degisen.isEmpty) return;
    final acilan = degisen.entries.where((e) => e.value == 'acik').map((e) => e.key).toList();
    if (acilan.isNotEmpty) {
      final onay = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hizmeti aç'),
          content: Text('${acilan.join(', ')}: Bu ildeki herkes talep ve ödeme yapabilir. Devam edilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aç')),
          ],
        ),
      );
      if (onay != true) return;
    }
    setState(() => _kaydediliyor = true);
    try {
      await widget.api.updateServiceArea([for (final e in degisen.entries) {'il': e.key, 'durum': e.value}]);
      if (!mounted) return;
      setState(() => _kayitli = Map.of(_durum));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet bölgeleri kaydedildi')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sayilar = {for (final d in durumEtiketleri.keys) d: _durum.values.where((v) => v == d).length};
    final gorunen = _durum.keys.where((il) => il.toLowerCase().contains(_arama.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hizmet bölgeleri'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('hizmet-bolgeleri-kaydet'),
              onPressed: _kaydediliyor || _degisenler.isEmpty ? null : _kaydet,
              icon: const Icon(Icons.save),
              label: Text(_degisenler.isEmpty ? 'Kaydet' : 'Kaydet (${_degisenler.length})'),
            ),
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
              ? Center(child: Text(_hata!))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Pilot il: $_pilot · Açık ${sayilar['acik']} · Test ${sayilar['test']} · Kapalı ${sayilar['kapali']}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Açık: herkes talep açar. Test: yalnız yönetici ve test kullanıcıları. '
                        'Genel anahtar kapalıyken açık illerde de yalnız test kullanıcıları talep açar.'),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'İl ara'),
                      onChanged: (v) => setState(() => _arama = v),
                    ),
                    const SizedBox(height: 8),
                    for (final il in gorunen)
                      ListTile(
                        key: Key('il-$il'),
                        dense: true,
                        title: Text(il, style: TextStyle(fontWeight: il == _pilot ? FontWeight.w700 : null)),
                        subtitle: _kayitli[il] != _durum[il] ? const Text('Kaydedilmedi', style: TextStyle(color: Colors.deepOrange)) : null,
                        trailing: DropdownButton<String>(
                          value: _durum[il],
                          items: [
                            for (final e in durumEtiketleri.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) => setState(() => _durum[il] = v ?? _durum[il]!),
                        ),
                      ),
                  ],
                ),
    );
  }
}

library;

import 'package:flutter/material.dart';

import '../../core/constants/roles.dart';
import '../../core/constants/location_data.dart';
import '../../core/mappers/location_mapper.dart';

import '../../models/personel_model.dart';
import '../../services/personel_service.dart';

class PersonelBolgePaneli extends StatefulWidget {
  final List<dynamic> personeller;
  final Function(dynamic) onPersonelEkle;
  final Function(dynamic) onPersonelDuzenle;
  final Function(dynamic) onPersonelSil;
  final Function(dynamic) onPersonelAktiflikDegistir;

  const PersonelBolgePaneli({
    super.key,
    required this.personeller,
    required this.onPersonelEkle,
    required this.onPersonelDuzenle,
    required this.onPersonelSil,
    required this.onPersonelAktiflikDegistir,
  });

  @override
  State<PersonelBolgePaneli> createState() => _PersonelBolgePaneliState();
}

class _PersonelBolgePaneliState extends State<PersonelBolgePaneli> {
  final PersonelService _personelService = PersonelService();
  final LocationMapper _locationMapper = LocationMapper();
  bool _loadingCoverage = false;

  List<PersonelModel> get _personeller => widget.personeller
      .whereType<Map<String, dynamic>>()
      .map(PersonelModel.fromMap)
      .toList();

  Map<String, dynamic>? get _coverage => _personelService.coverage;

  @override
  void initState() {
    super.initState();
    _refreshCoverage();
  }

  Future<void> _refreshCoverage() async {
    setState(() => _loadingCoverage = true);
    await _personelService.loadCoverage();
    if (mounted) setState(() => _loadingCoverage = false);
  }

  @override
  Widget build(BuildContext context) {
    final personeller = _personeller;
    final activeCount = personeller.where((p) => p.aktif).length;
    final passiveCount = personeller.length - activeCount;
    final summary = (_coverage?['summary'] as Map?) ?? {};
    final missing = List<String>.from((_coverage?['missing_cities'] as List?) ?? const []);
    final understaffed = List<String>.from((_coverage?['understaffed_cities'] as List?) ?? const []);

    return RefreshIndicator(
      onRefresh: () async {
        await _personelService.loadPersoneller();
        await _refreshCoverage();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(onAdd: () => _showPersonelDialog()),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: 'Toplam', value: '${personeller.length}', color: Colors.blueGrey),
              _MetricCard(label: 'Aktif', value: '$activeCount', color: Colors.green),
              _MetricCard(label: 'Pasif', value: '$passiveCount', color: Colors.redAccent),
              _MetricCard(label: 'Kapsanan Il', value: '${summary['covered_city_count'] ?? '-'}', color: Colors.indigo),
              _MetricCard(label: 'Eksik Il', value: '${summary['missing_city_count'] ?? missing.length}', color: Colors.deepOrange),
              _MetricCard(label: 'Yetersiz Il', value: '${summary['understaffed_city_count'] ?? understaffed.length}', color: Colors.amber.shade800),
            ],
          ),
          const SizedBox(height: 16),
          _RiskLists(missing: missing, understaffed: understaffed, loading: _loadingCoverage),
          const SizedBox(height: 16),
          _CoverageTable(coverage: _coverage),
          const SizedBox(height: 16),
          _PersonnelTable(
            personeller: personeller,
            onEdit: _showPersonelDialog,
            onDeactivate: _showDeactivateDialog,
            onActivate: _activatePersonel,
            onResetPassword: _showResetPasswordDialog,
            onDelete: _confirmHardDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _showPersonelDialog([PersonelModel? personel]) async {
    final isEdit = personel != null;
    final nameController = TextEditingController(text: personel?.tamAd ?? '');
    final emailController = TextEditingController(text: personel?.email ?? '');
    final phoneController = TextEditingController(text: personel?.telefon ?? '');
    final expertiseController = TextEditingController(text: personel?.uzmanlikAlani ?? personel?.unvan ?? '');
    final passwordController = TextEditingController();
    
    // ✅ İL/İLÇE DROPDOWN — LocationData kullanılarak
    int selectedIlId = personel?.ilId ?? 0;
    String selectedIlce = personel?.ilce ?? '';
    final result = await showDialog<PersonelModel>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Seçilen ile göre ilçeleri filtrele
            final ilcelerList = selectedIlId > 0
                ? _locationMapper.getIlceler(selectedIlId)
                : <String>[];
            if (!ilcelerList.contains(selectedIlce)) {
              selectedIlce = '';
            }

            return AlertDialog(
              title: Text(isEdit ? 'Personel Duzenle' : 'Personel Ekle'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ad Soyad')),
                      TextField(controller: emailController, enabled: !isEdit, decoration: const InputDecoration(labelText: 'E-posta')),
                      TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telefon')),
                      const SizedBox(height: 12),
                      // ✅ İL DROPDOWN
                      DropdownButtonFormField<int>(
                        initialValue: selectedIlId > 0 ? selectedIlId : null,
                        decoration: const InputDecoration(
                          labelText: 'İl',
                          border: OutlineInputBorder(),
                        ),
                        items: LocationData.cities.map((city) {
                          return DropdownMenuItem<int>(
                            value: city.plakaKodu,
                            child: Text(city.ilAdi),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedIlId = value ?? 0;
                            selectedIlce = '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      // ✅ İLÇE DROPDOWN
                      DropdownButtonFormField<String>(
                        initialValue: selectedIlce.isNotEmpty ? selectedIlce : null,
                        decoration: const InputDecoration(
                          labelText: 'İlçe',
                          border: OutlineInputBorder(),
                        ),
                        items: ilcelerList.map((ilce) {
                          return DropdownMenuItem<String>(
                            value: ilce,
                            child: Text(ilce),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedIlce = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: expertiseController, decoration: const InputDecoration(labelText: 'Uzmanlik')),
                      if (!isEdit)
                        const SizedBox(height: 12),
                      if (!isEdit)
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Gecici Sifre'),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgec')),
                FilledButton(
                  onPressed: () {
                    final fullName = nameController.text.trim();
                    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
                    final city = _locationMapper.getIlAdi(selectedIlId);
                    final bolgeId = _locationMapper.getBolgeIdFromIlId(selectedIlId);
                    Navigator.pop(
                      context,
                      PersonelModel(
                        id: personel?.id ?? 'staff_${DateTime.now().millisecondsSinceEpoch}',
                        ad: parts.isNotEmpty ? parts.first : '',
                        soyad: parts.length > 1 ? parts.sublist(1).join(' ') : '',
                        adSoyad: fullName,
                        unvan: expertiseController.text.trim().isEmpty ? 'Saha Personeli' : expertiseController.text.trim(),
                        ilId: selectedIlId,
                        bolgeId: bolgeId,
                        email: emailController.text.trim(),
                        telefon: phoneController.text.trim(),
                        sifre: isEdit ? personel.sifre : passwordController.text,
                        rol: UserRole.fieldStaff,
                        aktif: personel?.aktif ?? true,
                        kayitTarihi: personel?.kayitTarihi ?? DateTime.now(),
                        il: city,
                        ilce: selectedIlce,
                        uzmanlikAlani: expertiseController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    expertiseController.dispose();
    passwordController.dispose();

    if (result == null) return;
    if (isEdit) {
      await widget.onPersonelDuzenle(result.toMap());
    } else {
      await widget.onPersonelEkle(result.toMap());
    }
    await _refreshCoverage();
    if (mounted) setState(() {});
  }


  Future<void> _showDeactivateDialog(PersonelModel personel) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${personel.tamAd} pasife alinsin mi?'),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Pasife alma nedeni'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Pasife Al'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty) return;
    await _personelService.deactivatePersonel(personel.id, reason);
    await _refreshCoverage();
    if (mounted) setState(() {});
  }

  Future<void> _activatePersonel(PersonelModel personel) async {
    await _personelService.activatePersonel(personel.id);
    await _refreshCoverage();
    if (mounted) setState(() {});
  }

  Future<void> _showResetPasswordDialog(PersonelModel personel) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${personel.tamAd} sifre sifirla'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Yeni gecici sifre'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgec')),
          FilledButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Sifreyi Sifirla'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.length < 8) return;
    await _personelService.resetPersonelPassword(personel.id, password);
  }

  Future<void> _confirmHardDelete(PersonelModel personel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kalici silme'),
        content: Text('${personel.tamAd} kaydi kalici olarak silinsin mi? Sadece hatali/test kayitlar icin kullanin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgec')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.onPersonelSil(personel.toMap());
    await _refreshCoverage();
    if (mounted) setState(() {});
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Personel ve Il Kapasitesi',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Personel Ekle'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskLists extends StatelessWidget {
  final List<String> missing;
  final List<String> understaffed;
  final bool loading;

  const _RiskLists({required this.missing, required this.understaffed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _RiskBox(title: 'Personel Olmayan Iller', items: missing, color: Colors.redAccent, loading: loading)),
        const SizedBox(width: 12),
        Expanded(child: _RiskBox(title: 'Personel Eksigi Olan Iller', items: understaffed, color: Colors.amber.shade800, loading: loading)),
      ],
    );
  }
}

class _RiskBox extends StatelessWidget {
  final String title;
  final List<String> items;
  final Color color;
  final bool loading;

  const _RiskBox({required this.title, required this.items, required this.color, required this.loading});

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Yukleniyor...'
        : items.isEmpty
            ? 'Kritik eksik yok'
            : items.take(12).join(', ');
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _CoverageTable extends StatelessWidget {
  final Map<String, dynamic>? coverage;
  const _CoverageTable({required this.coverage});

  @override
  Widget build(BuildContext context) {
    final cities = (coverage?['cities'] as Map?) ?? {};
    final rows = cities.entries.take(20).map((entry) {
      final value = Map<String, dynamic>.from(entry.value as Map);
      return DataRow(cells: [
        DataCell(Text(entry.key.toString())),
        DataCell(Text('${value['active_count'] ?? 0}')),
        DataCell(Text('${value['passive_count'] ?? 0}')),
        DataCell(Text('${value['open_request_count'] ?? 0}')),
        DataCell(Text('${value['minimum_target'] ?? 1}')),
      ]);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Il Bazli Kapasite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Il')),
              DataColumn(label: Text('Aktif')),
              DataColumn(label: Text('Pasif')),
              DataColumn(label: Text('Acik Talep')),
              DataColumn(label: Text('Hedef')),
            ],
            rows: rows.isEmpty
                ? const [
                    DataRow(cells: [
                      DataCell(Text('Veri yok')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                    ]),
                  ]
                : rows,
          ),
        ),
      ],
    );
  }
}

class _PersonnelTable extends StatelessWidget {
  final List<PersonelModel> personeller;
  final void Function(PersonelModel personel) onEdit;
  final void Function(PersonelModel personel) onDeactivate;
  final void Function(PersonelModel personel) onActivate;
  final void Function(PersonelModel personel) onResetPassword;
  final void Function(PersonelModel personel) onDelete;

  const _PersonnelTable({
    required this.personeller,
    required this.onEdit,
    required this.onDeactivate,
    required this.onActivate,
    required this.onResetPassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personel Listesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Ad Soyad')),
              DataColumn(label: Text('Il/Ilce')),
              DataColumn(label: Text('Telefon')),
              DataColumn(label: Text('Uzmanlik')),
              DataColumn(label: Text('Durum')),
              DataColumn(label: Text('Islem')),
            ],
            rows: personeller.map((personel) {
              return DataRow(cells: [
                DataCell(Text(personel.tamAd)),
                DataCell(Text('${personel.il ?? '-'} / ${personel.ilce ?? '-'}')),
                DataCell(Text(personel.telefon ?? '-')),
                DataCell(Text(personel.uzmanlikAlani ?? personel.unvan)),
                DataCell(Text(personel.aktif ? 'Aktif' : 'Pasif')),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(tooltip: 'Duzenle', icon: const Icon(Icons.edit), onPressed: () => onEdit(personel)),
                    IconButton(tooltip: 'Sifre Sifirla', icon: const Icon(Icons.lock_reset), onPressed: () => onResetPassword(personel)),
                    IconButton(
                      tooltip: personel.aktif ? 'Pasife Al' : 'Aktif Et',
                      icon: Icon(personel.aktif ? Icons.block : Icons.check_circle_outline),
                      onPressed: () => personel.aktif ? onDeactivate(personel) : onActivate(personel),
                    ),
                    IconButton(tooltip: 'Kalici Sil', icon: const Icon(Icons.delete_outline), onPressed: () => onDelete(personel)),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

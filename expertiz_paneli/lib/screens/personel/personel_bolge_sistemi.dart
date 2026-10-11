/// Admin → Personel sekmesi: personel ekleme/çıkarma + bölge sistemi.
///
/// Veri kaynağı: [PersonelService] (merkezi API). Ekran kendi verisini yükler;
/// eski dashboard'lardan gelen callback parametreleri geriye dönük uyumluluk
/// için kabul edilir ama kullanılmaz.
library;

import 'package:flutter/material.dart';

import '../../core/constants/roles.dart';
import '../../core/mappers/location_mapper.dart';
import '../../models/personel_model.dart';
import '../../services/personel_service.dart';

class PersonelBolgePaneli extends StatefulWidget {
  /// Kullanılmıyor (geriye dönük uyumluluk). Veri [PersonelService]'ten gelir.
  final List<dynamic>? personeller;
  final Function(dynamic)? onPersonelEkle;
  final Function(dynamic)? onPersonelDuzenle;
  final Function(dynamic)? onPersonelSil;
  final Function(dynamic)? onPersonelAktiflikDegistir;

  const PersonelBolgePaneli({
    super.key,
    this.personeller,
    this.onPersonelEkle,
    this.onPersonelDuzenle,
    this.onPersonelSil,
    this.onPersonelAktiflikDegistir,
  });

  @override
  State<PersonelBolgePaneli> createState() => _PersonelBolgePaneliState();
}

class _PersonelBolgePaneliState extends State<PersonelBolgePaneli> {
  final PersonelService _service = PersonelService();
  final LocationMapper _locationMapper = LocationMapper();
  final TextEditingController _searchController = TextEditingController();

  /// 0 = tüm bölgeler
  int _selectedRegionId = 0;
  bool _showPassive = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.refreshAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------

  List<int> get _ilIdsSortedByName {
    final ids = _locationMapper.getAllIlIds();
    ids.sort((a, b) => _locationMapper.getIlAdi(a).compareTo(_locationMapper.getIlAdi(b)));
    return ids;
  }

  List<PersonelModel> _filteredPersonnel(List<PersonelModel> all) {
    final query = _searchController.text.trim().toLowerCase();
    return all.where((p) {
      if (_selectedRegionId != 0 && p.bolgeId != _selectedRegionId) return false;
      if (!_showPassive && !p.aktif) return false;
      if (query.isEmpty) return true;
      final haystack = '${p.tamAd} ${p.email ?? ''} ${p.il ?? ''} ${p.ilce ?? ''} ${p.telefon ?? ''}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        duration: Duration(seconds: error ? 5 : 3),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final all = _service.personeller;
        final coverage = _service.coverage;
        final summary = Map<String, dynamic>.from((coverage?['summary'] as Map?) ?? const {});
        final regions = ((coverage?['regions'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final filtered = _filteredPersonnel(all);
        final activeCount = all.where((p) => p.aktif).length;

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: _service.refreshAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Header(onAdd: () => _showPersonelDialog(), onRefresh: _service.refreshAll),
                  if (_service.lastError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _service.lastError!, onRetry: _service.refreshAll),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricCard(label: 'Toplam Personel', value: '${all.length}', color: Colors.blueGrey),
                      _MetricCard(label: 'Aktif', value: '$activeCount', color: Colors.green),
                      _MetricCard(label: 'Pasif', value: '${all.length - activeCount}', color: Colors.redAccent),
                      _MetricCard(label: 'Kapsanan İl', value: '${summary['covered_city_count'] ?? '-'} / 81', color: Colors.indigo),
                      _MetricCard(
                        label: 'Personelsiz + Talepli İl',
                        value: '${summary['critical_city_count'] ?? '-'}',
                        color: Colors.deepOrange,
                      ),
                      _MetricCard(
                        label: 'Atama Bekleyen Talep',
                        value: '${summary['unassigned_request_count'] ?? '-'}',
                        color: Colors.amber.shade800,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _RegionGrid(
                    regions: regions,
                    selectedRegionId: _selectedRegionId,
                    onSelect: (id) => setState(() => _selectedRegionId = _selectedRegionId == id ? 0 : id),
                    colorOf: _locationMapper.getBolgeRenk,
                  ),
                  const SizedBox(height: 16),
                  _RiskLists(
                    critical: List<String>.from((coverage?['critical_cities'] as List?) ?? const []),
                    understaffed: List<String>.from((coverage?['understaffed_cities'] as List?) ?? const []),
                    loading: coverage == null && _service.lastError == null,
                  ),
                  const SizedBox(height: 16),
                  _ProvinceTable(regions: regions, selectedRegionId: _selectedRegionId),
                  const SizedBox(height: 20),
                  _PersonnelToolbar(
                    controller: _searchController,
                    selectedRegionName: _selectedRegionId == 0 ? null : _locationMapper.getBolgeAdi(_selectedRegionId),
                    showPassive: _showPassive,
                    onSearch: (_) => setState(() {}),
                    onClearRegion: () => setState(() => _selectedRegionId = 0),
                    onTogglePassive: (value) => setState(() => _showPassive = value),
                  ),
                  const SizedBox(height: 8),
                  if (_service.isLoading && all.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _PersonnelTable(
                      personeller: filtered,
                      openTaskCount: _service.acikGorevSayisi,
                      onEdit: _showPersonelDialog,
                      onDeactivate: _showDeactivateDialog,
                      onActivate: (p) => _run(() async {
                        await _service.activatePersonel(p.id);
                        _toast('${p.tamAd} tekrar aktif');
                      }),
                      onResetPassword: _showResetPasswordDialog,
                      onRemove: _confirmRemove,
                    ),
                ],
              ),
            ),
            if (_busy)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x33000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dialoglar
  // ---------------------------------------------------------------------------

  Future<void> _showPersonelDialog([PersonelModel? personel]) async {
    final isEdit = personel != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: personel?.tamAd ?? '');
    final emailController = TextEditingController(text: personel?.email ?? '');
    final phoneController = TextEditingController(text: personel?.telefon ?? '');
    final expertiseController = TextEditingController(text: personel?.uzmanlikAlani ?? '');
    final passwordController = TextEditingController();

    int selectedIlId = personel?.ilId ?? 0;
    if (selectedIlId == 0 && (personel?.il ?? '').isNotEmpty) {
      selectedIlId = _locationMapper.getIlId(personel!.il!);
    }
    String selectedIlce = personel?.ilce ?? '';
    final ilIds = _ilIdsSortedByName;

    final result = await showDialog<PersonelModel>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final ilceler = selectedIlId > 0 ? _locationMapper.getIlceler(selectedIlId) : <String>[];
            if (!ilceler.contains(selectedIlce)) selectedIlce = '';
            final bolgeId = _locationMapper.getBolgeIdFromIlId(selectedIlId);

            return AlertDialog(
              title: Text(isEdit ? 'Personeli Düzenle' : 'Yeni Personel Ekle'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Ad Soyad *'),
                          validator: (v) => (v == null || v.trim().split(RegExp(r'\s+')).length < 2)
                              ? 'Ad ve soyad girin'
                              : null,
                        ),
                        TextFormField(
                          controller: emailController,
                          enabled: !isEdit,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'E-posta *',
                            helperText: isEdit ? 'E-posta giriş kimliğidir, değiştirilemez' : 'Personel bu e-posta ile giriş yapar',
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Geçerli bir e-posta girin';
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Telefon'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedIlId > 0 ? selectedIlId : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'İl *', border: OutlineInputBorder()),
                          items: ilIds
                              .map((id) => DropdownMenuItem<int>(
                                    value: id,
                                    child: Text('${_locationMapper.getIlAdi(id)} (${id.toString().padLeft(2, '0')})'),
                                  ))
                              .toList(),
                          validator: (v) => (v == null || v == 0) ? 'İl seçin' : null,
                          onChanged: (value) => setDialogState(() {
                            selectedIlId = value ?? 0;
                            selectedIlce = '';
                          }),
                        ),
                        if (bolgeId > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(Icons.map_outlined, size: 16, color: _locationMapper.getBolgeRenk(bolgeId)),
                                const SizedBox(width: 6),
                                Text('Bölge: ${_locationMapper.getBolgeAdi(bolgeId)}'),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey('ilce-$selectedIlId'),
                          initialValue: selectedIlce.isNotEmpty ? selectedIlce : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'İlçe *', border: OutlineInputBorder()),
                          items: ilceler.map((ilce) => DropdownMenuItem<String>(value: ilce, child: Text(ilce))).toList(),
                          validator: (v) => (v == null || v.isEmpty) ? 'İlçe seçin' : null,
                          onChanged: (value) => setDialogState(() => selectedIlce = value ?? ''),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: expertiseController,
                          decoration: const InputDecoration(labelText: 'Uzmanlık (ör. Kaporta, Mekanik)'),
                        ),
                        if (!isEdit) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Geçici Şifre *',
                              helperText: 'En az 8 karakter. Personel ilk girişte değiştirir.',
                            ),
                            validator: (v) => (v == null || v.length < 8) ? 'En az 8 karakter' : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
                FilledButton(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final fullName = nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                    final parts = fullName.split(' ');
                    final expertise = expertiseController.text.trim();
                    Navigator.pop(
                      dialogContext,
                      PersonelModel(
                        id: personel?.id ?? '',
                        ad: parts.first,
                        soyad: parts.length > 1 ? parts.sublist(1).join(' ') : '',
                        adSoyad: fullName,
                        unvan: expertise.isEmpty ? 'Saha Personeli' : expertise,
                        ilId: selectedIlId,
                        bolgeId: bolgeId,
                        email: emailController.text.trim().toLowerCase(),
                        telefon: phoneController.text.trim(),
                        sifre: isEdit ? null : passwordController.text,
                        rol: UserRole.fieldStaff,
                        aktif: personel?.aktif ?? true,
                        kayitTarihi: personel?.kayitTarihi ?? DateTime.now(),
                        il: _locationMapper.getIlAdi(selectedIlId),
                        ilce: selectedIlce,
                        bolge: _locationMapper.getBolgeAdi(bolgeId),
                        uzmanlikAlani: expertise,
                      ),
                    );
                  },
                  child: Text(isEdit ? 'Kaydet' : 'Personeli Ekle'),
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
    await _run(() async {
      if (isEdit) {
        await _service.updatePersonel(result);
        _toast('${result.tamAd} güncellendi');
      } else {
        final created = await _service.addPersonel(result);
        _toast('${created.tamAd} eklendi (${created.il} / ${created.bolge}). Geçici şifre ile giriş yapabilir.');
      }
    });
  }

  Future<void> _showDeactivateDialog(PersonelModel personel) async {
    final reasonController = TextEditingController();
    final openTasks = _service.acikGorevSayisi(personel.id);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${personel.tamAd} pasife alınsın mı?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pasif personel sisteme giriş yapamaz ve yeni görev alamaz.'),
            if (openTasks > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Üzerindeki $openTasks açık görev admin kuyruğuna (Atama Bekleyen) geri dönecek.',
                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepOrange),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Pasife alma nedeni *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, reasonController.text.trim());
            },
            child: const Text('Pasife Al'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty) return;
    await _run(() async {
      final released = await _service.deactivatePersonel(personel.id, reason);
      _toast(released > 0
          ? '${personel.tamAd} pasife alındı. $released görev yeniden atama için kuyruğa döndü.'
          : '${personel.tamAd} pasife alındı.');
    });
  }

  Future<void> _showResetPasswordDialog(PersonelModel personel) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${personel.tamAd} – şifre sıfırla'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Yeni geçici şifre (en az 8 karakter)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () {
              if (passwordController.text.length < 8) return;
              Navigator.pop(dialogContext, passwordController.text);
            },
            child: const Text('Şifreyi Sıfırla'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null) return;
    await _run(() async {
      await _service.resetPersonelPassword(personel.id, password);
      _toast('Şifre sıfırlandı. Personel ilk girişte yeni şifre belirleyecek.');
    });
  }

  Future<void> _confirmRemove(PersonelModel personel) async {
    final reasonController = TextEditingController();
    final openTasks = _service.acikGorevSayisi(personel.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personeli sistemden çıkar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${personel.tamAd} (${personel.email ?? '-'}) hesabı silinecek ve bir daha giriş yapamayacak.'),
            const SizedBox(height: 8),
            Text(
              openTasks > 0
                  ? 'Üzerindeki $openTasks açık görev admin kuyruğuna geri dönecek.'
                  : 'Açık görevi yok.',
              style: TextStyle(color: openTasks > 0 ? Colors.deepOrange : null),
            ),
            const SizedBox(height: 4),
            const Text('Tamamlanmış raporlar silinmez.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            const Text(
              'Geçici olarak durdurmak için "Pasife Al" seçeneğini kullanın.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Neden (isteğe bağlı)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sistemden Çıkar'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true) return;
    await _run(() async {
      final released = await _service.deletePersonel(personel.id, reason: reason.isEmpty ? null : reason);
      _toast(released > 0
          ? '${personel.tamAd} sistemden çıkarıldı. $released görev kuyruğa döndü.'
          : '${personel.tamAd} sistemden çıkarıldı.');
    });
  }
}

// =============================================================================
// Alt bileşenler
// =============================================================================

class _Header extends StatelessWidget {
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;
  const _Header({required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('Personel ve Bölge Yönetimi', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        IconButton(tooltip: 'Yenile', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Personel Ekle'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
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
      width: 170,
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

class _RegionGrid extends StatelessWidget {
  final List<Map<String, dynamic>> regions;
  final int selectedRegionId;
  final ValueChanged<int> onSelect;
  final Color Function(int) colorOf;

  const _RegionGrid({
    required this.regions,
    required this.selectedRegionId,
    required this.onSelect,
    required this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Bölgeler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Bir bölgeye dokunarak il tablosunu ve personel listesini filtreleyin.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        if (regions.isEmpty)
          const Text('Bölge verisi yükleniyor...')
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: regions.map((region) {
              final id = (region['region_id'] as num?)?.toInt() ?? 0;
              final color = colorOf(id);
              final selected = id == selectedRegionId;
              final covered = region['covered_province_count'] ?? 0;
              final total = region['province_count'] ?? 0;
              final pct = ((region['coverage_pct'] as num?) ?? 0).toDouble();
              final unassigned = (region['unassigned_request_count'] as num?)?.toInt() ?? 0;
              final critical = List<String>.from((region['critical_cities'] as List?) ?? const []);
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(id),
                child: Container(
                  width: 230,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? color.withValues(alpha: .18) : null,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: selected ? .9 : .4), width: selected ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: color, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              region['region']?.toString() ?? '-',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: pct / 100,
                        color: color,
                        backgroundColor: color.withValues(alpha: .15),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 6),
                      Text('$covered / $total il kapsanıyor', style: const TextStyle(fontSize: 12)),
                      Text('Aktif personel: ${region['active_personnel'] ?? 0}', style: const TextStyle(fontSize: 12)),
                      Text(
                        'Atama bekleyen talep: $unassigned',
                        style: TextStyle(
                          fontSize: 12,
                          color: unassigned > 0 ? Colors.deepOrange : null,
                          fontWeight: unassigned > 0 ? FontWeight.w700 : null,
                        ),
                      ),
                      if (critical.isNotEmpty)
                        Text(
                          'Personelsiz talepli: ${critical.join(', ')}',
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _RiskLists extends StatelessWidget {
  final List<String> critical;
  final List<String> understaffed;
  final bool loading;

  const _RiskLists({required this.critical, required this.understaffed, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _RiskBox(
            title: 'Talep var, personel yok',
            items: critical,
            emptyText: 'Talebi olup personeli olmayan il yok',
            color: Colors.redAccent,
            loading: loading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RiskBox(
            title: 'Hedefin altında (büyükşehir min. 3)',
            items: understaffed,
            emptyText: 'Hedefin altında il yok',
            color: Colors.amber.shade800,
            loading: loading,
          ),
        ),
      ],
    );
  }
}

class _RiskBox extends StatelessWidget {
  final String title;
  final List<String> items;
  final String emptyText;
  final Color color;
  final bool loading;

  const _RiskBox({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.color,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Yükleniyor...'
        : items.isEmpty
            ? emptyText
            : items.take(15).join(', ') + (items.length > 15 ? ' +${items.length - 15}' : '');
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

class _ProvinceTable extends StatelessWidget {
  final List<Map<String, dynamic>> regions;
  final int selectedRegionId;

  const _ProvinceTable({required this.regions, required this.selectedRegionId});

  static const Map<String, String> _statusText = {
    'ok': 'Yeterli',
    'understaffed': 'Hedef altı',
    'missing': 'Personel yok',
    'critical': 'Talep var, personel yok',
  };

  static const Map<String, Color> _statusColor = {
    'ok': Colors.green,
    'understaffed': Colors.orange,
    'missing': Colors.grey,
    'critical': Colors.redAccent,
  };

  @override
  Widget build(BuildContext context) {
    final provinces = <Map<String, dynamic>>[];
    for (final region in regions) {
      final id = (region['region_id'] as num?)?.toInt() ?? 0;
      if (selectedRegionId != 0 && id != selectedRegionId) continue;
      for (final item in (region['provinces'] as List?) ?? const []) {
        if (item is Map) provinces.add(Map<String, dynamic>.from(item));
      }
    }
    // Tüm Türkiye görünümünde sadece hareketli illeri göster; bölge seçiliyse hepsini.
    final visible = selectedRegionId == 0
        ? provinces.where((p) => (p['active_count'] ?? 0) != 0 || (p['passive_count'] ?? 0) != 0 || (p['open_request_count'] ?? 0) != 0).toList()
        : provinces;
    visible.sort((a, b) {
      final order = ['critical', 'understaffed', 'missing', 'ok'];
      final byStatus = order.indexOf('${a['status']}').compareTo(order.indexOf('${b['status']}'));
      return byStatus != 0 ? byStatus : '${a['city']}'.compareTo('${b['city']}');
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedRegionId == 0 ? 'İl Bazlı Kapasite (personeli veya talebi olan iller)' : 'İl Bazlı Kapasite',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('İl')),
              DataColumn(label: Text('Bölge')),
              DataColumn(label: Text('Aktif'), numeric: true),
              DataColumn(label: Text('Pasif'), numeric: true),
              DataColumn(label: Text('Açık Talep'), numeric: true),
              DataColumn(label: Text('Atanmamış'), numeric: true),
              DataColumn(label: Text('Hedef'), numeric: true),
              DataColumn(label: Text('Durum')),
            ],
            rows: visible.isEmpty
                ? const [
                    DataRow(cells: [
                      DataCell(Text('Kayıt yok')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                      DataCell(Text('-')),
                    ]),
                  ]
                : visible.map((p) {
                    final status = '${p['status']}';
                    return DataRow(cells: [
                      DataCell(Text('${p['city']}')),
                      DataCell(Text('${p['region']}')),
                      DataCell(Text('${p['active_count'] ?? 0}')),
                      DataCell(Text('${p['passive_count'] ?? 0}')),
                      DataCell(Text('${p['open_request_count'] ?? 0}')),
                      DataCell(Text('${p['unassigned_request_count'] ?? 0}')),
                      DataCell(Text('${p['minimum_target'] ?? 1}')),
                      DataCell(Text(
                        _statusText[status] ?? status,
                        style: TextStyle(color: _statusColor[status], fontWeight: FontWeight.w600),
                      )),
                    ]);
                  }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PersonnelToolbar extends StatelessWidget {
  final TextEditingController controller;
  final String? selectedRegionName;
  final bool showPassive;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearRegion;
  final ValueChanged<bool> onTogglePassive;

  const _PersonnelToolbar({
    required this.controller,
    required this.selectedRegionName,
    required this.showPassive,
    required this.onSearch,
    required this.onClearRegion,
    required this.onTogglePassive,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Personel Listesi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        SizedBox(
          width: 260,
          child: TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Ad, e-posta, il ara',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (selectedRegionName != null)
          InputChip(label: Text('Bölge: $selectedRegionName'), onDeleted: onClearRegion),
        FilterChip(
          label: const Text('Pasifleri göster'),
          selected: showPassive,
          onSelected: onTogglePassive,
        ),
      ],
    );
  }
}

class _PersonnelTable extends StatelessWidget {
  final List<PersonelModel> personeller;
  final int Function(String personelId) openTaskCount;
  final void Function(PersonelModel personel) onEdit;
  final void Function(PersonelModel personel) onDeactivate;
  final void Function(PersonelModel personel) onActivate;
  final void Function(PersonelModel personel) onResetPassword;
  final void Function(PersonelModel personel) onRemove;

  const _PersonnelTable({
    required this.personeller,
    required this.openTaskCount,
    required this.onEdit,
    required this.onDeactivate,
    required this.onActivate,
    required this.onResetPassword,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (personeller.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Henüz personel yok. "Personel Ekle" ile ilk saha personelini ekleyin.'),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('Ad Soyad')),
          DataColumn(label: Text('İl / İlçe')),
          DataColumn(label: Text('Bölge')),
          DataColumn(label: Text('Telefon')),
          DataColumn(label: Text('Uzmanlık')),
          DataColumn(label: Text('Açık Görev'), numeric: true),
          DataColumn(label: Text('Durum')),
          DataColumn(label: Text('İşlem')),
        ],
        rows: personeller.map((personel) {
          return DataRow(cells: [
            DataCell(Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(personel.tamAd, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(personel.email ?? '-', style: const TextStyle(fontSize: 11)),
              ],
            )),
            DataCell(Text('${personel.il ?? '-'} / ${personel.ilce ?? '-'}')),
            DataCell(Text(personel.bolge ?? '-')),
            DataCell(Text((personel.telefon ?? '').isEmpty ? '-' : personel.telefon!)),
            DataCell(Text((personel.uzmanlikAlani ?? '').isEmpty ? personel.unvan : personel.uzmanlikAlani!)),
            DataCell(Text('${openTaskCount(personel.id)}')),
            DataCell(Chip(
              label: Text(personel.aktif ? 'Aktif' : 'Pasif'),
              backgroundColor: (personel.aktif ? Colors.green : Colors.grey).withValues(alpha: .18),
              visualDensity: VisualDensity.compact,
            )),
            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(tooltip: 'Düzenle', icon: const Icon(Icons.edit), onPressed: () => onEdit(personel)),
                IconButton(tooltip: 'Şifre Sıfırla', icon: const Icon(Icons.lock_reset), onPressed: () => onResetPassword(personel)),
                IconButton(
                  tooltip: personel.aktif ? 'Pasife Al' : 'Aktif Et',
                  icon: Icon(personel.aktif ? Icons.block : Icons.check_circle_outline),
                  onPressed: () => personel.aktif ? onDeactivate(personel) : onActivate(personel),
                ),
                IconButton(
                  tooltip: 'Sistemden Çıkar',
                  icon: const Icon(Icons.person_remove_alt_1_outlined, color: Colors.redAccent),
                  onPressed: () => onRemove(personel),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }
}

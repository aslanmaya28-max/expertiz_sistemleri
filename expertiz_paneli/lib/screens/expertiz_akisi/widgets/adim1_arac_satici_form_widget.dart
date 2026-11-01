import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/expertiz/adim1_arac_satici_model.dart';
import '../../../models/expertiz/durumlu_soru_model.dart';
import 'durumlu_soru_widget.dart';

/// Adım 1: Araç ve Satıcı Bilgileri Form Widget'ı
class Adim1AracSaticiFormWidget extends StatefulWidget {
  final Adim1AracSaticiModel model;
  final Function(Adim1AracSaticiModel) onChanged;
  final bool enabled;

  const Adim1AracSaticiFormWidget({
    super.key,
    required this.model,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<Adim1AracSaticiFormWidget> createState() =>
      _Adim1AracSaticiFormWidgetState();
}

class _Adim1AracSaticiFormWidgetState extends State<Adim1AracSaticiFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _markaController;
  late TextEditingController _modelController;
  late TextEditingController _paketController;
  late TextEditingController _plakaController;
  late TextEditingController _saseNoController;
  late TextEditingController _kmController;
  late TextEditingController _ruhsatSahibiController;
  late TextEditingController _telefonController;
  late TextEditingController _pazarlikMiktarController;
  late TextEditingController _hasarAdetController;
  late TextEditingController _hasarTutarController;

  @override
  void initState() {
    super.initState();
    _markaController = TextEditingController(text: widget.model.marka);
    _modelController = TextEditingController(text: widget.model.model);
    _paketController = TextEditingController(text: widget.model.paket ?? '');
    _plakaController = TextEditingController(text: widget.model.plaka);
    _saseNoController = TextEditingController(text: widget.model.saseNo);
    _kmController =
        TextEditingController(text: widget.model.guncelKm.toString());
    _ruhsatSahibiController =
        TextEditingController(text: widget.model.ruhsatSahibiAdSoyad);
    _telefonController =
        TextEditingController(text: widget.model.iletisimTelefon);
    _pazarlikMiktarController = TextEditingController(
      text: widget.model.pazarlikMiktari?.toString() ?? '',
    );
    _hasarAdetController = TextEditingController(
      text: widget.model.hasarKayitAdet?.toString() ?? '',
    );
    _hasarTutarController = TextEditingController(
      text: widget.model.hasarKayitToplamTutar?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _markaController.dispose();
    _modelController.dispose();
    _paketController.dispose();
    _plakaController.dispose();
    _saseNoController.dispose();
    _kmController.dispose();
    _ruhsatSahibiController.dispose();
    _telefonController.dispose();
    _pazarlikMiktarController.dispose();
    _hasarAdetController.dispose();
    _hasarTutarController.dispose();
    super.dispose();
  }

  void _updateModel() {
    final yeniModel = widget.model.copyWith(
      marka: _markaController.text,
      model: _modelController.text,
      paket: _paketController.text.trim(),
      plaka: _plakaController.text,
      saseNo: _saseNoController.text,
      guncelKm: int.tryParse(_kmController.text) ?? 0,
      ruhsatSahibiAdSoyad: _ruhsatSahibiController.text,
      iletisimTelefon: _telefonController.text,
      pazarlikMiktari: double.tryParse(_pazarlikMiktarController.text),
      hasarKayitAdet: int.tryParse(_hasarAdetController.text),
      hasarKayitToplamTutar: double.tryParse(_hasarTutarController.text),
    );
    widget.onChanged(yeniModel);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚗 Araç Bilgileri (ZORUNLU)
          _buildSectionHeader('🚗 Araç Bilgileri', zorunlu: true),
          const SizedBox(height: 16),

          _ResponsiveFieldRow(
            children: [
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _markaController,
                  decoration: const InputDecoration(
                    labelText: 'Marka *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Marka zorunludur';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateModel(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Model zorunludur';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateModel(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Paket: ilandaki / ruhsattaki gibi motor + paket adi. AI emsal ilanlari bu paketten secer.
          TextFormField(
            enabled: widget.enabled,
            controller: _paketController,
            decoration: const InputDecoration(
              labelText: 'Motor / Paket',
              hintText: 'ör. 1.0 EcoTSI Style DSG, 1.3 Multijet Urban',
              helperText: 'İlandaki gibi yazın; AI aynı paketteki ilanlarla karşılaştırır',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.star),
            ),
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue:
                widget.model.yakitTuru.isEmpty ? null : widget.model.yakitTuru,
            decoration: const InputDecoration(
              labelText: 'Yakıt Tipi *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_gas_station),
            ),
            items: Adim1AracSaticiModel.yakitTurleri
                .map((tip) => DropdownMenuItem(value: tip, child: Text(tip)))
                .toList(),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Yakıt tipi zorunludur';
              }
              return null;
            },
            onChanged: widget.enabled
                ? (value) {
                    if (value != null) {
                      final yeniModel = widget.model.copyWith(yakitTuru: value);
                      widget.onChanged(yeniModel);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            enabled: widget.enabled,
            controller: _plakaController,
            decoration: const InputDecoration(
              labelText: 'Plaka *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Plaka zorunludur';
              }
              return null;
            },
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            enabled: widget.enabled,
            controller: _saseNoController,
            decoration: const InputDecoration(
              labelText: 'Şase No *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Şase no zorunludur';
              }
              if (value.length != 17) {
                return 'Şase no 17 karakter olmalıdır';
              }
              return null;
            },
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            enabled: widget.enabled,
            controller: _kmController,
            decoration: const InputDecoration(
              labelText: 'Güncel KM *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.speed),
              suffixText: 'km',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'KM zorunludur';
              }
              final km = int.tryParse(value);
              if (km == null || km < 0) {
                return 'Geçerli bir KM giriniz';
              }
              return null;
            },
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 12),

          _ResponsiveFieldRow(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.enabled
                      ? () async {
                          final tarih = await showDatePicker(
                            context: context,
                            initialDate:
                                widget.model.enSonBakimTarihi ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (tarih != null) {
                            final yeniModel =
                                widget.model.copyWith(enSonBakimTarihi: tarih);
                            widget.onChanged(yeniModel);
                          }
                        }
                      : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'En Son Bakım Tarihi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.build),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      widget.model.enSonBakimTarihi != null
                          ? DateFormat('dd.MM.yyyy')
                              .format(widget.model.enSonBakimTarihi!)
                          : 'Seçiniz',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: widget.enabled
                      ? () async {
                          final tarih = await showDatePicker(
                            context: context,
                            initialDate:
                                widget.model.sonMuayeneTarihi ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (tarih != null) {
                            final yeniModel =
                                widget.model.copyWith(sonMuayeneTarihi: tarih);
                            widget.onChanged(yeniModel);
                          }
                        }
                      : null,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Son Muayene Tarihi',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.verified_user),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      widget.model.sonMuayeneTarihi != null
                          ? DateFormat('dd.MM.yyyy')
                              .format(widget.model.sonMuayeneTarihi!)
                          : 'Seçiniz',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ⚠️ Hasar Bilgileri (OPSİYONEL)
          _buildSectionHeader('⚠️ Hasar Bilgileri', zorunlu: false),
          const SizedBox(height: 16),

          _ResponsiveFieldRow(
            children: [
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _hasarAdetController,
                  decoration: const InputDecoration(
                    labelText: 'Hasar Kayıt Adet',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.warning),
                    suffixText: 'adet',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final adet = int.tryParse(value);
                      if (adet == null || adet < 0) {
                        return 'Geçerli bir adet giriniz';
                      }
                    }
                    return null;
                  },
                  onChanged: (_) => _updateModel(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _hasarTutarController,
                  decoration: const InputDecoration(
                    labelText: 'Hasar Kayıt Toplam Tutar',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: '₺ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final tutar = double.tryParse(value);
                      if (tutar == null || tutar < 0) {
                        return 'Geçerli bir tutar giriniz';
                      }
                    }
                    return null;
                  },
                  onChanged: (_) => _updateModel(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 👤 Ruhsat / Satıcı Bilgileri (ZORUNLU)
          _buildSectionHeader('👤 Ruhsat / Satıcı Bilgileri', zorunlu: true),
          const SizedBox(height: 16),

          TextFormField(
            enabled: widget.enabled,
            controller: _ruhsatSahibiController,
            decoration: const InputDecoration(
              labelText: 'Ruhsat Sahibi Ad Soyad *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ruhsat sahibi zorunludur';
              }
              return null;
            },
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 12),

          TextFormField(
            enabled: widget.enabled,
            controller: _telefonController,
            decoration: const InputDecoration(
              labelText: 'İletişim (Telefon) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Telefon zorunludur';
              }
              return null;
            },
            onChanged: (_) => _updateModel(),
          ),
          const SizedBox(height: 24),

          // 🔸 Durum Sekme Mantığı
          _buildSectionHeader('🔸 Durum Değerlendirmesi', zorunlu: true),
          const SizedBox(height: 16),

          ...widget.model.durumSorular.asMap().entries.map((entry) {
            final index = entry.key;
            final soru = entry.value;
            return Column(
              children: [
                DurumluSoruWidget(
                  soru: soru,
                  enabled: widget.enabled,
                  showFoto: false,
                  onDurumChanged: (durum) {
                    final yeniSorular =
                        List<DurumluSoru>.from(widget.model.durumSorular);
                    yeniSorular[index] = soru.copyWith(durum: durum);
                    widget.onChanged(
                        widget.model.copyWith(durumSorular: yeniSorular));
                  },
                  onNotChanged: (not) {
                    final yeniSorular =
                        List<DurumluSoru>.from(widget.model.durumSorular);
                    yeniSorular[index] = soru.copyWith(not: not);
                    widget.onChanged(
                        widget.model.copyWith(durumSorular: yeniSorular));
                  },
                  onFotoChanged: (fotoYolu) {
                    final yeniSorular =
                        List<DurumluSoru>.from(widget.model.durumSorular);
                    yeniSorular[index] = soru.copyWith(fotoYolu: fotoYolu);
                    widget.onChanged(
                        widget.model.copyWith(durumSorular: yeniSorular));
                  },
                ),
                if (index < widget.model.durumSorular.length - 1)
                  const Divider(thickness: 1, height: 16),
              ],
            );
          }),
          const SizedBox(height: 16),
          const Divider(thickness: 1),
          const SizedBox(height: 16),

          // Pazarlık bilgisi
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  'Pazarlık Miktarı',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text(
                    '-',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: TextFormField(
                  enabled: widget.enabled,
                  controller: _pazarlikMiktarController,
                  decoration: const InputDecoration(
                    labelText: 'Miktar',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (widget.model.pazarlikPayiVar == true &&
                        (value == null || value.isEmpty)) {
                      return 'Pazarlık miktarı zorunludur';
                    }
                    return null;
                  },
                  onChanged: (_) => _updateModel(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required bool zorunlu}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          )),
          if (zorunlu) const SizedBox(width: 8),
          if (zorunlu)
            const Text(
              '*',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  /// Model isminden spor paket tespiti
}

/// Keeps existing desktop field pairs, stacking them at narrow form widths.
class _ResponsiveFieldRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveFieldRow({required this.children});

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 560) return Row(children: children);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                if (child is Expanded)
                  child.child
                else if (child is SizedBox)
                  const SizedBox(height: 12)
                else
                  child,
            ]);
      });
}

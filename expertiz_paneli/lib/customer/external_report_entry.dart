import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yerimebak_sistemleri/models/arac_rapor_model.dart';
import 'package:yerimebak_sistemleri/services/ai/ai_analiz_service.dart';
import 'package:yerimebak_sistemleri/models/ai/ai_analiz_sonucu_model.dart';
// import 'package:yerimebak_sistemleri/screens/musteri_odeme_sayfasi.dart'; // Kaldırıldı - Faz-1 modüler yapı
// TODO: Eğer ödeme sayfası gerekiyorsa customer_dashboard içinden çağır veya geçici widget kullan

class ExternalReportEntry extends StatefulWidget {
  const ExternalReportEntry({super.key});

  @override
  State<ExternalReportEntry> createState() => _ExternalReportEntryState();
}

class _ExternalReportEntryState extends State<ExternalReportEntry> {
  final _formKey = GlobalKey<FormState>();
  
  // Araç Bilgileri
  final _markaController = TextEditingController();
  final _modelController = TextEditingController();
  final _yilController = TextEditingController();
  final _plakaController = TextEditingController();
  final _kmController = TextEditingController();
  
  // Boya Bilgileri
  final _boyaSolOnKapi = TextEditingController();
  final _boyaSagOnKapi = TextEditingController();
  final _boyaSolArkaKapi = TextEditingController();
  final _boyaSagArkaKapi = TextEditingController();
  final _boyaKaput = TextEditingController();
  final _boyaTrunk = TextEditingController();
  
  // Motor & Mekanik
  final _motorDurumuController = TextEditingController();
  final _sanzumanDurumuController = TextEditingController();
  final _frenDurumuController = TextEditingController();
  final _suspansiyonDurumuController = TextEditingController();
  
  final List<String> _uploadedFiles = [];
  bool _isUploading = false;
  bool _isAnalyzing = false;
  
  static const double _aiServicePrice = 500.0;

  @override
  void dispose() {
    _markaController.dispose();
    _modelController.dispose();
    _yilController.dispose();
    _plakaController.dispose();
    _kmController.dispose();
    _boyaSolOnKapi.dispose();
    _boyaSagOnKapi.dispose();
    _boyaSolArkaKapi.dispose();
    _boyaSagArkaKapi.dispose();
    _boyaKaput.dispose();
    _boyaTrunk.dispose();
    _motorDurumuController.dispose();
    _sanzumanDurumuController.dispose();
    _frenDurumuController.dispose();
    _suspansiyonDurumuController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    setState(() => _isUploading = true);
    
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFiles.addAll(result.files.map((file) => file.name));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya yükleme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _uploadedFiles.removeAt(index);
    });
  }

  Future<void> _submitAndAnalyze() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir rapor sayfası yükleyin')),
      );
      return;
    }

    // Örnek rapor oluştur - ödeme adımı atlandı (placeholder)
    final rapor = AracRapor(
      id: 'ext_${DateTime.now().millisecondsSinceEpoch}',
      musteriId: 'guest',
      personelId: null,
      olusturmaTarihi: DateTime.now(),
      durum: 'Beklemede', // Ödeme atlandı
      plaka: _plakaController.text,
      marka: _markaController.text,
      model: _modelController.text,
      yil: _yilController.text,
      secilenPaket: 'AI Analiz Paketi',
      hizmetBedeli: _aiServicePrice,
      paketFiyati: _aiServicePrice,
      toplamTutar: _aiServicePrice,
      isPaid: false,
    );

    // Direkt AI analizini başlat (ödeme adımı placeholder)
    _startAIAnalysis(rapor);
  }

  Future<void> _startAIAnalysis(AracRapor rapor) async {
    setState(() => _isAnalyzing = true);

    try {
      // AracRapor'u TamRaporModel'e dönüştür
      final tamRapor = rapor.toTamRaporModel();
      
      // AI analizini başlat
      final analizSonucu = await AIAnalizService.analizEtVeKaydet(
        raporId: tamRapor.gorevId,
        marka: tamRapor.adim1.marka,
        model: tamRapor.adim1.model,
        yil: tamRapor.adim1.yil ?? DateTime.now().year.toString(),
        km: tamRapor.adim1.guncelKm,
        hasarKayitlar: tamRapor.adim4.hasarKayitlari.map((h) => h.konum).toList(),
        donanimlar: {},
        boyaliParcalar: tamRapor.adim4.boyaliParcalar,
      );

      if (mounted) {
        setState(() => _isAnalyzing = false);
        
        // Başarılı analizi göster
        _showAnalysisResult(analizSonucu, rapor);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI analizi başlatılırken hata: $e')),
        );
      }
    }
  }

  void _showAnalysisResult(AIAnalizSonucu? analizSonucu, AracRapor rapor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'AI Analizi Tamamlandı!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Genel Puan: ${analizSonucu?.skorlar.genelPuan.toStringAsFixed(1) ?? "N/A"}/100',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dış Rapor AI Analizi'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fiyat Bilgisi
              _buildPriceCard(),
              const SizedBox(height: 20),
              
              // Araç Bilgileri
              _buildSectionHeader('Araç Bilgileri', Icons.directions_car),
              const SizedBox(height: 10),
              _buildVehicleForm(),
              const SizedBox(height: 20),
              
              // Boya Bilgileri
              _buildSectionHeader('Boya Bilgileri', Icons.format_paint),
              const SizedBox(height: 10),
              _buildPaintForm(),
              const SizedBox(height: 20),
              
              // Motor & Mekanik
              _buildSectionHeader('Motor & Mekanik', Icons.settings),
              const SizedBox(height: 10),
              _buildMechanicalForm(),
              const SizedBox(height: 20),
              
              // Fotoğraf Yükleme
              _buildSectionHeader('Rapor Sayfalarını Yükle', Icons.photo_library),
              const SizedBox(height: 10),
              _buildFileUploadSection(),
              const SizedBox(height: 30),
              
              // Submit Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isAnalyzing ? null : _submitAndAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isAnalyzing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('AI Analizi Yapılıyor...'),
                          ],
                        )
                      : Text(
                          'Analizi Başlat (${_aiServicePrice.toStringAsFixed(0)} TL)',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[700]!, Colors.orange[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Analiz Hizmeti',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Profesyonel araç değerlemesi ve risk analizi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '500 TL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange[700]),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildTextField(_markaController, 'Marka', 'Örn: Toyota')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_modelController, 'Model', 'Örn: Corolla')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_yilController, 'Yıl', 'Örn: 2020')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_plakaController, 'Plaka', 'Örn: 34ABC123')),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(_kmController, 'Kilometre', 'Örn: 50000', keyboardType: TextInputType.number),
      ],
    );
  }

  Widget _buildPaintForm() {
    return Column(
      children: [
        _buildPaintRow('Sol Ön Kapı', _boyaSolOnKapi, 'Sağ Ön Kapı', _boyaSagOnKapi),
        const SizedBox(height: 12),
        _buildPaintRow('Sol Arka Kapı', _boyaSolArkaKapi, 'Sağ Arka Kapı', _boyaSagArkaKapi),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_boyaKaput, 'Kaput', 'Var/Yok')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_boyaTrunk, 'Bagaj Kapağı', 'Var/Yok')),
          ],
        ),
      ],
    );
  }

  Widget _buildPaintRow(String label1, TextEditingController controller1, String label2, TextEditingController controller2) {
    return Row(
      children: [
        Expanded(child: _buildTextField(controller1, label1, 'Boyalı/Yok')),
        const SizedBox(width: 12),
        Expanded(child: _buildTextField(controller2, label2, 'Boyalı/Yok')),
      ],
    );
  }

  Widget _buildMechanicalForm() {
    return Column(
      children: [
        _buildTextArea(_motorDurumuController, 'Motor Durumu', 'Örn: Motor temiz, yağ seviyesi normal'),
        const SizedBox(height: 12),
        _buildTextArea(_sanzumanDurumuController, 'Şanzıman Durumu', 'Örn: Vites geçişleri sorunsuz'),
        const SizedBox(height: 12),
        _buildTextArea(_frenDurumuController, 'Fren Sistemi', 'Örn: Frenler güçlü'),
        const SizedBox(height: 12),
        _buildTextArea(_suspansiyonDurumuController, 'Süspansiyon', 'Örn: Süspansiyon stabil'),
      ],
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _pickFiles,
            icon: const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Yükleniyor...' : 'Rapor Sayfaları Yükle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[100],
              foregroundColor: Colors.orange[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_uploadedFiles.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yüklenen Dosyalar:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...List.generate(_uploadedFiles.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_uploadedFiles[index])),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => _removeFile(index),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Henüz dosya yüklenmedi', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      keyboardType: keyboardType ?? TextInputType.text,
      validator: (value) => value?.isEmpty ?? true ? '$label zorunludur' : null,
    );
  }

  Widget _buildTextArea(TextEditingController controller, String label, String hint) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value?.isEmpty ?? true ? '$label zorunludur' : null,
    );
  }
}

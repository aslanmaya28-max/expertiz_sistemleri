import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/futuristic_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/neon_button.dart';
import '../../core/layout/base_scaffold.dart';
import '../../widgets/cyber/siber_scanner_animation.dart';
import '../../services/report_upload_service.dart';
import '../../core/constants/roles.dart';

/// Rapor Yükleme Ekranı
/// Müşterinin dışarıdan aldığı raporu sisteme yükler
class ReportUploadScreen extends StatefulWidget {
  const ReportUploadScreen({super.key});

  @override
  State<ReportUploadScreen> createState() => _ReportUploadScreenState();
}

class _ReportUploadScreenState extends State<ReportUploadScreen>
    with TickerProviderStateMixin {
  // Akış durumları
  UploadStep _currentStep = UploadStep.upload;
  
  // Progress
  double _uploadProgress = 0.0;
  String _statusText = 'Rapor Verileri Okunuyor...';
  
  // Rapor verileri
  Map<String, dynamic>? _reportData;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      role: UserRole.customer,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              SizedBox(height: 30),
              
              // Content based on current step
              _buildCurrentStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RAPOR YÜKLEME',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: FuturisticTheme.neon,
            letterSpacing: 2.0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Dışarıdan aldığınız raporu sisteme yükleyin ve AI ile analiz edin',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case UploadStep.upload:
        return _buildUploadStep();
      case UploadStep.scanning:
        return _buildScanningStep();
      case UploadStep.payment:
        return _buildPaymentStep();
      case UploadStep.processing:
        return _buildProcessingStep();
      case UploadStep.completed:
        return _buildCompletedStep();
    }
  }

  // Step 1: Upload
  Widget _buildUploadStep() {
    return Column(
      children: [
        // Upload Card
        GlassCard(
          padding: EdgeInsets.all(30),
          child: Column(
            children: [
              // Upload Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.cloud_upload,
                  size: 50,
                  color: FuturisticTheme.neon,
                ),
              ),
              
              SizedBox(height: 20),
              
              // Upload Text
              Text(
                'Rapor Dosyasını Yükleyin',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'PDF veya JPG formatında raporunuzu yükleyin',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Upload Button
              NeonButton(
                text: 'Dosya Seç',
                onTap: _handleFileUpload,
              ),
              
              SizedBox(height: 20),
              
              // Demo Button
              TextButton(
                onPressed: _handleDemoUpload,
                child: Text(
                  'Demo Rapor ile Devam Et',
                  style: TextStyle(
                    color: FuturisticTheme.neon,
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 30),
        
        // Info Card
        GlassCard(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: FuturisticTheme.neon,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nasıl Çalışır?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. Raporunuzu yükleyin\n2. AI tarar ve analiz eder\n3. 500 TL ödeme yapın\n4. Siber-Premium raporunuzu alın',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2: Scanning
  Widget _buildScanningStep() {
    return Column(
      children: [
        // Scanner Animation
        SiberScannerAnimation(
          statusText: _statusText,
          progress: _uploadProgress,
        ),
        
        SizedBox(height: 30),
        
        // Status Card
        GlassCard(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: FuturisticTheme.neon,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: FuturisticTheme.neon.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Payment
  Widget _buildPaymentStep() {
    return Column(
      children: [
        // Payment Card
        GlassCard(
          padding: EdgeInsets.all(30),
          child: Column(
            children: [
              // Payment Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.payment,
                  size: 40,
                  color: FuturisticTheme.neon,
                ),
              ),
              
              SizedBox(height: 20),
              
              // Payment Text
              Text(
                'Ödeme Gerekli',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              SizedBox(height: 8),
              
              Text(
                'AI Analiz Hizmeti',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Price
              Container(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '500 TL',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: FuturisticTheme.neon,
                  ),
                ),
              ),
              
              SizedBox(height: 30),
              
              // Pay Button
              NeonButton(
                text: 'Ödemeyi Tamamla',
                onTap: _handlePayment,
              ),
              
              SizedBox(height: 20),
              
              // Cancel Button
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = UploadStep.upload;
                  });
                },
                child: Text(
                  'İptal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 30),
        
        // Info Card
        GlassCard(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FuturisticTheme.neon.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  color: FuturisticTheme.neon,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Güvenli Ödeme',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Ödemeniz güvenli bir şekilde işlenir',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 4: Processing
  Widget _buildProcessingStep() {
    return Column(
      children: [
        // Processing Animation
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: FuturisticTheme.bgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FuturisticTheme.neon.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(FuturisticTheme.neon),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'AI Analizi Yapılıyor...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Bu işlem birkaç saniye sürebilir',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        SizedBox(height: 30),
        
        // Status Card
        GlassCard(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProcessingItem('Rapor verileri işleniyor', true),
              _buildProcessingItem('AI skorları hesaplanıyor', true),
              _buildProcessingItem('Siber-Premium şablonuna dönüştürülüyor', true),
              _buildProcessingItem('Onay mührü basılıyor', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingItem(String text, bool isCompleted) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? FuturisticTheme.neon : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  )
                : SizedBox.shrink(),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isCompleted ? Colors.white : Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 5: Completed
  Widget _buildCompletedStep() {
    if (_reportData == null) return SizedBox.shrink();
    
    return Column(
      children: [
        // Success Animation
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: FuturisticTheme.bgSecondary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: FuturisticTheme.neon.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              // Seal Stamp
              Center(
                child: SealStampAnimation(isActive: true),
              ),
              
              // Success Text
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'RAPOR HAZIR!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: FuturisticTheme.neon,
                        letterSpacing: 2.0,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI Skoru: ${_reportData!['aiAnalizi']['genelSkor']}/100',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 30),
        
        // Report Info Card
        GlassCard(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rapor Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              _buildInfoRow('Araç', '${_reportData!['aracBilgileri']['marka']} ${_reportData!['aracBilgileri']['model']}'),
              _buildInfoRow('Yıl', '${_reportData!['aracBilgileri']['yil']}'),
              _buildInfoRow('KM', '${_reportData!['aracBilgileri']['km']}'),
              _buildInfoRow('Boya Durumu', _reportData!['ekspertizSonucu']['boyaDurumu']),
              _buildInfoRow('AI Skoru', '${_reportData!['aiAnalizi']['genelSkor']}/100'),
            ],
          ),
        ),
        
        SizedBox(height: 30),
        
        // View Report Button
        NeonButton(
          text: 'Raporu Görüntüle',
          onTap: _handleViewReport,
        ),
        
        SizedBox(height: 20),
        
        // Back to Dashboard Button
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'Panele Dön',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Handlers
  void _handleFileUpload() {
    // File picker entegrasyonu buraya yapılacak
    // Şimdilik demo upload'a yönlendiriyoruz
    _handleDemoUpload();
  }

  void _handleDemoUpload() {
    setState(() {
      _currentStep = UploadStep.scanning;
    });
    
    // Simüle edilmiş tarama süreci
    _simulateScanning();
  }

  void _simulateScanning() {
    double progress = 0.0;
    
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      setState(() {
        progress += 0.05;
        _uploadProgress = progress;
        
        if (progress < 0.3) {
          _statusText = 'Rapor Verileri Okunuyor...';
        } else if (progress < 0.6) {
          _statusText = 'Araç Bilgileri Çıkarılıyor...';
        } else if (progress < 0.9) {
          _statusText = 'Donanım Listesi Oluşturuluyor...';
        } else {
          _statusText = 'Tarama Tamamlandı!';
        }
        
        if (progress >= 1.0) {
          timer.cancel();
          Future.delayed(Duration(milliseconds: 500), () {
            setState(() {
              _currentStep = UploadStep.payment;
            });
          });
        }
      });
    });
  }

  void _handlePayment() {
    setState(() {
      _currentStep = UploadStep.processing;
    });
    
    // Simüle edilmiş ödeme ve AI analizi
    _simulateProcessing();
  }

  void _simulateProcessing() async {
    await Future.delayed(Duration(milliseconds: 2000));
    
    // Rapor oluştur
    final reportData = await ReportUploadService.createFullReport(
      gorevId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      personelId: 'system',
    );
    
    setState(() {
      _reportData = reportData;
      _currentStep = UploadStep.completed;
    });
  }

  void _handleViewReport() {
    if (_reportData == null) return;
    
    // Rapor detay ekranına git - ReportDetailScreen tanımlı değil, şimdilik basit bir mesaj göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rapor detay ekranı henüz entegre edilmedi'),
        backgroundColor: FuturisticTheme.neon,
      ),
    );
  }
}

enum UploadStep {
  upload,
  scanning,
  payment,
  processing,
  completed,
}

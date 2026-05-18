import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expertiz_provider.dart';
import '../../providers/admin_provider.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'adim1_sayfasi.dart';
import 'adim2_sayfasi.dart';
import 'adim3_sayfasi.dart';
import 'adim4_sayfasi.dart';
import 'adim5_sayfasi.dart';

 

/// Expertiz Başlatma Sayfası
/// 5 adımlı expertiz akışını yönetir
class ExpertizBaslatSayfasi extends StatefulWidget {
  final String gorevId;
  final String personelId;
  final String personelAdi;
  final String musteriAdi;
  final String aracPlakasi;

  const ExpertizBaslatSayfasi({
    super.key,
    required this.gorevId,
    required this.personelId,
    required this.personelAdi,
    required this.musteriAdi,
    required this.aracPlakasi,
  });

  @override
  State<ExpertizBaslatSayfasi> createState() => _ExpertizBaslatSayfasiState();
}

class _ExpertizBaslatSayfasiState extends State<ExpertizBaslatSayfasi> {
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Provider'da görevi başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpertizProvider>().startGorev(
            gorevId: widget.gorevId,
            personelId: widget.personelId,
            personelAdi: widget.personelAdi,
            musteriAdi: widget.musteriAdi,
            aracPlakasi: widget.aracPlakasi,
          );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Expertiz Akışı', style: TextStyle(color: YerimeBakColors.blue)),
        backgroundColor: Colors.white,
        foregroundColor: YerimeBakColors.blue,
        elevation: 0,
        iconTheme: const IconThemeData(color: YerimeBakColors.blue),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // İlerleme göstergesi
          Consumer<ExpertizProvider>(
            builder: (context, provider, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '%${(provider.completionPercentage * 100).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: YerimeBakColors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Adım ${provider.currentStep}/5',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Consumer<ExpertizProvider>(
            builder: (context, provider, child) {
              return LinearProgressIndicator(
                value: provider.completionPercentage,
                backgroundColor: YerimeBakColors.lightGray,
                valueColor: const AlwaysStoppedAnimation<Color>(YerimeBakColors.blue),
              );
            },
          ),
        ),
      ),
      body: Consumer<ExpertizProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Yükleniyor...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600]!,
                    ),
                  ),
                ],
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: YerimeBakColors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      style: const TextStyle(
                        fontSize: 18,
                        color: YerimeBakColors.red,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.clearError(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tekrar Dene'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: YerimeBakColors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Görev bilgileri kartı
          return Column(
            children: [
              // Üst bilgi kartı
              _buildGorevBilgisiCard(provider),

              // PageView ile adımlar
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    Adim1Sayfasi(),
                    Adim2Sayfasi(),
                    Adim3Sayfasi(),
                    Adim4Sayfasi(),
                    Adim5Sayfasi(),
                  ],
                ),
              ),

              // Alt navigasyon
              _buildBottomNavigation(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGorevBilgisiCard(ExpertizProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: YerimeBakColors.lightGray,
        border: Border(
          bottom: BorderSide(color: YerimeBakColors.blue.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: YerimeBakColors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Görev: ${provider.gorevId ?? 'Belirtilmedi'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: YerimeBakColors.darkBlue,
                        ),
                      ),
                      Text(
                        'Personel: ${provider.personelAdi ?? 'Belirtilmedi'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: YerimeBakColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF757575), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Müşteri: ${provider.musteriAdi ?? 'Belirtilmedi'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.directions_car, color: Color(0xFF757575), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Araç: ${provider.aracPlakasi ?? 'Belirtilmedi'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(ExpertizProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Önceki adım butonu
          Expanded(
            child: ElevatedButton.icon(
              onPressed: provider.currentStep > 1
                  ? () {
                      provider.previousStep();
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  : null,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Geri'),
              style: ElevatedButton.styleFrom(
                backgroundColor: provider.currentStep > 1
                    ? YerimeBakColors.blue
                    : Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Adım butonları
          ...List.generate(5, (index) {
            final stepNumber = index + 1;
            final isCurrentStep = provider.currentStep == stepNumber;
            final isCompleted = provider.currentStep > stepNumber;
  
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (provider.currentStep != stepNumber) {
                    provider.goToStep(stepNumber);
                    _pageController.animateToPage(
                      stepNumber - 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isCurrentStep
                        ? YerimeBakColors.blue
                        : isCompleted
                            ? YerimeBakColors.green
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCurrentStep
                          ? YerimeBakColors.blue
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        ExpertizProvider.stepIcons[index],
                        style: TextStyle(
                          fontSize: 24,
                          color: isCurrentStep || isCompleted
                              ? Colors.white
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrentStep || isCompleted
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 16),

          // Sonraki adım butonu veya BİTİR butonu
          Expanded(
            child: provider.currentStep == 5
            ? ElevatedButton.icon( // BİTİR BUTONU
                 onPressed: provider.currentStepValid
                   ? () async {
                        // 1. Görevi Tamamla (AI Analiz + Kayıt)
                        final success = await provider.completeGorev();
                         
                        if (success && mounted) {
                           // 2. Admin Bildirimi
                           await context.read<AdminProvider>().raporTamamlandi(
                              provider.gorevId!,
                              provider.personelId!
                           );
                             
                           // 3. Başarılı Mesajı ve Çıkış
                           if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(
                                 content: Text('Rapor başarıyla tamamlandı ve merkeze iletildi! 🚀'),
                                 backgroundColor: YerimeBakColors.green,
                                 duration: Duration(seconds: 3),
                               )
                             );
                             
                             Navigator.pop(context); // Ana sayfaya dön
                           }
                        }
                    }
                    : null,
                 icon: const Icon(Icons.check_circle),
                 label: const Text('BİTİR VE GÖNDER'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: provider.currentStepValid
                       ? YerimeBakColors.green
                       : Colors.grey.shade300,
                   foregroundColor: Colors.white,
                 ),
               )
            : ElevatedButton.icon( // İLERİ BUTONU
               onPressed: provider.currentStepValid
                   ? () {
                       provider.nextStep();
                       _pageController.nextPage(
                         duration: const Duration(milliseconds: 300),
                         curve: Curves.easeInOut,
                       );
                     }
                   : null,
               icon: const Icon(Icons.arrow_forward),
               label: const Text('İleri'),
               style: ElevatedButton.styleFrom(
                 backgroundColor: provider.currentStepValid
                     ? YerimeBakColors.blue
                     : Colors.grey.shade300,
                 foregroundColor: Colors.white,
                 disabledBackgroundColor: Colors.grey.shade300,
               ),
             ),
          ),
        ],
      ),
    );
  }
}

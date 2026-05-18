// PHASE 6.6 - Customer Dashboard Migration to Riverpod
//
// ARCHITECTURE:
// - ConsumerWidget with Riverpod state management
// - CustomerReportsProvider for published reports only
// - Privacy-First data filtering (hide sensitive fields)
// - Instant Delivery real-time sync
// - Forensic Certificate UX with neon cyan accents
// - Offline readiness indicators

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/report_state_provider.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/neon_button.dart';
import '../core/layout/base_scaffold.dart';
import '../screens/login_screen.dart';
import '../core/constants/roles.dart';

// ========================================
// MAIN DASHBOARD WIDGET
// ========================================

class CustomerDashboard extends ConsumerWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all data sources reactively
    final reports = ref.watch(customerReportsProvider);
    final state = ref.watch(reportStateProvider);
    final currentUserAsync = ref.watch(customerUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: FuturisticTheme.neon),
                  SizedBox(height: 16),
                  Text(
                    'Panel yükleniyor...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          );
        }

        // Listen for new published reports (simplified - provider handles filtering)
        ref.listen<ReportState>(reportStateProvider, (previous, next) {
          // ReportStateProvider will notify when new reports are published
          // CustomerDashboard shows only published reports via customerReportsProvider
        });

        return Stack(
          children: [
            BaseScaffold(
              role: UserRole.customer,
              appBar: AppBar(
                title: Text('Müşteri Paneli'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: Icon(Icons.notifications),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Bildirimler özelliği yakında aktif olacak'),
                          backgroundColor: FuturisticTheme.neon,
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(currentUser),
                    SizedBox(height: 24),
                    _buildAICard(),
                    SizedBox(height: 24),
                    _buildReportUploadCard(),
                    SizedBox(height: 24),
                    _buildNewRequestCard(),
                    SizedBox(height: 32),
                    _buildPublishedReportsSection(context, ref, reports, state),
                    SizedBox(height: 32),
                    _buildQuickActions(context),
                    SizedBox(height: 32),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
            if (state.isBulkOperationInProgress)
              _buildOfflineIndicator(state),
          ],
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: FuturisticTheme.neon),
              SizedBox(height: 16),
              Text(
                'Panel yükleniyor...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text('Hata: $error', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // WELCOME CARD
  // ========================================

  Widget _buildWelcomeCard(dynamic currentUser) {
    final userName = currentUser?.fullName ?? currentUser?.name ?? 'Müşteri';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.3),
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.person, size: 25, color: FuturisticTheme.neon),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba, $userName',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Araç ekspertiz işlemlerinizi buradan yönetebilirsiniz.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================
  // AI ANALYSIS CARD
  // ========================================

  Widget _buildAICard() {
    return GestureDetector(
      onTap: () {
        // Navigate to AI Analysis Center
      },
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FuturisticTheme.neon.withValues(alpha: 0.3),
                    FuturisticTheme.neon.withValues(alpha: 0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: FuturisticTheme.neon.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Icon(Icons.auto_awesome, color: FuturisticTheme.neon, size: 30),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Oto-Analiz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Yapay zeka destekli araç değerleme',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FuturisticTheme.neon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // REPORT UPLOAD CARD
  // ========================================

  Widget _buildReportUploadCard() {
    return GestureDetector(
      onTap: () {
        // Navigate to Report Upload
      },
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FuturisticTheme.neon.withValues(alpha: 0.3),
                    Colors.purple.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cloud_upload, color: FuturisticTheme.neon, size: 30),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapor Yükle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dışarıdan aldığınız raporu sisteme yükleyin',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FuturisticTheme.neon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_forward_ios, color: FuturisticTheme.neon, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // NEW REQUEST CARD
  // ========================================

  Widget _buildNewRequestCard() {
    return GestureDetector(
      onTap: () {
        // Navigate to Create Request
      },
      child: GlassCard(
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add_circle, color: Colors.blue, size: 30),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Ekspertiz Talebi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Hemen bir araç için randevu oluşturun',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // PUBLISHED REPORTS SECTION
  // ========================================

  Widget _buildPublishedReportsSection(
    BuildContext context,
    WidgetRef ref,
    Iterable<Map<String, dynamic>> reports,
    ReportState state,
  ) {
    // Convert to typed models
    final reportModels = reports.map((r) => _mapToReportModel(r)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Yayınlanan Raporlarım',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: FuturisticTheme.neon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FuturisticTheme.neon),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: FuturisticTheme.neon, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Sertifikalı',
                    style: TextStyle(
                      color: FuturisticTheme.neon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          '${reportModels.length} adet rapor',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        SizedBox(height: 16),
        
        if (reportModels.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white.withValues(alpha: 0.24)),
                  SizedBox(height: 16),
                  Text('Henüz yayınlanmış rapor yok', style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 8),
                  Text(
                    'Raporlarınız inceleme ve onaylandıktan sonra burada görünecektir',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ...reportModels.map((report) => _buildReportCard(context, ref, report)),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, WidgetRef ref, CustomerReportModel report) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FuturisticTheme.neon.withValues(alpha: 0.3),
                      FuturisticTheme.neon.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Icon(Icons.verified, color: FuturisticTheme.neon, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.plaka,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      report.firma,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Forensic Certificate Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.3),
                      Colors.green.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, color: Colors.green, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Sertifikalı',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.white54),
              SizedBox(width: 4),
              Text(
                DateFormat('dd.MM.yyyy HH:mm').format(report.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Download Button with Pulse Animation
          SizedBox(
            width: double.infinity,
            child: _AnimatedDownloadButton(
              reportId: report.id,
              onTap: () => _downloadReport(context, report),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadReport(BuildContext context, CustomerReportModel report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 8),
            Text('${report.plaka} raporu indiriliyor...'),
          ],
        ),
        backgroundColor: FuturisticTheme.neon,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Future use: void _showNewReportNotification(BuildContext context, String reportId) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Row(
  //         children: [
  //           Icon(Icons.verified, color: Colors.white),
  //           SizedBox(width: 8),
  //           Expanded(
  //             child: Text('Yeni raporunuz hazır! İndirmek için tıklayın.'),
  //           ),
  //         ],
  //       ),
  //       backgroundColor: Colors.green,
  //       action: SnackBarAction(
  //         label: 'İndir',
  //         textColor: Colors.white,
  //         onPressed: () {
  //           // Navigate to report or show download dialog
  //         },
  //       ),
  //       duration: Duration(seconds: 5),
  //     ),
  //   );
  // }

  // ========================================
  // QUICK ACTIONS
  // ========================================

  Widget _buildQuickActions(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hızlı İşlemler',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAction(
                Icons.history,
                'Raporlarım',
                Colors.blue,
                () {},
              ),
              _buildQuickAction(
                Icons.message,
                'Mesajlar',
                Colors.purple,
                () {},
              ),
              _buildQuickAction(
                Icons.settings,
                'Ayarlar',
                Colors.grey,
                () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // LOGOUT BUTTON
  // ========================================

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: NeonButton(
        text: 'Çıkış Yap',
                  onTap: () async {
                    // TODO: Implement logout via UserProvider
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                      );
                    }
                  },
      ),
    );
  }

  Widget _buildOfflineIndicator(ReportState state) {
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 8),
            Text(
              'Senkronize ediliyor...',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // HELPERS
  // ========================================

  CustomerReportModel _mapToReportModel(Map<String, dynamic> data) {
    return CustomerReportModel(
      id: data['id']?.toString() ?? '',
      plaka: data['plaka']?.toString() ?? '---',
      firma: data['firma']?.toString() ?? '---',
      durum: data['status']?.toString() ?? 'published',
      createdAt: data['created_at'] != null
          ? DateTime.parse(data['created_at'].toString())
          : DateTime.now(),
      raporUrl: data['rapor_url']?.toString(),
    );
  }
}

// ========================================
// MODELS
// ========================================

class CustomerReportModel {
  final String id;
  final String plaka;
  final String firma;
  final String durum;
  final DateTime createdAt;
  final String? raporUrl;

  CustomerReportModel({
    required this.id,
    required this.plaka,
    required this.firma,
    required this.durum,
    required this.createdAt,
    this.raporUrl,
  });
}

// ========================================
// ANIMATED DOWNLOAD BUTTON
// ========================================

class _AnimatedDownloadButton extends StatefulWidget {
  final String reportId;
  final VoidCallback onTap;

  const _AnimatedDownloadButton({
    required this.reportId,
    required this.onTap,
  });

  @override
  State<_AnimatedDownloadButton> createState() => _AnimatedDownloadButtonState();
}

class _AnimatedDownloadButtonState extends State<_AnimatedDownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FuturisticTheme.neon.withValues(alpha: 0.3),
                  FuturisticTheme.neon.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FuturisticTheme.neon.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, color: FuturisticTheme.neon, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Raporu İndir',
                        style: TextStyle(
                          color: FuturisticTheme.neon,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ========================================
// PROVIDERS
// ========================================

final customerUserProvider = FutureProvider<dynamic>((ref) async {
  // TODO: Replace with UserProvider.currentUser
  return null;
});

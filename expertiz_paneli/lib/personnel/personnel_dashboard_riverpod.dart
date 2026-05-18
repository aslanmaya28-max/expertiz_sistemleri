// PHASE 6.5 - Personnel Dashboard Migration to Riverpod
//
// ARCHITECTURE:
// - ConsumerWidget with Riverpod state management
// - PersonnelReportsProvider for assigned reports only
// - Admin Annotation Feedback Loop (personnel can view annotations)
// - Real-time sync with Admin dashboard
// - Conflict detection and resolution
// - Glass-morphism UI with neon cyan accents
// - Offline readiness indicators

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/report_state_provider.dart';
import '../core/theme/futuristic_theme.dart';
import '../core/widgets/glass_card.dart';
import '../core/widgets/neon_button.dart';
import '../core/layout/base_scaffold.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../models/admin_annotation.dart';
import 'widgets/annotation_badge.dart';
import '../screens/personel/expertiz_sihirbazi.dart';

// ========================================
// MAIN DASHBOARD WIDGET
// ========================================

class PersonnelDashboard extends ConsumerWidget {
  const PersonnelDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch all data sources reactively
    final reports = ref.watch(personnelReportsProvider);
    final state = ref.watch(reportStateProvider);
    final currentUserAsync = ref.watch(currentUserProvider);

    // Show loading if user not loaded
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

    // Show conflict snackbar if needed
    if (state.hasConflict) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Admin raporu güncelledi. Verileri yenileyin.')),
              ],
            ),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Yenile',
              textColor: Colors.white,
              onPressed: () {
                ref.read(reportStateProvider.notifier).clearConflict();
                ref.read(reportStateProvider.notifier).refresh();
              },
            ),
            duration: Duration(seconds: 5),
          ),
        );
      });
    }

    final pages = [
      _buildDashboard(context, ref, reports, state, currentUser),
      _buildGorevler(context, ref, reports, state, currentUser),
      _buildProfil(context, ref, currentUser),
    ];

        return Stack(
          children: [
            BaseScaffold(
              role: UserRole.fieldStaff,
              body: pages[0], // Dashboard tab as default
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
  // DASHBOARD TAB
  // ========================================

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    Iterable<Map<String, dynamic>> reports,
    ReportState state,
    UserModel currentUser,
  ) {
    final reportModels = reports.map((r) => _mapToReportModel(r)).toList();
    final assignedTasks = reportModels.where((t) =>
      t.durum != 'Raporlandı' && t.durum != 'Tamamlandı' && t.durum != 'published'
    ).toList();
    final completedTasks = reportModels.where((t) =>
      t.durum == 'Raporlandı' || t.durum == 'Tamamlandı' || t.durum == 'published'
    ).toList();

    // Check for reports with Admin annotations requiring attention
    final reportsWithAnnotations = reportModels.where((r) =>
      r.adminAnnotations?.isNotEmpty == true
    ).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card with Neon Cyan
          GlassCard(
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
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: FuturisticTheme.neon.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.person, size: 30, color: FuturisticTheme.neon),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hoş Geldiniz, ${currentUser.fullName}!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ID: ${currentUser.id}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
                      ),
                      Text(
                        DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Offline sync indicator
                if (state.isBulkOperationInProgress)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Statistics with Neon Cyan
          Row(
            children: [
              Expanded(
                child: _buildGlassStatCard('Atanan', assignedTasks.length.toString(), Icons.assignment, Colors.orange),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildGlassStatCard('Tamamlanan', completedTasks.length.toString(), Icons.check_circle, Colors.green),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildGlassStatCard('Toplam', '${reportModels.length}', Icons.work, FuturisticTheme.neon),
              ),
            ],
          ),

          SizedBox(height: 24),

          // Admin Annotations Alert
          if (reportsWithAnnotations.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.3),
                    Colors.orange.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.orange, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${reportsWithAnnotations.length} raporda Admin notu var!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Aşağıdaki görevleri kontrol edin',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Today's Tasks
          if (assignedTasks.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  "📋 Atanan Görevler",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FuturisticTheme.neon),
                  ),
                  child: Text(
                    '${assignedTasks.length}',
                    style: TextStyle(
                      color: FuturisticTheme.neon,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            ...assignedTasks.map((gorev) => _buildGorevCard(context, ref, gorev, currentUser)),
          ] else ...[
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 64, color: Colors.white.withValues(alpha: 0.24)),
                    SizedBox(height: 16),
                    Text('Atanan aktif görev bulunmuyor', style: TextStyle(color: Colors.white.withValues(alpha: 0.54))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.70))),
        ],
      ),
    );
  }

  // ========================================
  // GÖREVLER TAB
  // ========================================

  Widget _buildGorevler(
    BuildContext context,
    WidgetRef ref,
    Iterable<Map<String, dynamic>> reports,
    ReportState state,
    UserModel currentUser,
  ) {
    final reportModels = reports.map((r) => _mapToReportModel(r)).toList();
    final assignedTasks = reportModels.where((t) =>
      t.durum != 'Raporlandı' && t.durum != 'Tamamlandı' && t.durum != 'published'
    ).toList();
    final completedTasks = reportModels.where((t) =>
      t.durum == 'Raporlandı' || t.durum == 'Tamamlandı' || t.durum == 'published'
    ).toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: FuturisticTheme.bgSecondary,
            child: TabBar(
              labelColor: FuturisticTheme.neon,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.54),
              indicatorColor: FuturisticTheme.neon,
              tabs: [
                Tab(text: 'Aktif (${assignedTasks.length})'),
                Tab(text: 'Geçmiş (${completedTasks.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGorevListesi(context, ref, assignedTasks, currentUser, false),
                _buildGorevListesi(context, ref, completedTasks, currentUser, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGorevListesi(
    BuildContext context,
    WidgetRef ref,
    List<PersonnelReportModel> gorevler,
    UserModel currentUser,
    bool tamamlandi,
  ) {
    if (gorevler.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tamamlandi ? Icons.check_circle_outline : Icons.assignment_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.24),
            ),
            SizedBox(height: 16),
            Text(
              tamamlandi ? 'Tamamlanan görev bulunmuyor' : 'Aktif görev bulunmuyor',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: gorevler.length,
      itemBuilder: (context, index) => _buildGorevCard(context, ref, gorevler[index], currentUser),
    );
  }

  // ========================================
  // REPORT CARD WITH ADMIN ANNOTATIONS
  // ========================================

  Widget _buildGorevCard(
    BuildContext context,
    WidgetRef ref,
    PersonnelReportModel gorev,
    UserModel currentUser,
  ) {
    void navigateToWorkflow() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExpertizSihirbazi(
            gorevId: gorev.id,
            musteriAdi: gorev.musteriAdi,
            aracPlaka: gorev.aracPlaka,
          ),
        ),
      );
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  gorev.aracMarkaModel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status Chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDurumColor(gorev.durum).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getDurumColor(gorev.durum)),
                ),
                child: Text(
                  gorev.durum,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getDurumColor(gorev.durum),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Admin Annotations Badge
          if (gorev.adminAnnotations?.isNotEmpty == true) ...[
            SizedBox(height: 8),
            ...gorev.adminAnnotations!.map((annotation) => AnnotationBadge(
              fieldKey: annotation.fieldKey,
              fieldLabel: annotation.fieldLabel,
              message: annotation.adminNote,
              type: annotation.annotationType,
              annotations: gorev.adminAnnotations!,
              onReply: () => _showAnnotationReplyDialog(context, ref, gorev, annotation),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${annotation.fieldLabel}: ${annotation.adminNote}',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            )),
            SizedBox(height: 8),
          ],

          SizedBox(height: 4),
          Text(
            gorev.aracPlaka,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70), fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            gorev.aciklama,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.white54),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  gorev.sehir.isNotEmpty ? gorev.sehir : "İstanbul",
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.54)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 14, color: Colors.white54),
              SizedBox(width: 4),
              Text(
                DateFormat('dd.MM.yyyy HH:mm').format(gorev.olusturulma),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.54)),
              ),
            ],
          ),

          // Action Buttons
          if (gorev.durum != 'Raporlandı' && gorev.durum != 'Tamamlandı' && gorev.durum != 'published') ...[
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: NeonButton(
                text: 'GÖREVİ BAŞLAT',
                onTap: navigateToWorkflow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAnnotationReplyDialog(
    BuildContext context,
    WidgetRef ref,
    PersonnelReportModel gorev,
    AdminAnnotation annotation,
  ) {
    final replyController = TextEditingController(text: annotation.personnelReply ?? '');
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  FuturisticTheme.bgSecondary.withValues(alpha: 0.95),
                  FuturisticTheme.bgPrimary.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: FuturisticTheme.neon.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FuturisticTheme.neon.withValues(alpha: 0.1),
                        FuturisticTheme.neon.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FuturisticTheme.neon.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.message,
                          color: FuturisticTheme.neon,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ADMİN NOTU',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              gorev.aracPlaka,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Admin's Note
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Notu:',
                        style: TextStyle(
                          color: FuturisticTheme.neon,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          annotation.adminNote,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

                // Personnel Reply Section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yanıtınız:',
                        style: TextStyle(
                          color: FuturisticTheme.neon,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: replyController,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          hintText: 'Admin notuna yanıt verin...',
                          hintStyle: TextStyle(color: Colors.white24),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: FuturisticTheme.neon),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: Text(
                            'İptal',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  final reply = replyController.text.trim();
                                  if (reply.isEmpty) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                                      SnackBar(
                                        content: Text('Lütfen bir yanıt yazın'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);

                                  final notifier = ref.read(reportStateProvider.notifier);
                                  final success = await notifier.replyToAnnotation(
                                    gorev.id,
                                    annotation.id,
                                    reply,
                                  );

                                  if (dialogContext.mounted) {
                                    setDialogState(() => isSubmitting = false);

                                    if (success) {
                                      Navigator.of(dialogContext).pop();
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.check_circle, color: Colors.white),
                                                SizedBox(width: 8),
                                                Text('Yanıtınız başarıyla iletildi'),
                                              ],
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } else {
                                      final state = ref.read(reportStateProvider);
                                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            state.error ?? 'Yanıt gönderilemedi',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSubmitting
                                ? Colors.white12
                                : FuturisticTheme.neon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white24,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isSubmitting
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Gönder'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDurumColor(String durum) {
    switch (durum) {
      case 'Onaylandı':
        return Colors.orange;
      case 'Raporlandı':
      case 'Tamamlandı':
      case 'published':
        return Colors.green;
      case 'Beklemede':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ========================================
  // PROFIL TAB
  // ========================================

  Widget _buildProfil(BuildContext context, WidgetRef ref, UserModel currentUser) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadPersonelData(ref, currentUser.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: FuturisticTheme.neon));
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.withValues(alpha: 0.7)),
                SizedBox(height: 16),
                Text('Veri yüklenemedi: ${snapshot.error}', style: TextStyle(color: Colors.white70)),
              ],
            ),
          );
        }

        final personelData = snapshot.data ?? {
          'id': currentUser.id,
          'adSoyad': currentUser.fullName,
          'email': currentUser.email,
          'rol': currentUser.role.name,
          'aktif': false,
          'musait': false,
          'uzmanlikAlani': 'Belirtilmemiş',
          'performansSkoru': 0.0,
          'aktifGorevSayisi': 0,
          'il': '---',
          'ilce': '---',
        };

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              // Digital ID Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FuturisticTheme.bgSecondary,
                      FuturisticTheme.bgPrimary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: FuturisticTheme.neon.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: FuturisticTheme.neon.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  FuturisticTheme.neon.withValues(alpha: 0.3),
                                  FuturisticTheme.neon.withValues(alpha: 0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(40),
                              border: Border.all(
                                color: FuturisticTheme.neon.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: Icon(Icons.person, size: 40, color: FuturisticTheme.neon),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  personelData['adSoyad']?.toString() ?? '---',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (personelData['aktif'] as bool? ?? false)
                                            ? Colors.green.withValues(alpha: 0.2)
                                            : Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            (personelData['aktif'] as bool? ?? false) ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: (personelData['aktif'] as bool? ?? false) ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (personelData['musait'] as bool? ?? false)
                                            ? Colors.blue.withValues(alpha: 0.2)
                                            : Colors.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            (personelData['musait'] as bool? ?? false) ? Icons.check_circle : Icons.work,
                                            size: 12,
                                            color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            (personelData['musait'] as bool? ?? false) ? 'Müsait' : 'Meşgul',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: (personelData['musait'] as bool? ?? false) ? Colors.blue : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    ),

                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildStatRow(
                            Icons.trending_up,
                            'Performans Skoru',
                            '${personelData['performansSkoru']}',
                            FuturisticTheme.neon,
                          ),
                          SizedBox(height: 16),
                          _buildStatRow(
                            Icons.assignment_turned_in,
                            'Aktif Görev',
                            '${personelData['aktifGorevSayisi']}',
                            Colors.orange,
                          ),
                          SizedBox(height: 16),
                          _buildStatRow(
                            Icons.engineering,
                            'Uzmanlık Alanı',
                            personelData['uzmanlikAlani']?.toString() ?? '---',
                            Colors.purple,
                          ),
                          SizedBox(height: 16),
                          _buildStatRow(
                            Icons.badge,
                            'Rol',
                            (personelData['rol'] as String?)?.toUpperCase() ?? '---',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      height: 1,
                      margin: EdgeInsets.symmetric(horizontal: 24),
                      color: FuturisticTheme.neon.withValues(alpha: 0.2),
                    ),

                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  Icons.add_task,
                                  'Görev Ata',
                                  Colors.green,
                                  () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Görev atama modülü açılıyor...'),
                                        backgroundColor: FuturisticTheme.neon,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  Icons.show_chart,
                                  'Performans İzle',
                                  Colors.blue,
                                  () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Performans analizi açılıyor...'),
                                        backgroundColor: FuturisticTheme.neon,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildActionButton(
                            Icons.chat,
                            'İletişime Geç',
                            FuturisticTheme.neon,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sohbet açılıyor...'),
                                  backgroundColor: FuturisticTheme.neon,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              GlassCard(
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    // TODO: Implement logout via UserProvider
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadPersonelData(WidgetRef ref, String userId) async {
    try {
      // For now, return mock data (actual stats require service implementation)
      await Future.delayed(Duration(milliseconds: 500));
      
      return {
        'id': userId,
        'adSoyad': 'Personel',
        'email': 'personel@example.com',
        'rol': 'personel',
        'aktif': false,
        'musait': false,
        'uzmanlikAlani': 'Belirtilmemiş',
        'performansSkoru': 0.0,
        'aktifGorevSayisi': 0,
        'il': '---',
        'ilce': '---',
      };
    } catch (e) {
      return {
        'id': userId,
        'adSoyad': 'Personel',
        'email': 'personel@example.com',
        'rol': 'personel',
        'aktif': false,
        'musait': false,
        'uzmanlikAlani': 'Belirtilmemiş',
        'performansSkoru': 0.0,
        'aktifGorevSayisi': 0,
        'il': '---',
        'ilce': '---',
      };
    }
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineIndicator(ReportState state) {
    if (!state.isBulkOperationInProgress) return SizedBox.shrink();

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

  PersonnelReportModel _mapToReportModel(Map<String, dynamic> data) {
    final annotations = data['admin_annotations'] as List?;
    final adminAnnotations = annotations?.map((a) {
      final map = a as Map<String, dynamic>;
      
      // Parse annotation type from string to enum
      AnnotationType annotationType = AnnotationType.info;
      if (map['annotation_type'] != null || map['type'] != null) {
        try {
          final typeStr = (map['annotation_type'] ?? map['type'])?.toString().toLowerCase();
          annotationType = AnnotationType.values.firstWhere(
            (e) => e.name == typeStr,
            orElse: () => AnnotationType.info,
          );
        } catch (_) {
          annotationType = AnnotationType.info;
        }
      }
      
      return AdminAnnotation(
        id: map['id']?.toString() ?? '',
        reportId: data['id']?.toString() ?? '',
        fieldKey: map['field_key']?.toString() ?? map['id']?.toString() ?? '',
        fieldLabel: map['field_label']?.toString() ?? map['admin_name']?.toString() ?? 'Admin Notu',
        adminNote: map['message']?.toString() ?? map['admin_note']?.toString() ?? '',
        annotationType: annotationType,
        adminId: map['admin_id']?.toString() ?? '',
        adminName: map['admin_name']?.toString() ?? 'Admin',
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'].toString())
            : DateTime.now(),
        severity: AnnotationSeverity.medium,
      );
    }).toList();

    return PersonnelReportModel(
      id: data['id']?.toString() ?? '',
      aracMarkaModel: '${data['arac_marka'] ?? ''} ${data['arac_model'] ?? ''}'.trim(),
      aracPlaka: data['plaka']?.toString() ?? data['arac_plaka']?.toString() ?? '---',
      musteriAdi: data['musteri_adi']?.toString() ?? data['customer_name']?.toString() ?? 'Bilinmiyor',
      durum: data['durum']?.toString() ?? data['status']?.toString() ?? 'Beklemede',
      olusturulma: data['olusturulma'] != null
          ? DateTime.parse(data['olusturulma'].toString())
          : DateTime.now(),
      aciklama: data['aciklama']?.toString() ?? '',
      sehir: data['sehir']?.toString() ?? '',
      adminAnnotations: adminAnnotations,
    );
  }
}

// ========================================
// MODELS
// ========================================

class PersonnelReportModel {
  final String id;
  final String aracMarkaModel;
  final String aracPlaka;
  final String musteriAdi;
  final String durum;
  final DateTime olusturulma;
  final String aciklama;
  final String sehir;
  final List<AdminAnnotation>? adminAnnotations;

  PersonnelReportModel({
    required this.id,
    required this.aracMarkaModel,
    required this.aracPlaka,
    required this.musteriAdi,
    required this.durum,
    required this.olusturulma,
    required this.aciklama,
    required this.sehir,
    this.adminAnnotations,
  });
}

// ========================================
// PROVIDERS
// ========================================

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  // TODO: Replace with UserProvider.currentUser
  return null;
});

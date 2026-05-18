import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/futuristic_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../widgets/status_chip.dart';
import '../../services/personel_service.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

/// PersonelGorevleriScreen - Personel My Tasks View
///
/// FEATURES:
/// - Shows assigned tasks to current personnel
/// - Task filtering by status
/// - Task details view
/// - Navigate to expertiz wizard
class PersonelGorevleriScreen extends StatefulWidget {
  const PersonelGorevleriScreen({super.key});

  @override
  State<PersonelGorevleriScreen> createState() => _PersonelGorevleriScreenState();
}

class _PersonelGorevleriScreenState extends State<PersonelGorevleriScreen> {
  String _selectedStatusFilter = 'Tümü';
  final List<String> _statusOptions = [
    'Tümü',
    'Beklemede',
    'İşlemde',
    'Onay Bekliyor',
    'Tamamlandı',
  ];

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    // Redirect if not logged in
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return const SizedBox.shrink();
    }

    // Redirect non-personnel users
    if (currentUser.role != UserRole.fieldStaff) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(
                'Bu sayfaya sadece personel erişebilir',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // Get tasks from PersonelService
    final personelService = context.watch<PersonelService>();
    final assignedTasks = _getAssignedTasks(personelService, currentUser.id);

    // Filter by status
    final filteredTasks = _selectedStatusFilter == 'Tümü'
        ? assignedTasks
        : assignedTasks.where((t) => t.durum == _selectedStatusFilter).toList();

    return Scaffold(
      backgroundColor: FuturisticTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: FuturisticTheme.bgSecondary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: FuturisticTheme.neon),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Görevlerim',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: FuturisticTheme.neon),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Filter
          Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusOptions.map((status) {
                  final isSelected = _selectedStatusFilter == status;
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = status;
                        });
                      },
                      selectedColor: FuturisticTheme.neon,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: FuturisticTheme.bgSecondary.withValues(alpha: 0.5),
                      side: BorderSide(
                        color: isSelected ? FuturisticTheme.neon : Colors.white54,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Task List
          Expanded(
            child: filteredTasks.isEmpty
                ? _buildEmptyState(_selectedStatusFilter)
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return _buildTaskCard(task, currentUser);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Get assigned tasks for current personnel
  List<AdminRaporTalepModel> _getAssignedTasks(
    PersonelService personelService,
    String currentPersonelId,
  ) {
    // Get all reports from service
    // Note: In production, this would fetch from database
    // For now, use mock data filtered by personelId
    
    // Mock data - replace with actual service call
    final allTasks = <AdminRaporTalepModel>[
      AdminRaporTalepModel(
        id: 'G001',
        baslik: 'BMW 320i Motor İncelemesi',
        musteriAdi: 'Ahmet Yılmaz',
        musteriId: 'M001',
        aracPlaka: '34ABC123',
        durum: 'Beklemede',
        talepTarihi: DateTime.now().subtract(Duration(hours: 2)),
        aciklama: 'Araç çalıştığında motor bölgesinden anormal ses geliyor',
        personelId: currentPersonelId,
        ucret: 2500,
      ),
      AdminRaporTalepModel(
        id: 'G002',
        baslik: 'Mercedes C200 Değerleme Talebi',
        musteriAdi: 'Mehmet Kaya',
        musteriId: 'M002',
        aracPlaka: '06XYZ789',
        durum: 'İşlemde',
        talepTarihi: DateTime.now().subtract(Duration(days: 1)),
        aciklama: 'Satın almak için ekspertiz raporu gerekiyor',
        personelId: currentPersonelId,
        ucret: 3500,
      ),
      AdminRaporTalepModel(
        id: 'G003',
        baslik: 'Audi A4 Kaza Sonrası Hasar Tespiti',
        musteriAdi: 'Ayşe Demir',
        musteriId: 'M003',
        aracPlaka: '34DEF456',
        durum: 'Onay Bekliyor',
        talepTarihi: DateTime.now().subtract(Duration(days: 2)),
        aciklama: 'Arka çamurlukta hafif çizik ve çökme var',
        personelId: currentPersonelId,
        ucret: 4200,
      ),
    ];

    // Filter by current personnel ID
    return allTasks.where((t) => t.personelId == currentPersonelId).toList();
  }

  Widget _buildEmptyState(String filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            color: Colors.white54,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            filter == 'Tümü'
                ? 'Henüz göreviniz yok'
                : '$filter durumunda göreviniz yok',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(AdminRaporTalepModel task, UserModel currentUser) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: GlassCard(
        child: InkWell(
          onTap: () => _navigateToExpertizWizard(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.baslik,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  StatusChip(durum: task.durum),
                ],
              ),
              SizedBox(height: 12),

              // Customer Info
              _buildInfoRow(Icons.person, 'Müşteri', task.musteriAdi),
              SizedBox(height: 8),
              _buildInfoRow(Icons.directions_car, 'Plaka', task.aracPlaka),
              SizedBox(height: 8),
              _buildInfoRow(Icons.calendar_today, 'Tarih', _formatDate(task.talepTarihi)),

              if (task.ucret != null) ...[
                SizedBox(height: 8),
                _buildInfoRow(
                  Icons.attach_money,
                  'Ücret',
                  '₺${task.ucret!.toStringAsFixed(2)}',
                  color: FuturisticTheme.neon,
                ),
              ],

              if (task.aciklama != null && task.aciklama!.isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.aciklama!,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],

              // Action Button
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _navigateToExpertizWizard(task),
                icon: Icon(Icons.play_arrow),
                label: Text(task.durum == 'Beklemede' ? 'Başla' : 'Devam Et'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FuturisticTheme.neon,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white54, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              color: color ?? Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _navigateToExpertizWizard(AdminRaporTalepModel task) {
    // Navigate to expertiz wizard with task data
    // This would navigate to ExpertizSihirbazi widget
    Navigator.of(context).pushNamed(
      '/expertiz-wizard',
      arguments: task,
    );
  }
}

/// AdminRaporTalepModel - Task Model
/// (Temporary model for task display)
class AdminRaporTalepModel {
  final String id;
  final String baslik;
  final String musteriAdi;
  final String musteriId;
  final String aracPlaka;
  final String durum;
  final DateTime talepTarihi;
  final String? aciklama;
  final String? notlar;
  final String? raporUrl;
  final String? personelId;
  final double? ucret;

  AdminRaporTalepModel({
    required this.id,
    required this.baslik,
    required this.musteriAdi,
    required this.musteriId,
    required this.aracPlaka,
    required this.durum,
    required this.talepTarihi,
    this.aciklama,
    this.notlar,
    this.raporUrl,
    this.personelId,
    this.ucret,
  });
}

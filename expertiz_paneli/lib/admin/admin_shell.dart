/// ADMIN SHELL - SYSTEM BORDER CONTROL
/// 
/// ⚠️ NON-NEGOTIABLE: Admin paneline giriş için TEK NOKTA
/// 
/// Sorumluluklar:
/// 1. ROLE GUARD: Sadece admin kullanıcıları içeri alır
/// 2. SINGLE ENTRY POINT: Admin paneline girişi kontrol eder
/// 3. SIDEBAR/DRAWER: Navigation'ı yönetir
/// 4. TAB ROUTING: 8 sekme için modül routing sağlar
/// 
/// ❌ Business logic YOK - Her modül kendi işini halleder
/// ✅ Sadece auth check ve navigation
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cyber/cyber_background.dart';
import '../../core/constants/yerimebak_colors.dart';
import 'unauthorized_screen.dart';
import 'modules/dashboard_module.dart';
import 'modules/arac_operasyonu.dart';
import '../../screens/personel/personel_bolge_sistemi.dart';
import 'modules/musteri_yonetimi_module.dart';
import 'modules/rapor_inceleme_module.dart';
import 'modules/ai_merkezi.dart';
import 'modules/finans_yonetimi.dart';
import 'modules/ayarlar_module.dart';

/// Admin Shell
/// 
/// Sistem'in tek giriş kapısı ve role guard'ı
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // ✅ ROLE GUARD: Sadece admin kullanıcıları içeri al
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // Kullanıcı giriş yapmamışsa
        if (!userProvider.isAuthenticated) {
          return _buildUnauthorizedScreen(context);
        }

        // Kullanıcı admin değilse
        if (!userProvider.isAdmin) {
          return _buildUnauthorizedScreen(context);
        }

        // ✅ TAMAM: Admin kullanıcısı - içeri al
        return CyberBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            key: _scaffoldKey,
            appBar: _buildAppBar(context, isDarkMode, userProvider),
            drawer: _buildDrawer(context, isDarkMode, userProvider),
            body: TabBarView(
              controller: _tabController,
              children: [
                // 8 Modül - Her biri kendi işini halleder
                const DashboardModule(),
                const AracOperasyonu(),
                _buildPersonelModule(context),
                const MusteriYonetimiModule(),
                const RaporIncelemeModule(),
                const AIMerkezi(),
                const FinansYonetimi(),
                const AyarlarModule(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// =====================================================
  // ROLE GUARD
  // =====================================================

  /// Unauthorized screen göster
  Widget _buildUnauthorizedScreen(BuildContext context) {
    return const UnauthorizedScreen();
  }

  /// =====================================================
  // APP BAR
  // =====================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isDarkMode,
    UserProvider userProvider,
  ) {
    return AppBar(
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: YerimeBakColors.blue),
          const SizedBox(width: 10),
          Text(
            'Admin Paneli',
            style: TextStyle(
              color: isDarkMode ? Colors.white : YerimeBakColors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      elevation: 4,
      iconTheme: IconThemeData(color: isDarkMode ? Colors.white : YerimeBakColors.blue),
      actions: [
        // Theme toggle
        IconButton(
          icon: Icon(
            isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: isDarkMode ? Colors.white : YerimeBakColors.blue,
          ),
          onPressed: () => _toggleTheme(context),
          tooltip: isDarkMode ? 'Aydınlık Mod' : 'Gece Modu',
        ),
        // Notifications
        IconButton(
          icon: Icon(
            Icons.notifications,
            color: isDarkMode ? Colors.white : YerimeBakColors.blue,
          ),
          onPressed: () => _showMessage('Bildirimler'),
          tooltip: 'Bildirimler',
        ),
        // Logout
        IconButton(
          icon: Icon(
            Icons.exit_to_app,
            color: isDarkMode ? Colors.white : YerimeBakColors.blue,
          ),
          onPressed: () => _logout(context),
          tooltip: 'Çıkış Yap',
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
          Tab(icon: Icon(Icons.directions_car), text: 'Araç Operasyonu'),
          Tab(icon: Icon(Icons.people), text: 'Personel'),
          Tab(icon: Icon(Icons.person), text: 'Müşteriler'),
          Tab(icon: Icon(Icons.description), text: 'Raporlar'),
          Tab(icon: Icon(Icons.psychology), text: 'AI Merkezi'),
          Tab(icon: Icon(Icons.attach_money), text: 'Finans Yönetimi'),
          Tab(icon: Icon(Icons.settings), text: 'Ayarlar'),
        ],
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  /// =====================================================
  // DRAWER
  // =====================================================

  Widget _buildDrawer(
    BuildContext context,
    bool isDarkMode,
    UserProvider userProvider,
  ) {
    final currentUser = userProvider.currentUser;
    final initials = currentUser?.initials ?? 'A';
    final fullName = currentUser?.fullName ?? 'Admin';

    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: (isDarkMode ? YerimeBakColors.darkGray : YerimeBakColors.blue).withAlpha(204),
              border: const Border(
                right: BorderSide(
                  color: Colors.white24,
                  width: 1.0,
                ),
              ),
            ),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // HEADER
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withAlpha(25)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: YerimeBakColors.cyberNeonTurquoise,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: YerimeBakColors.cyberNeonTurquoise.withAlpha(76),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: YerimeBakColors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Admin Panel
                      const Text(
                        'Admin Panel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      // Kullanıcı adı
                      Text(
                        fullName,
                        style: TextStyle(
                          color: Colors.white.withAlpha(153),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // NAVIGATION ITEMS
                _buildDrawerItem(Icons.dashboard, 'Dashboard', 0, isDarkMode),
                _buildDrawerItem(Icons.directions_car, 'Araç Operasyonu', 1, isDarkMode),
                _buildDrawerItem(Icons.people, 'Personel', 2, isDarkMode),
                _buildDrawerItem(Icons.person, 'Müşteriler', 3, isDarkMode),
                _buildDrawerItem(Icons.description, 'Raporlar', 4, isDarkMode),
                _buildDrawerItem(Icons.psychology, 'AI Merkezi', 5, isDarkMode),
                _buildDrawerItem(Icons.attach_money, 'Finans Yönetimi', 6, isDarkMode),
                _buildDrawerItem(Icons.settings, 'Ayarlar', 7, isDarkMode),

                // DIVIDER
                Divider(color: Colors.white.withAlpha(25), thickness: 1),

                // BOTTOM ACTIONS
                _buildBottomDrawerItem(
                  Icons.help,
                  'Yardım',
                  isDarkMode,
                  () => _showMessage('Yardım'),
                ),
                _buildBottomDrawerItem(
                  Icons.logout,
                  'Çıkış Yap',
                  isDarkMode,
                  () => _logout(context),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Drawer item builder
  Widget _buildDrawerItem(IconData icon, String title, int index, bool isDarkMode) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
              _tabController.animateTo(index);
            });
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(10),
          splashColor: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isSelected
                  ? YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.15)
                  : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
              border: isSelected
                  ? Border.all(
                      color: YerimeBakColors.cyberNeonTurquoise.withValues(alpha: 0.3),
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                // Icon
                Icon(
                  icon,
                  color: isSelected ? YerimeBakColors.cyberNeonTurquoise : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 16),
                // Title
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                      letterSpacing: isSelected ? 0.5 : 0,
                    ),
                  ),
                ),
                // Glowing Indicator Line
                if (isSelected)
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: YerimeBakColors.cyberNeonTurquoise,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: YerimeBakColors.cyberNeonTurquoise,
                          blurRadius: 6,
                          spreadRadius: 2,
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

  /// Bottom drawer item builder
  Widget _buildBottomDrawerItem(
    IconData icon,
    String title,
    bool isDarkMode,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white70,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.redAccent : Colors.white,
        ),
      ),
      onTap: onTap,
      hoverColor: Colors.white.withValues(alpha: 0.05),
    );
  }

  /// =====================================================
  // MODULES
  // =====================================================

  /// Personel modülü - PersonelService'i inject et
  Widget _buildPersonelModule(BuildContext context) {
    return PersonelBolgePaneli(
      personeller: [], // Provider'dan çekilecek
      onPersonelEkle: (p) => _showMessage('Personel eklendi'),
      onPersonelDuzenle: (p) => _showMessage('Personel düzenlendi'),
      onPersonelSil: (p) => _showMessage('Personel silindi'),
      onPersonelAktiflikDegistir: (p) => _showMessage('Personel durumu değiştirildi'),
    );
  }

  /// =====================================================
  // ACTIONS
  // =====================================================

  /// Theme toggle
  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  /// Logout
  void _logout(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.logout();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  /// Show message
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
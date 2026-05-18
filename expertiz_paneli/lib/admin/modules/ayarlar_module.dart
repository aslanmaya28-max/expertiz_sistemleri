/// AYARLAR MODULE
/// 
/// Sistem ayarları ekranı
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/theme_provider.dart';

/// Ayarlar Module
class AyarlarModule extends StatelessWidget {
  const AyarlarModule({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sistem Ayarları',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),

          // TEMA AYARLARI
          Card(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tema Ayarları',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildThemeCard(
                        '☀️ Aydınlık Mod',
                        'Açık renk teması',
                        Icons.light_mode,
                        Colors.blue[100]!,
                        false,
                        () => _toggleTheme(context),
                        isDarkMode,
                      ),
                      _buildThemeCard(
                        '🌙 Gece Modu',
                        'Koyu renk teması',
                        Icons.dark_mode,
                        Colors.grey[900]!,
                        true,
                        () => _toggleTheme(context),
                        isDarkMode,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Seçili Tema: ${isDarkMode ? "Gece Modu" : "Aydınlık Mod"}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // GENEL AYARLAR
          Card(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Genel Ayarlar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: Text(
                      'Bildirimler',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    subtitle: Text(
                      'Sistem bildirimlerini aç/kapat',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    value: true,
                    onChanged: (val) {},
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.language,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    title: Text(
                      'Dil Seçeneği',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    subtitle: const Text('Türkçe'),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // GÜVENLİK AYARLARI
          Card(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Güvenlik Ayarları',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.lock,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    title: Text(
                      'Şifre Değiştir',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    onTap: () => _showMessage(context, 'Şifre değiştirme'),
                  ),
                  SwitchListTile(
                    title: Text(
                      'İki Aşamalı Doğrulama',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    subtitle: Text(
                      'Ek güvenlik için',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    value: false,
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // SİSTEM BİLGİLERİ
          Card(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistem Bilgileri',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: Icon(
                      Icons.info,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    title: Text(
                      'Versiyon',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    subtitle: const Text('v1.0.0'),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.update,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    title: Text(
                      'Son Güncelleme',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    subtitle: Text(
                      DateTime.now().toString().substring(0, 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
    VoidCallback onTap,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145,
        height: 145,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: isDark
              ? Border.all(color: Colors.blue, width: 3)
              : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: color == Colors.grey[900] ? Colors.white : Colors.black,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: color == Colors.grey[900] ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: color == Colors.grey[900] ? Colors.white70 : Colors.black54,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
              if (isDark) ...[
                const SizedBox(height: 5),
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTheme(BuildContext context) {
    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
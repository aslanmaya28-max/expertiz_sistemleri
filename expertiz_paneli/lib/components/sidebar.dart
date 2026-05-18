import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/app_menu_controller.dart';
import '../constants.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final role = context.read<AppMenuController>().currentRole;
    
    return Drawer(
      child: Container(
        color: secondaryColor,
        child: ListView(
          children: [
            // Logo Alanı - DÜZELTİLDİ: Overflow sorunu çözüldü
            DrawerHeader(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: secondaryColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo - KÜÇÜLTÜLDÜ
                  Container(
                    width: 60, // 80'den 60'a küçültüldü
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        "ES",
                        style: TextStyle(
                          fontSize: 24, // 32'den 24'e küçültüldü
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Sistem Adı - FONT KÜÇÜLTÜLDÜ
                  Text(
                    "EXPERTİZ SİSTEMİ",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12, // 14'ten 12'ye küçültüldü
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Rol Bilgisi - FONT KÜÇÜLTÜLDÜ
                  Text(
                    role == 'admin' ? 'Admin Paneli' :
                    role == 'personel' ? 'Personel Paneli' : 'Müşteri Paneli',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 14, // 16'dan 14'e küçültüldü
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Admin Menü Öğeleri
            if (role == 'admin') ...[
              _buildMenuTile(Icons.dashboard, "Dashboard", () {
                // Navigasyon eklenebilir
              }),
              _buildMenuTile(Icons.directions_car, "Araç Yönetimi", () {}),
              _buildMenuTile(Icons.people, "Personel Yönetimi", () {}),
              _buildMenuTile(Icons.person, "Müşteri Yönetimi", () {}),
              _buildMenuTile(Icons.description, "Raporlar", () {}),
              _buildMenuTile(Icons.settings, "Ayarlar", () {}),
            ],
            
            // Personel Menü Öğeleri
            if (role == 'personel') ...[
              _buildMenuTile(Icons.task, "Görevlerim", () {}),
              _buildMenuTile(Icons.directions_car, "Atanan Araçlar", () {}),
              _buildMenuTile(Icons.note_add, "Rapor Oluştur", () {}),
              _buildMenuTile(Icons.analytics, "İstatistiklerim", () {}),
            ],
            
            // Müşteri Menü Öğeleri
            if (role == 'musteri') ...[
              _buildMenuTile(Icons.directions_car, "Araçlarım", () {}),
              _buildMenuTile(Icons.history, "Rapor Geçmişim", () {}),
              _buildMenuTile(Icons.notifications, "Taleplerim", () {}),
              _buildMenuTile(Icons.person, "Profilim", () {}),
            ],
            
            const SizedBox(height: 20),
            
            // Çıkış Butonu - YENİ EKLENDİ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Çıkış Yap'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () {
                  // Çıkış işlemi - LoginScreen'e yönlendir
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/login', 
                    (route) => false
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Rol Değiştirici (Demo)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo: Rol Değiştir',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildRoleButton(context, 'Admin', 'admin'),
                      const SizedBox(width: 8),
                      _buildRoleButton(context, 'Personel', 'personel'),
                      const SizedBox(width: 8),
                      _buildRoleButton(context, 'Müşteri', 'musteri'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Versiyon Bilgisi
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      horizontalTitleGap: 0.0,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white54, size: 20),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white70),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.white30,
        size: 18,
      ),
    );
  }
  
  Widget _buildRoleButton(BuildContext context, String text, String role) {
    final currentRole = context.read<AppMenuController>().currentRole;
    final isActive = currentRole == role;
    
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          context.read<AppMenuController>().setRole(role);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? primaryColor : Colors.white10,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }
}
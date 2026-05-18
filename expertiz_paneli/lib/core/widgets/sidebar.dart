import 'package:flutter/material.dart';
import '../constants/roles.dart' as roles;

class Sidebar extends StatelessWidget {
  final roles.UserRole role;
  const Sidebar({super.key, required this.role});

  List<String> get menu {
    switch (role) {
      case roles.UserRole.admin:
        return ['Dashboard', 'Kullanıcılar', 'Raporlar', 'Ayarlar'];
      case roles.UserRole.fieldStaff:
        return ['Dashboard', 'Görevler', 'Raporlar'];
      case roles.UserRole.customer:
        return ['Dashboard', 'Raporlarım', 'Mesajlar', 'Profil'];
      case roles.UserRole.unauthorized:
        return [];
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 220,
        color: Colors.black.withValues(alpha: 0.4),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: menu
                .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(e, style: const TextStyle(color: Colors.white70)),
                        ))
                .toList(),
        ),
    );
  }
}

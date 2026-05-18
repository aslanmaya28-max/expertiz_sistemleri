import 'package:flutter/material.dart';
import '../admin/admin_shell.dart';

// AnaSayfa artık doğrudan Admin Paneline yönlendiriyor veya onun sarmalayıcısı oluyor.
// Çünkü main.dart'ta admin ve yöneticiler buraya yönlendiriliyor.
class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShell();
  }
}
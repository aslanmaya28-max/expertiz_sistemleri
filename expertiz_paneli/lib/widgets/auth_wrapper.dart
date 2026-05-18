/// AUTH WRAPPER - SINGLE SOURCE OF TRUTH
///
/// Kullanıcı oturum durumuna göre doğru ekrana yönlendirir.
/// UserProvider üzerinden çalışır - AuthServicePro KULLANMAZ.
///
/// ⚠️ NON-NEGOTIABLE: Bu dosya UserProvider dışında bir auth servisi kullanamaz.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../personnel/personnel_panel.dart';
import '../customer/customer_dashboard.dart';
import '../core/constants/roles.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.fieldStaff:
        return const PersonnelPanel();
      case UserRole.customer:
        return const CustomerDashboard();
      case UserRole.unauthorized:
        return const LoginScreen();
    }
  }
}

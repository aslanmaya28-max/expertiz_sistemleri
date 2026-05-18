import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/roles.dart';
import '../../providers/expertiz_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/expertiz_akisi/expertiz_baslat_sayfasi.dart';
import '../../screens/login_screen.dart';

/// Legacy compatibility wrapper.
///
/// The official personnel inspection flow is:
/// PersonnelDashboard -> ExpertizBaslatSayfasi -> ExpertizProvider.
/// This wrapper keeps older routes/imports working while preventing the old
/// local-only PersonelService.submitTamRapor path from being used.
class ExpertizSihirbazi extends StatelessWidget {
  final String gorevId;
  final String musteriAdi;
  final String aracPlaka;

  const ExpertizSihirbazi({
    super.key,
    required this.gorevId,
    required this.musteriAdi,
    required this.aracPlaka,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      });
      return const SizedBox.shrink();
    }

    if (currentUser.role != UserRole.fieldStaff) {
      return const Scaffold(
        body: Center(
          child: Text('Bu sayfaya sadece personel erisebilir'),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ExpertizProvider(),
      child: ExpertizBaslatSayfasi(
        gorevId: gorevId,
        personelId: currentUser.id,
        personelAdi: currentUser.fullName,
        musteriAdi: musteriAdi,
        aracPlakasi: aracPlaka,
      ),
    );
  }
}

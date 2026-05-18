import 'package:flutter/material.dart';
import '../theme/futuristic_theme.dart';
import '../widgets/sidebar.dart';
import '../constants/roles.dart' as roles;
  
class BaseScaffold extends StatelessWidget {
  final Widget body;
  final roles.UserRole role;
  final PreferredSizeWidget? appBar;
  
  const BaseScaffold({
    super.key, 
    required this.body, 
    required this.role,
    this.appBar,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FuturisticTheme.loginBgStart,
              FuturisticTheme.loginBgEnd,
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: Row(
            children: [
              Sidebar(role: role),
              Expanded(child: body),
            ],
          ),
        ),
    );
  }
}

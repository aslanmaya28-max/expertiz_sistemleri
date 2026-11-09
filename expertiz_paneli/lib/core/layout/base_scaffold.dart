import 'package:flutter/material.dart';
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
    return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              Sidebar(role: role),
              Expanded(child: body),
            ],
          ),
    );
  }
}

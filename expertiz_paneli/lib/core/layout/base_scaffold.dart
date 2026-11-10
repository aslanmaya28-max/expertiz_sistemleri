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
    final compact = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      appBar: appBar,
      drawer:
          compact ? Drawer(child: SafeArea(child: Sidebar(role: role))) : null,
      body: Row(
        children: [
          if (!compact) Sidebar(role: role),
          Expanded(child: body),
        ],
      ),
    );
  }
}

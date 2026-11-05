import 'package:flutter/material.dart';
import 'islem_butonu.dart';

class AnaButon extends StatelessWidget {
  final String label;
  final Future<void> Function()? action;
  final bool destructive;
  final IconData? icon;
  const AnaButon(
    this.label,
    this.action, {
    super.key,
    this.destructive = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => IslemButonu(
    label,
    action,
    primary: true,
    destructive: destructive,
    icon: icon,
  );
}

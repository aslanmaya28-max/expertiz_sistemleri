import 'package:flutter/material.dart';
import 'islem_butonu.dart';
class IkincilButon extends StatelessWidget {
  final String label;
  final Future<void> Function()? action;
  final IconData? icon;
  const IkincilButon(this.label,this.action,{super.key,this.icon});
  @override Widget build(BuildContext context) => IslemButonu(label,action,primary:false,icon:icon);
}

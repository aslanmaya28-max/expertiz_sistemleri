import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class YbArama extends StatelessWidget {
  const YbArama(
      {super.key, this.controller, this.onChanged, this.ipucu = 'Ara…'});
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String ipucu;
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
          hintText: ipucu,
          prefixIcon: const Icon(LucideIcons.search),
          isDense: true));
}

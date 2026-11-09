import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

class YbGirdi extends StatelessWidget {
  const YbGirdi(
      {super.key,
      required this.etiket,
      this.controller,
      this.ipucu,
      this.validator,
      this.obscureText = false,
      this.prefixIcon,
      this.suffixIcon,
      this.onChanged,
      this.keyboardType,
      this.maxLines = 1,
      this.enabled = true});
  final String etiket;
  final TextEditingController? controller;
  final String? ipucu;
  final FormFieldValidator<String>? validator;
  final bool obscureText, enabled;
  final Widget? prefixIcon, suffixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(etiket,
                style: Yazilar.etiket
                    .copyWith(color: context.renkler.metinIkincil)),
            const SizedBox(height: Olcu.s8),
            TextFormField(
                controller: controller,
                validator: validator,
                obscureText: obscureText,
                enabled: enabled,
                maxLines: maxLines,
                onChanged: onChanged,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                    hintText: ipucu,
                    prefixIcon: prefixIcon,
                    suffixIcon: suffixIcon,
                    isDense: true)),
          ]);
}

import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';

class MetinKutusu extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool password;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final Widget? suffix;
  const MetinKutusu(
    this.label,
    this.controller, {
    super.key,
    this.password = false,
    this.keyboard,
    this.validator,
    this.suffix,
  });
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: Olcu.girdi),
    child: TextFormField(
      controller: controller,
      obscureText: password,
      keyboardType: keyboard,
      enableSuggestions: !password,
      autocorrect: !password,
      style: Yazilar.govde,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: suffix,
      ),
      validator:
          validator ??
          (v) =>
              v == null || v.trim().isEmpty ? '$label alanını doldurun.' : null,
    ),
  );
}

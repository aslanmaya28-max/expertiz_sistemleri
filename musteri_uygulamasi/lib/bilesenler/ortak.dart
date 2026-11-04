import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

String money(dynamic value) =>
    value is num ? '${NumberFormat('#,##0', 'tr_TR').format(value)} TL' : '—';
String number(dynamic value) =>
    value is num ? NumberFormat('#,##0.#', 'tr_TR').format(value) : '—';
String dateText(DateTime? value) => value == null
    ? 'Tarih belirtilmemiş'
    : DateFormat('d MMMM yyyy', 'tr_TR').format(value.toLocal());
String percent(dynamic value) =>
    value is num ? '%${NumberFormat('#,##0.#', 'tr_TR').format(value)}' : '—';

class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Olcu.azamiIcerik),
      child: Padding(padding: const EdgeInsets.all(Olcu.sayfa), child: child),
    ),
  );
}

class Panel extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Panel(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Olcu.kartArasi),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(Olcu.kartIci),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: Olcu.s12),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class ValueLine extends StatelessWidget {
  final String label, value;
  const ValueLine(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Olcu.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Yazilar.etiket.copyWith(
            color: YbRenkler.of(context).metinIkincil,
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}

class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList(this.items, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: Olcu.s8),
          child: Text('• $item'),
        ),
    ],
  );
}

class FailureView extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const FailureView(this.error, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Panel('İşlem tamamlanamadı', [
    Text(error.toString(), semanticsLabel: error.toString()),
    const SizedBox(height: Olcu.s12),
    OutlinedButton(onPressed: retry, child: const Text('Tekrar dene')),
  ]);
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Yükleniyor',
    liveRegion: true,
    child: Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: Olcu.s12),
          child: Card(
            child: SizedBox(width: double.infinity, height: Olcu.anaButon),
          ),
        ),
      ),
    ),
  );
}

class ActionButton extends StatefulWidget {
  final String label;
  final Future<void> Function()? action;
  final bool destructive;
  const ActionButton(
    this.label,
    this.action, {
    super.key,
    this.destructive = false,
  });
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: widget.destructive
        ? FilledButton.styleFrom(
            backgroundColor: YbRenkler.of(context).tehlike,
            foregroundColor: YbRenkler.of(context).tehlikeYuzey,
          )
        : null,
    onPressed: busy || widget.action == null
        ? null
        : () async {
            setState(() => busy = true);
            try {
              await widget.action!();
            } catch (e) {
              if (context.mounted) showMessage(context, e.toString());
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
    child: busy
        ? Semantics(
            label: '${widget.label} işlemi sürüyor',
            child: const SizedBox(
              width: Olcu.ikon,
              height: Olcu.ikon,
              child: CircularProgressIndicator(),
            ),
          )
        : Text(widget.label),
  );
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

class FormFieldView extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool password;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  const FormFieldView(
    this.label,
    this.controller, {
    super.key,
    this.password = false,
    this.keyboard,
    this.validator,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Olcu.s16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      obscureText: password,
      enableSuggestions: !password,
      autocorrect: !password,
      keyboardType: keyboard,
      validator:
          validator ??
          (v) =>
              v == null || v.trim().isEmpty ? '$label alanını doldurun.' : null,
    ),
  );
}

import 'package:flutter/material.dart';
import '../tema/olculer.dart';
import '../tema/renkler.dart';
import '../tema/yazi.dart';

class IslemButonu extends StatefulWidget {
  final String label;
  final Future<void> Function()? action;
  final bool primary, destructive;
  final IconData? icon;
  const IslemButonu(
    this.label,
    this.action, {
    super.key,
    required this.primary,
    this.destructive = false,
    this.icon,
  });
  @override
  State<IslemButonu> createState() => _IslemButonuState();
}

class _IslemButonuState extends State<IslemButonu> {
  bool busy = false;
  Future<void> _run() async {
    if (busy || widget.action == null) return;
    setState(() => busy = true);
    try {
      await widget.action!();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = YbRenkler.of(context);
    final child = busy
        ? Semantics(
            label: '${widget.label} işlemi sürüyor',
            child: const SizedBox(
              width: Olcu.ikon,
              height: Olcu.ikon,
              child: CircularProgressIndicator(strokeWidth: Olcu.odakKenar),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: Olcu.ikonInce),
                const SizedBox(width: Olcu.s8),
              ],
              Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
            ],
          );
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(
          double.infinity,
          widget.primary ? Olcu.anaButon : Olcu.ikincilButon,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Olcu.s16, vertical: Olcu.s12),
      ),
      textStyle: const WidgetStatePropertyAll(Yazilar.buton),
    );
    return widget.primary
        ? FilledButton(
            style: style.copyWith(
              backgroundColor: widget.destructive
                  ? WidgetStatePropertyAll(r.tehlike)
                  : null,
              foregroundColor: widget.destructive
                  ? WidgetStatePropertyAll(r.tehlikeYuzey)
                  : null,
            ),
            onPressed: busy || widget.action == null ? null : _run,
            child: child,
          )
        : OutlinedButton(
            style: style,
            onPressed: busy || widget.action == null ? null : _run,
            child: child,
          );
  }
}

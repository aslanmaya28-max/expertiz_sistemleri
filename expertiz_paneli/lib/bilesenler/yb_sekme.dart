import 'package:flutter/material.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';

class YbSekme extends StatelessWidget {
  const YbSekme(
      {super.key,
      required this.sekmeler,
      required this.secili,
      required this.onChanged});
  final List<String> sekmeler;
  final int secili;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < sekmeler.length; i++)
            Semantics(
                selected: secili == i,
                button: true,
                child: InkWell(
                    onTap: () => onChanged(i),
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Olcu.s16, vertical: Olcu.s12),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: secili == i ? r.birincil : r.ayirici,
                                    width: secili == i
                                        ? Olcu.vurguluKenar
                                        : Olcu.kenar))),
                        child: Text(sekmeler[i],
                            style: TextStyle(
                                color: secili == i
                                    ? r.birincilMetin
                                    : r.metinIkincil,
                                fontWeight: secili == i
                                    ? FontWeight.w600
                                    : FontWeight.w500)))))
        ]));
  }
}

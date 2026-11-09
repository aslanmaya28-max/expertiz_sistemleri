import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../tema/renkler.dart';
import '../tema/olculer.dart';
import '../tema/yazi.dart';
import 'yb_bos_durum.dart';

class YbTablo extends StatelessWidget {
  const YbTablo(
      {super.key,
      required this.columns,
      required this.rows,
      this.bosMesaj = 'Kayıt bulunamadı',
      this.sayfa = 0,
      this.sayfaBoyutu = 10,
      this.onPageChanged})
      : assert(sayfaBoyutu > 0);
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String bosMesaj;
  final int sayfa, sayfaBoyutu;
  final ValueChanged<int>? onPageChanged;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final pageCount = math.max(1, (rows.length / sayfaBoyutu).ceil());
    final current = sayfa.clamp(0, pageCount - 1);
    final visibleRows = onPageChanged == null
        ? rows
        : rows.skip(current * sayfaBoyutu).take(sayfaBoyutu).toList();
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows.isEmpty)
            YbBosDurum(mesaj: bosMesaj)
          else
            LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minWidth: constraints.hasBoundedWidth
                                ? constraints.maxWidth
                                : 0),
                        child: DataTable(
                          columns: columns
                              .map((column) => DataColumn(
                                  label: DefaultTextStyle.merge(
                                      style: Yazilar.kucuk
                                          .copyWith(color: r.metinIkincil),
                                      child: column.label is Text && (column.label as Text).data != null ? Text((column.label as Text).data!.replaceAll('i', 'İ').toUpperCase()) : column.label),
                                  tooltip: column.tooltip,
                                  numeric: column.numeric,
                                  onSort: column.onSort))
                              .toList(),
                          rows: visibleRows,
                          headingRowColor: WidgetStatePropertyAll(r.yuzey),
                          headingTextStyle:
                              Yazilar.kucuk.copyWith(color: r.metinIkincil),
                          dataTextStyle:
                              Yazilar.govdeKucuk.copyWith(color: r.metin),
                          dataRowMinHeight: PanelOlcu.satir,
                          dataRowMaxHeight: PanelOlcu.satir + Olcu.s12,
                          dataRowColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.hovered)
                                  ? r.yuzeyIkincil
                                  : null),
                          dividerThickness: Olcu.kenar,
                          horizontalMargin: Olcu.s20,
                          columnSpacing: Olcu.s24,
                          border: TableBorder(
                              horizontalInside: BorderSide(color: r.ayirici)),
                        )))),
          if (onPageChanged != null)
            Padding(
                padding: const EdgeInsets.all(Olcu.s12),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(
                      child: Text(
                          '${rows.length} kayıt · ${current + 1} / $pageCount',
                          style:
                              Yazilar.etiket.copyWith(color: r.metinIkincil))),
                  const SizedBox(width: Olcu.s12),
                  IconButton(
                      tooltip: 'Önceki sayfa',
                      onPressed: current > 0
                          ? () => onPageChanged!(current - 1)
                          : null,
                      icon: const Icon(LucideIcons.chevronLeft)),
                  IconButton(
                      tooltip: 'Sonraki sayfa',
                      onPressed: current + 1 < pageCount
                          ? () => onPageChanged!(current + 1)
                          : null,
                      icon: const Icon(LucideIcons.chevronRight)),
                ])),
        ]);
  }
}



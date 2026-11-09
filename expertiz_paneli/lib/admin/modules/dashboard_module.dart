import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/dashboard_stats.dart';
import '../../services/yerimebak_expertiz_api_service.dart';
import '../../tema/renkler.dart';
import '../../bilesenler/bilesenler.dart';

class DashboardModule extends StatefulWidget {
  const DashboardModule(
      {super.key,
      this.apiService,
      this.displayName,
      this.email,
      this.onNavigate,
      this.onUpdated});
  final YerimebakExpertizApiService? apiService;
  final String? displayName;
  final String? email;
  final void Function(String page, String? filter)? onNavigate;
  final VoidCallback? onUpdated;
  @override
  State<DashboardModule> createState() => _DashboardModuleState();
}

class _DashboardModuleState extends State<DashboardModule> {
  late final YerimebakExpertizApiService _api;
  Timer? _refresh;
  DashboardOzet? _ozet;
  List<RecentActivity> _activities = [];
  int _pending = 0;
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  bool _valuations = true, _customers = true;
  int? _hover;
  @override
  void initState() {
    super.initState();
    _api = widget.apiService ?? YerimebakExpertizApiService();
    _load();
    _refresh =
        Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent && _ozet == null) setState(() => _loading = true);
    try {
      final data = await _api.getAdminDashboard();
      if (!mounted) return;
      setState(() {
        _ozet = DashboardOzet.fromResponse(data);
        final pending = data['pending_admin'];
        _pending = pending is List
            ? pending.length
            : (pending is num ? pending.toInt() : 0);
        final distribution = data['status_distribution'];
        if (distribution is Map && distribution['pending_admin'] is num) {
          _pending = (distribution['pending_admin'] as num).toInt();
        }
        _activities = [
          for (final row in data['recent_activities'] is List
              ? data['recent_activities'] as List
              : const [])
            if (row is Map)
              RecentActivity.fromMap({
                ...Map<String, dynamic>.from(row),
                'id': '${row['id'] ?? ''}',
                'title': '${row['title'] ?? 'Sistem işlemi'}',
                'description': '${row['description'] ?? ''}'
              })
        ];
        _error = null;
        _loading = false;
      });
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ana sayfa verileri yüklenemedi';
          _loading = false;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  Duration _duration(int ms) => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: ms);
  void _open(String page, [String? filter]) =>
      widget.onNavigate?.call(page, filter);
  String _number(num v) => NumberFormat.decimalPattern('tr_TR').format(v);
  Widget _counter(num? value, {bool money = false}) =>
      _AnimatedNumber(value: value, money: money, duration: _duration(700));
  Widget _stat(String title, num? value, String detail, String page, int index,
      {bool money = false, List<double> points = const [], required IconData icon}) {
    final r = context.renkler;
    final card = YbKart(
        onTap: () => _open(page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: r.metinIkincil))),
            Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: r.birincilYuzey,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: r.birincilMetin)),
          ]),
          const SizedBox(height: 10),
          _counter(value, money: money),
          const SizedBox(height: 8),
          ConstrainedBox(constraints: BoxConstraints(minHeight: 40 * MediaQuery.textScalerOf(context).scale(1)),
            child: Text(detail, style: TextStyle(fontSize: 13, color: r.metinIkincil))),
          const SizedBox(height: 18),
          SizedBox(
              height: 32,
              child: points.isEmpty
                  ? const SizedBox()
                  : _reveal(_line(points, r.birincil, mini: true)))
        ]));
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: _duration(220 + index * 60),
        curve: Curves.linear,
        builder: (context, v, child) {
          final progress = MediaQuery.disableAnimationsOf(context) ? 1.0 : Curves.easeOutCubic.transform(
              ((v * (220 + index * 60) - index * 60) / 220).clamp(0.0, 1.0));
          return Opacity(
              opacity: progress,
              child: Transform.translate(
                  offset: Offset(0, 8 * (1 - progress)), child: child));
        },
        child: card);
  }

  Widget _reveal(Widget child) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _duration(800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) =>
          ClipRect(clipper: _RevealClipper(value), child: child));
  Widget _line(List<double> values, Color color, {bool mini = false}) =>
      LineChart(
          LineChartData(
              minY: 0,
              maxY: values.fold<double>(1, math.max) * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                    spots: [
                      for (var i = 0; i < values.length; i++)
                        FlSpot(i.toDouble(), values[i])
                    ],
                    color: color,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    barWidth: mini ? 1.5 : 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: !mini, color: color.withValues(alpha: .12)))
              ]),
          duration: _duration(300));
  Widget _daily() {
    final r = context.renkler;
    final days = _ozet?.gunluk ?? [];
    final maxY = days.fold<double>(
            1, (v, d) => math.max(v, math.max(d.degerleme, d.yeniMusteri))) *
        1.2;
    final chart = LineChart(
        LineChartData(
            minX: 0,
            maxX: math.max(1, days.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: r.ayirici, strokeWidth: 1)),
            titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, m) => Text(
                            v == v.roundToDouble() ? '${v.toInt()}' : '',
                            style: TextStyle(
                                fontSize: 12, color: r.metinIkincil)))),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: days.length > 7 ? 3 : 1,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (days.length > 7 && i == days.length - 1) return const SizedBox.shrink();
                          return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                  i >= 0 && i < days.length
                                      ? DateFormat('d MMM', 'tr_TR')
                                          .format(days[i].tarih)
                                      : '',
                                  style: TextStyle(
                                      fontSize: 12, color: r.metinIkincil)));
                        }))),
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => r.yuzeyIkincil,
                    getTooltipItems: (spots) => spots.map((spot) {
                          if (spot != spots.first) return null;
                          final day = days[spot.x.toInt()];
                          return LineTooltipItem(
                              '${DateFormat('d MMM', 'tr_TR').format(day.tarih)} · ${_number(day.degerleme)} değerleme · ${_number(day.yeniMusteri)} yeni müşteri',
                              TextStyle(fontSize: 12, color: r.metin));
                        }).toList())),
            lineBarsData: [
              if (_valuations)
                LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++)
                        FlSpot(i.toDouble(), days[i].degerleme)
                    ],
                    color: r.birincil,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true, color: r.birincil.withValues(alpha: .12))),
              if (_customers)
                LineChartBarData(
                    spots: [
                      for (var i = 0; i < days.length; i++)
                        FlSpot(i.toDouble(), days[i].yeniMusteri)
                    ],
                    color: r.vurgu,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    barWidth: 1.5,
                    dotData: const FlDotData(show: false)),
            ]),
        duration: _duration(300));
    return YbKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            const Text('Son 14 gün',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Wrap(spacing: 8, children: [
              FilterChip(
                  label: const Text('Değerleme'),
                  selected: _valuations,
                  onSelected: (v) => setState(() => _valuations = v)),
              FilterChip(
                  label: const Text('Müşteri'),
                  selected: _customers,
                  onSelected: (v) => setState(() => _customers = v))
            ])
          ]),
      const SizedBox(height: 28),
      SizedBox(
          height: 230,
          child: days.isEmpty
              ? Center(
                  child: Text('Günlük veri henüz yok',
                      style: TextStyle(color: r.metinIkincil)))
              : _reveal(chart))
    ]));
  }

  Widget _attention() {
    final o = _ozet;
    final rows = <({String text, String page, String? filter})>[
      if ((o?.ekspertiz['waiting_assignment'] ?? 0) > 0)
        (
          text: '${o!.ekspertiz['waiting_assignment']} talep atama bekliyor',
          page: 'talepler',
          filter: 'waiting_assignment'
        ),
      if ((o?.ekspertiz['arac_bulunamadi'] ?? 0) > 0)
        (
          text:
              '${o!.ekspertiz['arac_bulunamadi']} araç bulunamadı — iade kararı bekliyor',
          page: 'talepler',
          filter: 'arac_bulunamadi'
        ),
      if ((o?.krediSatisi['bekleyen_havale'] ?? 0) > 0)
        (
          text: '${o!.krediSatisi['bekleyen_havale']} havale onay bekliyor',
          page: 'finans',
          filter: 'bekleyen_havale'
        ),
      if (_pending > 0)
        (
          text: '$_pending rapor onay bekliyor',
          page: 'talepler',
          filter: 'pending_approval'
        ),
    ];
    return YbKart(
        baslik: 'Dikkat isteyenler',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (o == null)
            const Text('Özet verisi henüz sunulmuyor')
          else if (rows.isEmpty)
            const Text('Bekleyen iş yok'),
            for (final row in rows)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                      onTap: () => _open(row.page, row.filter),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: context.renkler.uyariYuzey,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            Icon(LucideIcons.circleAlert,
                                color: context.renkler.uyari, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(row.text,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: context.renkler.uyari))),
                            Icon(LucideIcons.arrowUpRight,
                                size: 16, color: context.renkler.uyari)
                          ]))))
        ]));
  }

  Widget _donut() {
    final r = context.renkler;
    if (_ozet == null) {
      return const YbKart(baslik: 'Ekspertiz talepleri', child: Text('Ekspertiz özeti henüz sunulmuyor'));
    }
    const keys = [
      'waiting_assignment',
      'in_progress',
      'pending_approval',
      'completed',
      'cancelled'
    ];
    const labels = [
      'Atama bekliyor',
      'Sürüyor',
      'Onay bekliyor',
      'Tamamlandı',
      'İptal'
    ];
    final colors = [r.uyari, r.bilgi, r.vurgu, r.birincil, r.metinIkincil];
    final values = [
      for (final k in keys) (_ozet?.ekspertiz[k] ?? 0).toDouble()
    ];
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total == 0) {
      return const YbKart(
          baslik: 'Ekspertiz talepleri',
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text('Henüz ekspertiz talebi yok')));
    }
    return YbKart(
        baslik: 'Ekspertiz talepleri',
        child: Column(children: [
          SizedBox(
              height: 190,
              child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: _duration(800),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) =>
                      Stack(alignment: Alignment.center, children: [
                        PieChart(
                            PieChartData(
                                startDegreeOffset: -90,
                                sectionsSpace: 3,
                                centerSpaceRadius: 55,
                                pieTouchData: PieTouchData(
                                    touchCallback: (event, response) =>
                                        setState(() => _hover =
                                            event.isInterestedForInteractions
                                                ? response?.touchedSection
                                                    ?.touchedSectionIndex
                                                : null)),
                                sections: [
                                  for (var i = 0; i < 5; i++)
                                    PieChartSectionData(
                                        value: values[i] * t,
                                        color: colors[i],
                                        showTitle: false,
                                        radius: _hover == i ? 28 : 24),
                                  if (t < 1)
                                    PieChartSectionData(
                                        value: total * (1 - t),
                                        color: r.yuzey,
                                        showTitle: false,
                                        radius: 24)
                                ]),
                            duration: _duration(300)),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              _number(
                                  _hover != null && _hover! >= 0 && _hover! < 5
                                      ? values[_hover!]
                                      : total),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ])),
                          Text(
                              _hover != null && _hover! >= 0 && _hover! < 5
                                  ? labels[_hover!]
                                  : 'Toplam',
                              style: TextStyle(
                                  fontSize: 12, color: r.metinIkincil))
                        ])
                      ]))),
          const SizedBox(height: 16),
          for (var i = 0; i < 5; i++)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: colors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(labels[i],
                          style: const TextStyle(fontSize: 13))),
                  Text(_number(values[i]),
                      style: const TextStyle(
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()]))
                ]))
        ]));
  }

  Widget _timeline() => YbKart(
        baslik: 'Son işlemler',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_activities.isEmpty)
            Text('Henüz işlem yok',
                style: TextStyle(color: context.renkler.metinIkincil)),
          for (final activity in _activities.take(5))
            Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: BoxDecoration(
                              color: context.renkler.birincil,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(
                              padding: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                  border: Border(
                                      left: BorderSide(
                                          color: context.renkler.ayirici))),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activity.title,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    if (activity.description.isNotEmpty)
                                      Text(activity.description,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: context
                                                  .renkler.metinIkincil)),
                                    const SizedBox(height: 4),
                                    Text(activity.timeAgo,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                context.renkler.metinIkincil)),
                                  ]))),
                    ])),
        ]),
      );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final raw = widget.displayName?.trim() ?? '';
    final name = raw.isNotEmpty
        ? raw.split(' ').first
        : (widget.email?.split('@').first ?? 'Yönetici');
    final greeting = now.hour < 12
        ? 'Günaydın'
        : now.hour < 18
            ? 'İyi günler'
            : 'İyi akşamlar';
    final o = _ozet;
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$greeting, $name',
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(now),
                  style: TextStyle(
                      fontSize: 13, color: context.renkler.metinIkincil))
            ]),
            IconButton(
                tooltip: 'Ana sayfayı yenile',
                onPressed: () => _load(),
                icon: const Icon(LucideIcons.refreshCw, size: 20))
          ]),
      const SizedBox(height: 28),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: YbBosDurum(
                mesaj: _error!,
                eylem: 'Tekrar dene',
                onPressed: () => _load())),
      if (_loading)
        Wrap(spacing: 16, runSpacing: 16, children: [
          for (var i = 0; i < 4; i++)
            const SizedBox(
                width: 230,
                child: YbKart(
                    child: Column(children: [
                  YbIskelet(height: 18),
                  SizedBox(height: 16),
                  YbIskelet(height: 36),
                  SizedBox(height: 16),
                  YbIskelet(height: 24)
                ])))
        ])
      else ...[
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth >= 1000
              ? 4
              : c.maxWidth >= 550
                  ? 2
                  : 1;
          final width = (c.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(
                width: width,
                child: _stat(
                    'Yeni müşteri',
                    o?.musteriler['bugun'],
                    o == null
                        ? 'bugün'
                        : 'bugün · 7 günde ${o.musteriler['son7'] ?? 0}',
                    'musteriler',
                    0,
                    icon: LucideIcons.userPlus,
                    points:
                        o?.gunluk.map((d) => d.yeniMusteri).toList() ?? [])),
            SizedBox(
                width: width,
                child: _stat(
                    'Değerleme',
                    o?.degerlemeler['bugun'],
                    o == null
                        ? 'bugün'
                        : 'bugün · 7 günde ${o.degerlemeler['son7'] ?? 0}',
                    'raporlar',
                    1,
                    icon: LucideIcons.fileChartColumn,
                    points: o?.gunluk.map((d) => d.degerleme).toList() ?? [])),
            SizedBox(
                width: width,
                child: _stat(
                    'Kredi satışı',
                    o?.krediSatisi['son30_tl'],
                    o == null
                        ? 'son 30 gün'
                        : 'son 30 gün · ${o.krediSatisi['son30_adet'] ?? 0} satış\nPlay: ${o.krediSatisi['play_son30_adet'] ?? 0} satın alma',
                    'finans',
                    2,
                    icon: LucideIcons.wallet,
                    money: true)),
            SizedBox(
                width: width,
                child: _stat(
                    'Açık ekspertiz',
                    o == null
                        ? null
                        : (o.ekspertiz['waiting_assignment'] ?? 0) +
                            (o.ekspertiz['in_progress'] ?? 0) +
                            (o.ekspertiz['pending_approval'] ?? 0),
                    o == null
                        ? 'güncel talepler'
                        : '${o.ekspertiz['waiting_assignment'] ?? 0} atama bekler · ${o.ekspertiz['in_progress'] ?? 0} sürüyor',
                    'talepler',
                    3,
                    icon: LucideIcons.carFront)),
          ]);
        }),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          final main = Column(children: [
            _daily(),
            const SizedBox(height: 20),
            LayoutBuilder(
                builder: (context, c) => c.maxWidth < 650
                    ? Column(children: [
                        _donut(),
                        const SizedBox(height: 20),
                        _timeline()
                      ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Expanded(child: _donut()),
                            const SizedBox(width: 20),
                            Expanded(child: _timeline())
                          ]))
          ]);
          return c.maxWidth < 1050
              ? Column(
                  children: [_attention(), const SizedBox(height: 20), main])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: main),
                  const SizedBox(width: 20),
                  Expanded(child: _attention())
                ]);
        }),
      ],
    ]));
  }
}

class _AnimatedNumber extends StatelessWidget {
  const _AnimatedNumber(
      {required this.value, required this.money, required this.duration});
  final num? value;
  final bool money;
  final Duration duration;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value?.toDouble() ?? 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
          value == null
              ? '—'
              : '${NumberFormat.decimalPattern('tr_TR').format(v.round())}${money ? ' TL' : ''}',
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: context.renkler.metin)));
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);
  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}

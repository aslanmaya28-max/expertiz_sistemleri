import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../tema/renkler.dart';
import 'yerimebak_logo.dart';
import '../constants/roles.dart' as roles;

const panelBasliklari = [
  'Ana sayfa',
  'Kontrol merkezi',
  'Talepler',
  'Personel',
  'Müşteriler',
  'Raporlar',
  'Finans',
  'Fiyatlar',
  'Ayarlar',
  'Piyasa takibi'
];
const _ikonlar = [
  LucideIcons.layoutDashboard,
  LucideIcons.headset,
  LucideIcons.car,
  LucideIcons.users,
  LucideIcons.contact,
  LucideIcons.files,
  LucideIcons.wallet,
  LucideIcons.tag,
  LucideIcons.settings,
  LucideIcons.chartNoAxesCombined
];

class PanelSidebar extends StatelessWidget {
  const PanelSidebar(
      {super.key,
      required this.secili,
      required this.onSelect,
      this.dar = false,
      this.onDaralt,
      this.sayilar = const {}});
  final int secili;
  final ValueChanged<int> onSelect;
  final bool dar;
  final VoidCallback? onDaralt;
  final Map<int, int> sayilar;
  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    Widget group(String title, List<int> indices) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!dar)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 12, 8),
                child: Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: r.metinIkincil))),
          for (final i in indices)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Tooltip(
                    message: dar ? panelBasliklari[i] : '',
                    child: Material(
                        color: secili == i ? r.birincilYuzey : r.yuzey,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => onSelect(i),
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: dar ? 12 : 14, vertical: 13),
                                child: Row(children: [
                                  Icon(_ikonlar[i],
                                      size: 20,
                                      color: secili == i
                                          ? r.birincilMetin
                                          : r.ikonPasif),
                                  if (!dar) ...[
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(panelBasliklari[i],
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: secili == i
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: secili == i
                                                    ? r.birincilMetin
                                                    : r.metin))),
                                    if ((sayilar[i] ?? 0) > 0)
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: r.birincilYuzey,
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text('${sayilar[i]}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: r.birincilMetin)))
                                  ]
                                ]))))))
        ]);
    return Container(
        width: dar ? 72 : 248,
        decoration: BoxDecoration(
            color: r.yuzey,
            border: Border(right: BorderSide(color: r.kenarlik))),
        child: Column(children: [
          // Üst çubukla aynı yükseklik ve alt çizgi: iki bölüm tek hizada okunur
          Container(
              height: 64,
              padding: EdgeInsets.symmetric(horizontal: dar ? 0 : 22),
              alignment: dar ? Alignment.center : Alignment.centerLeft,
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: r.kenarlik))),
              child: dar
                  ? const YerimeBakLogo(height: 22, markOnly: true)
                  : const YerimeBakLogo(height: 26)),
          Expanded(
              child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: dar ? 10 : 12),
                  children: [
                group('GENEL', [0, 1]),
                group('OPERASYON', [2, 3, 5]),
                group('MÜŞTERİ / GELİR', [4, 6, 7]),
                group('SİSTEM', [9, 8])
              ])),
          const Divider(height: 1),
          IconButton(
              tooltip: dar ? 'Menüyü genişlet' : 'Menüyü daralt',
              onPressed: onDaralt,
              icon: Icon(dar
                  ? LucideIcons.panelLeftOpen
                  : LucideIcons.panelLeftClose)),
          const SizedBox(height: 12)
        ]));
  }
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.role});
  final roles.UserRole role;
  @override
  Widget build(BuildContext context) => Container(
      width: 220,
      color: context.renkler.yuzey,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const YerimeBakLogo(height: 30),
        const SizedBox(height: 24),
        for (final title in role == roles.UserRole.admin
            ? panelBasliklari
            : ['Ana sayfa', 'Raporlar', 'Profil'])
          ListTile(title: Text(title))
      ]));
}

/// Servis oluşturmayan, bağımsız sınanabilen duyarlı yönetim kabuğu.
class PanelYerlesim extends StatefulWidget {
  const PanelYerlesim(
      {super.key,
      required this.secili,
      required this.onSelect,
      required this.child,
      this.actions = const [],
      this.sayilar = const {}});
  final int secili;
  final ValueChanged<int> onSelect;
  final Widget child;
  final List<Widget> actions;
  final Map<int, int> sayilar;
  @override
  State<PanelYerlesim> createState() => _PanelYerlesimState();
}

class _PanelYerlesimState extends State<PanelYerlesim> {
  bool _dar = false;
  final _key = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final mobile = size.maxWidth < 760;
        Widget menu(bool drawer) => PanelSidebar(
            secili: widget.secili,
            dar: !drawer && (_dar || size.maxWidth < 1100),
            sayilar: widget.sayilar,
            onDaralt: () => setState(() => _dar = !_dar),
            onSelect: (i) {
              if (drawer) Navigator.pop(context);
              widget.onSelect(i);
            });
        final content = Column(children: [
          Container(
              height: 64,
              decoration: BoxDecoration(
                  color: context.renkler.yuzey,
                  border: Border(
                      bottom: BorderSide(color: context.renkler.kenarlik))),
              padding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 32),
              child: Row(children: [
                if (mobile)
                  IconButton(
                      tooltip: 'Menüyü aç',
                      onPressed: () => _key.currentState?.openDrawer(),
                      icon: const Icon(LucideIcons.menu)),
                // Sayfanın kendi başlığı içerikte; üst çubuk yalnız konum gösterir (başlık iki kez yazılmaz)
                Expanded(
                    child: Row(children: [
                  Text('Yönetim',
                      style: TextStyle(
                          fontSize: 14, color: context.renkler.metinIkincil)),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(LucideIcons.chevronRight,
                          size: 14, color: context.renkler.metinIkincil)),
                  Flexible(
                      child: Text(panelBasliklari[widget.secili],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600))),
                ])),
                ...widget.actions
              ])),
          Expanded(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 16 : 32,
                              vertical: mobile ? 16 : 24),
                          child: AnimatedSwitcher(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                  key: ValueKey(widget.secili),
                                  child: widget.child))))))
        ]);
        return Scaffold(
            key: _key,
            drawer: mobile ? Drawer(width: 248, child: menu(true)) : null,
            body: SafeArea(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (!mobile) menu(false),
                  Expanded(child: content)
                ])));
      });
}

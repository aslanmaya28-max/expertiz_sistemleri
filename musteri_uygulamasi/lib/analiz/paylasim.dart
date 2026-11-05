import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/providers.dart';
import '../kredi/kredi_ekrani.dart';
import '../oturum/session_controller.dart';
import 'analiz_durumu.dart';
import 'ilan_metni.dart';

/// Android "Paylaş → YerimeBak" kanalı (MainActivity.kt).
class PaylasimKanali {
  static const _kanal = MethodChannel('yerimebak/paylasim');
  Future<String?> ilk() async {
    try {
      return await _kanal.invokeMethod<String>('ilkPaylasim');
    } on MissingPluginException {
      return null; // Testler ve Android dışı ortam.
    } on PlatformException {
      return null;
    }
  }

  void dinle(void Function(String) geldi) => _kanal.setMethodCallHandler((c) async {
    if (c.method == 'yeniPaylasim' && c.arguments is String) geldi(c.arguments as String);
  });
}

final paylasimKanaliProvider = Provider((ref) => PaylasimKanali());

/// Uygulama boyunca açık kalan dinleyiciler: paylaşılan ilan linki ve Google Play satın alma akışı.
/// [yonlendir] uygulamada `routerProvider`'dan gelir; böylece bu dosya yönlendirme tanımına bağımlı olmaz.
class UygulamaDinleyicileri extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouter Function(WidgetRef ref) yonlendirici;
  const UygulamaDinleyicileri({super.key, required this.child, required this.yonlendirici});
  @override
  ConsumerState<UygulamaDinleyicileri> createState() => _UygulamaDinleyicileriState();
}

class _UygulamaDinleyicileriState extends ConsumerState<UygulamaDinleyicileri> {
  @override
  void initState() {
    super.initState();
    final kanal = ref.read(paylasimKanaliProvider);
    kanal.dinle(_geldi);
    unawaited(kanal.ilk().then((m) {
      if (m != null) _geldi(m);
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) => _oturumDegisti());
  }

  void _geldi(String metin) {
    final link = paylasimdanLink(metin);
    if (link == null || !mounted) return;
    ref.read(bekleyenLinkProvider.notifier).state = link.toString();
    _bekleyeniAc();
  }

  void _bekleyeniAc() {
    final link = ref.read(bekleyenLinkProvider);
    if (link == null || ref.read(sessionProvider).phase != SessionPhase.signedIn) return;
    ref.read(bekleyenLinkProvider.notifier).state = null;
    widget.yonlendirici(ref).go('/analiz/oku?link=${Uri.encodeQueryComponent(link)}');
  }

  void _oturumDegisti() {
    if (!mounted) return;
    if (ref.read(sessionProvider).phase == SessionPhase.signedIn) {
      ref.read(satinAlmaProvider).baslat();
      _bekleyeniAc();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider.select((s) => s.phase), (_, _) => _oturumDegisti());
    return widget.child;
  }
}

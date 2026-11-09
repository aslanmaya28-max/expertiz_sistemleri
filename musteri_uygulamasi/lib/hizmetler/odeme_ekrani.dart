import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../api/models.dart';
import '../api/providers.dart';
import '../bilesenler/ana_buton.dart';
import '../bilesenler/ortak.dart';
import '../tema/olculer.dart';
import 'hizmet_api.dart';
import 'hizmet_tanitim.dart';

class HizmetOdemeEkrani extends ConsumerStatefulWidget {
  final String id;
  final Json? checkout;
  const HizmetOdemeEkrani(this.id, {super.key, this.checkout});
  @override
  ConsumerState<HizmetOdemeEkrani> createState() => _OdemeState();
}

class _OdemeState extends ConsumerState<HizmetOdemeEkrani> {
  WebViewController? web;
  Timer? timer;
  bool sorgulaniyor = false, tamam = false, baslatildi = false;
  Json? durum;
  Object? hata;
  @override
  void initState() {
    super.initState();
    ref.listenManual(ekspertizAcikProvider, (_, acik) {
      if (acik) _baslat();
    }, fireImmediately: true);
  }

  void _baslat() {
    if (baslatildi || !mounted) return;
    baslatildi = true;
    final checkout = widget.checkout;
    if (checkout?['order_id'] == widget.id &&
        checkout?['kind'] == 'expertiz' &&
        checkout?['provider'] == 'paytr' &&
        guvenliPaytr(text(checkout?['iframe_url']))) {
      web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              if (odemeDonusu(request.url) != null) {
                unawaited(_sorgula());
                return NavigationDecision.prevent;
              }
              final uri = Uri.tryParse(request.url);
              return uri?.scheme == 'https' && uri!.userInfo.isEmpty
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
            onWebResourceError: (e) {
              if (e.isForMainFrame == true && mounted) {
                setState(
                  () => hata =
                      'Ödeme sayfası açılamadı. Bağlantınızı kontrol edin.',
                );
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(text(checkout?['iframe_url'])));
    }
    unawaited(_sorgula());
    timer = Timer.periodic(const Duration(seconds: 3), (_) => _sorgula());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _sorgula() async {
    if (sorgulaniyor || tamam || !mounted) return;
    sorgulaniyor = true;
    try {
      final next = await ref.read(hizmetRepositoryProvider).siparis(widget.id);
      if (!mounted) return;
      if (text(next['order_id']) != widget.id || next['kind'] != 'expertiz') {
        throw StateError('Ödeme yanıtı bu taleple eşleşmiyor.');
      }
      setState(() {
        durum = next;
        hata = null;
      });
      if (['paid', 'failed'].contains(next['status'])) {
        timer?.cancel();
        tamam = true;
        ref.invalidate(hizmetTaleplerProvider);
      }
    } catch (e) {
      if (mounted) setState(() => hata = e);
    } finally {
      sorgulaniyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(ekspertizAcikProvider)) {
      return const YerindeIncelemeEkrani();
    }
    final status = text(durum?['status']), checkout = widget.checkout;
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenli hizmet ödemesi')),
      body: Column(
        children: [
          Expanded(
            child: status == 'paid' || status == 'failed'
                ? SingleChildScrollView(
                    child: PageBody(
                      child: Panel(
                        status == 'paid'
                            ? 'Ödemeniz alındı'
                            : 'Ödeme tamamlanamadı',
                        [
                          Text(
                            status == 'paid'
                                ? 'Talebiniz kaydedildi. Randevu ve rapor durumunu Taleplerim bölümünden izleyebilirsiniz.'
                                : text(durum?['failed_reason']).isEmpty
                                ? 'Ödeme onayı alınamadı. Tekrar işlem yapmadan önce talep durumunu kontrol edin.'
                                : text(durum?['failed_reason']),
                          ),
                          const SizedBox(height: Olcu.s16),
                          AnaButon(
                            'Talep durumunu gör',
                            () async => context.go('/talepler'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      if (checkout?['amount_tl'] is num)
                        PageBody(
                          child: ValueLine(
                            'Ödenecek toplam',
                            hizmetPara(checkout!['amount_tl']),
                          ),
                        ),
                      if (hata != null)
                        PageBody(
                          child: FailureView(hata!, () {
                            setState(() => hata = null);
                            unawaited(_sorgula());
                          }),
                        ),
                      if (web != null)
                        Expanded(child: WebViewWidget(controller: web!))
                      else
                        Expanded(
                          child: SingleChildScrollView(
                            child: PageBody(
                              child: Panel(
                                checkout?['provider'] == 'simulation'
                                    ? 'Deneme ödeme modu'
                                    : 'Ödeme durumu bekleniyor',
                                [
                                  Text(
                                    checkout?['provider'] == 'simulation'
                                        ? 'Sunucu gerçek ödeme almıyor. Bu görünüm yalnız geliştirme denemesi içindir.'
                                        : 'Talebinizin ödeme durumunu sunucudan kontrol ediyoruz. Bu ekran ödeme alındığı anlamına gelmez.',
                                  ),
                                  if (checkout?['provider'] == 'simulation' &&
                                      !const bool.fromEnvironment(
                                        'dart.vm.product',
                                      )) ...[
                                    const SizedBox(height: Olcu.s12),
                                    AnaButon('Deneme ödemesini onayla', () async {
                                      await ref.read(apiProvider).post(
                                        '/payments/checkout/${Uri.encodeComponent(widget.id)}/simulate',
                                        {'success': true},
                                      );
                                      await _sorgula();
                                    }),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: TextButton(
              onPressed: () => context.go('/talepler'),
              child: const Text('Taleplerim ve ödeme durumu'),
            ),
          ),
        ],
      ),
    );
  }
}

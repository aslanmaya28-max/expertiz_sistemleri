import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/providers.dart';
import 'analiz_api.dart';
import 'arac_formu.dart';

final analizRepositoryProvider = Provider((ref) => AnalizRepository(ref.watch(apiProvider)));

final parcalarProvider = FutureProvider<List<Parca>>(
  (ref) => ref.watch(analizRepositoryProvider).parcalar(),
);

/// Ekranlar arası taşınan analiz taslağı. İstek numarası taslakla birlikte yaşar:
/// bekleme ekranından çıkıp dönen ya da kredi yükleyip dönen müşteri aynı numarayla devam eder.
class AnalizTaslagi {
  final AracFormu form;
  final String istekNo;
  AnalizTaslagi(this.form, [String? istekNo]) : istekNo = istekNo ?? yeniIstekNo();
}

final analizTaslagiProvider = StateProvider<AnalizTaslagi?>((ref) => null);

/// Paylaş menüsünden gelen ve oturum açılınca işlenecek link.
final bekleyenLinkProvider = StateProvider<String?>((ref) => null);

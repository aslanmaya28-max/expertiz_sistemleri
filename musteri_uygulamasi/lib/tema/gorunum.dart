import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GorunumDenetleyicisi extends StateNotifier<ThemeMode> {
  static const anahtar = 'yerimebak_theme';
  final Future<SharedPreferences> Function() yukle;
  late final Future<void> hazir;
  Future<void> _yazmalar = Future.value();
  int _degisiklik = 0;
  GorunumDenetleyicisi({this.yukle=SharedPreferences.getInstance}) : super(ThemeMode.system) { hazir=_oku(); }
  Future<void> _oku() async {
    final revision=_degisiklik;
    try {
      final prefs=await yukle();final value=prefs.getString(anahtar);
      if(mounted && revision==_degisiklik) {
        state=ThemeMode.values.firstWhere((m) => m.name==value,orElse:() => ThemeMode.system);
      }
    } catch (_) { /* Tercih henüz okunamıyorsa güvenli varsayılan sistem temasıdır. */ }
  }
  Future<void> sec(ThemeMode next) {
    final revision=++_degisiklik,previous=state;state=next;
    final write=_yazmalar.then((_) async {
      final prefs=await yukle();
      if(!await prefs.setString(anahtar,next.name)) throw StateError('Tercih kaydedilemedi');
    });
    _yazmalar=write.catchError((Object _) {});
    return write.catchError((Object error) {
      if(mounted && revision==_degisiklik) state=previous;
      throw StateError('Görünüm tercihi kaydedilemedi. Tekrar deneyin.');
    });
  }
}
final themeModeProvider=StateNotifierProvider<GorunumDenetleyicisi,ThemeMode>((ref) => GorunumDenetleyicisi());

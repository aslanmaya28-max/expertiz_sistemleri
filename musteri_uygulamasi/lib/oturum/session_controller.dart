import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../api/repositories.dart';

enum SessionPhase { restoring, signedOut, signedIn, failed }

class SessionController extends ChangeNotifier {
  final AccountRepository repository;
  final ApiClient api;
  SessionPhase phase = SessionPhase.restoring;
  AppUser? user;
  String? error;
  int _epoch = 0;
  bool _disposed = false;
  SessionController({required this.repository, required this.api});
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> restore() async {
    final epoch = ++_epoch;
    phase = SessionPhase.restoring;
    error = null;
    _notify();
    try {
      if (await api.store.read() == null) {
        if (epoch == _epoch) {
          phase = SessionPhase.signedOut;
          _notify();
        }
        return;
      }
      final current = await repository.currentUser();
      if (epoch != _epoch) return;
      if (!current.isCustomer) {
        await logout();
        throw const ApiFailure(
          'Bu uygulama müşteri hesapları içindir.',
          status: 403,
        );
      }
      user = current;
      phase = SessionPhase.signedIn;
      _notify();
    } catch (e) {
      if (epoch != _epoch) return;
      error = e.toString();
      phase = SessionPhase.failed;
      _notify();
    }
  }

  Future<void> authenticate(Future<String> Function() action) async {
    final epoch = ++_epoch;
    final token = await action();
    if (epoch != _epoch || _disposed) return;
    await api.saveSession(token);
    if (epoch != _epoch || _disposed) return;
    try {
      final current = await repository.currentUser();
      if (epoch != _epoch || _disposed) return;
      if (!current.isCustomer) {
        await logout();
        throw const ApiFailure(
          'Bu uygulama müşteri hesapları içindir.',
          status: 403,
        );
      }
      user = current;
      phase = SessionPhase.signedIn;
      error = null;
      _notify();
    } catch (_) {
      if (epoch == _epoch) {
        await api.clearSession();
        phase = SessionPhase.signedOut;
        _notify();
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) =>
      authenticate(() => repository.login(email, password));
  Future<void> register(Json fields) =>
      authenticate(() => repository.register(fields));
  Future<void> refreshProfile() async {
    final epoch = _epoch;
    final current = await repository.profile();
    if (epoch == _epoch && !_disposed && phase == SessionPhase.signedIn) {
      user = current;
      _notify();
    }
  }

  Future<void> updateProfile(String name, String phone) async {
    final epoch = _epoch;
    final current = await repository.updateProfile(name, phone);
    if (epoch == _epoch && !_disposed && phase == SessionPhase.signedIn) {
      user = current;
      _notify();
    }
  }

  Future<void> deleteAccount(String password) async {
    await repository.deleteAccount(password);
    await logout();
  }

  Future<void> logout() async {
    _epoch++;
    user = null;
    phase = SessionPhase.signedOut;
    error = null;
    _notify();
    await api.clearSession();
  }

  void expire() {
    _epoch++;
    user = null;
    phase = SessionPhase.signedOut;
    error = 'Oturumunuz sona erdi. Tekrar giriş yapın.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

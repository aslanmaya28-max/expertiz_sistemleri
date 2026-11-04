import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'providers.dart';
import 'repositories.dart';

class ReportListController extends ChangeNotifier {
  final ReportRepository repository;
  List<ReportSummary> reports = [];
  int total = 0;
  bool loading = true, loadingMore = false;
  Object? error;
  int _generation = 0;
  bool _disposed = false;
  ReportListController(this.repository);
  bool get hasMore => reports.length < total;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await repository.page();
      if (generation != _generation || _disposed) return;
      reports = page.reports;
      total = page.total;
    } catch (e) {
      if (generation == _generation) error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> next() async {
    if (loading || loadingMore || !hasMore) return;
    final generation = _generation;
    loadingMore = true;
    error = null;
    _notify();
    try {
      final page = await repository.page(offset: reports.length);
      if (generation != _generation || _disposed) return;
      final existing = reports.map((r) => r.id).toSet();
      reports = [
        ...reports,
        ...page.reports.where((r) => !existing.contains(r.id)),
      ];
      total = page.total;
    } catch (e) {
      if (generation == _generation) error = e;
    } finally {
      loadingMore = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

final reportListProvider =
    ChangeNotifierProvider.autoDispose<ReportListController>((ref) {
      final user = ref.watch(sessionProvider.select((s) => s.user?.id));
      final controller = ReportListController(
        ref.watch(reportRepositoryProvider),
      );
      if (user != null) unawaited(Future.microtask(controller.refresh));
      return controller;
    });

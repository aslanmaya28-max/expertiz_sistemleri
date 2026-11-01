import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/yerimebak_expertiz_api_service.dart';

bool isReportArchived(Map<String, dynamic> report) => report['archive'] is Map;

/// İndirme tek başına silme yetkisi vermez; ayrı kullanıcı onayı zorunludur.
class ReportArchiveAction extends StatefulWidget {
  const ReportArchiveAction({
    super.key,
    required this.report,
    required this.api,
    required this.onArchived,
    this.saveArchive,
  });

  final Map<String, dynamic> report;
  final YerimebakExpertizApiService api;
  final Future<void> Function(String reportId) onArchived;
  final Future<bool> Function(ReportArchiveDownload archive, String fileName)?
      saveArchive;

  @override
  State<ReportArchiveAction> createState() => _ReportArchiveActionState();
}

class _ReportArchiveActionState extends State<ReportArchiveAction> {
  bool _busy = false;
  String? _retrySha;

  String? get _pendingSha =>
      _retrySha ?? widget.report['archive_retry_sha256'] as String?;

  @override
  void didUpdateWidget(covariant ReportArchiveAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report['id'] != widget.report['id']) _retrySha = null;
  }

  Future<bool> _save(ReportArchiveDownload archive, String name) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Rapor arşivini kaydet',
      fileName: name,
      bytes: archive.bytes,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    // Web indirmeyi başlatınca null döndürür; kaydı kullanıcı teyit eder.
    return kIsWeb || path != null;
  }

  Future<void> _archive() async {
    final id = widget.report['id'].toString();
    final api = widget.api;
    final onArchived = widget.onArchived;
    setState(() => _busy = true);
    try {
      var sha256 = _pendingSha;
      if (sha256 == null) {
        final archive = await api.downloadReportArchive(id);
        if (!mounted) return;
        final saved = await (widget.saveArchive ?? _save)(
            archive, 'yerimebak_rapor_$id.zip');
        if (!mounted || !saved) return;
        sha256 = archive.sha256;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Arşiv kaydını onayla'),
          content: const Text(
              'Dosya bilgisayarınıza kaydedildi mi? Onaylarsanız fotoğraf ve PDF’ler buluttan kalıcı olarak silinir.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('İndirdim, buluttan sil'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      _retrySha = sha256;
      await api.confirmReportArchive(id, sha256);
      _retrySha = null;
      await onArchived(id);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Rapor arşivlendi')));
      }
    } catch (e) {
      if (e is ApiException && e.statusCode == 409) _retrySha = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Arşivleme tamamlanamadı: ${e is ApiException ? e.message : e}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isReportArchived(widget.report)) {
      return const Chip(
          avatar: Icon(Icons.archive_outlined, size: 18),
          label: Text('Arşivlendi'));
    }
    if (widget.report['status'] != 'published') return const SizedBox.shrink();
    final retention = widget.report['media_retention'];
    final eligible = retention is Map && retention['archive_eligible'] == true;
    final remaining = retention is Map ? retention['remaining_days'] : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!eligible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(remaining is num
                ? 'Arşivlemeye $remaining gün kaldı.'
                : 'Arşivleme için saklama süresinin dolması bekleniyor.'),
          ),
        if (_pendingSha != null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'İndirilen arşiv kaydı korunuyor. Silme onayını yeniden deneyebilirsiniz.'),
          ),
        OutlinedButton.icon(
          onPressed: eligible && !_busy ? _archive : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.archive_outlined),
          label: Text(_busy
              ? 'Arşiv hazırlanıyor...'
              : _pendingSha != null
                  ? 'Arşivlemeyi tamamla'
                  : 'Arşivle'),
        ),
      ],
    );
  }
}

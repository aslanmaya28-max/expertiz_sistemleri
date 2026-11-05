import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../api/api_client.dart';

String? guvenliMedyaYolu(String raw, Uri base) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      raw.startsWith('//') ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return null;
  }
  if (uri.hasScheme &&
      (uri.scheme != base.scheme ||
          uri.host != base.host ||
          uri.port != base.port)) {
    return null;
  }
  var path = uri.path;
  final prefix = base.path.replaceFirst(RegExp(r'/$'), '');
  if (path.startsWith('$prefix/')) path = path.substring(prefix.length);
  final parts = Uri.parse(path).pathSegments;
  if (parts.length != 3 ||
      parts[0] != 'expertiz' ||
      parts[1] != 'media' ||
      parts[2].isEmpty ||
      parts[2] == '.' ||
      parts[2] == '..' ||
      parts[2].contains('/') ||
      uri.queryParameters.keys.any((key) => !{'sig', 'exp'}.contains(key))) {
    return null;
  }
  return '$path${uri.hasQuery ? '?${uri.query}' : ''}';
}

class HizmetDosyalari {
  final Future<Directory> Function() temporaryDirectory;
  final Future<OpenResult> Function(String path, String mime) openDocument;
  HizmetDosyalari({
    this.temporaryDirectory = getTemporaryDirectory,
    this.openDocument = _open,
  });
  static Future<OpenResult> _open(String path, String mime) =>
      OpenFilex.open(path, type: mime);
  Future<void> ac(ApiClient api, String path) async {
    final package = RegExp(r'^/expertiz/reports/[^/]+/package$').hasMatch(path);
    final media = guvenliMedyaYolu(path, api.baseUri);
    if (!package && media == null) {
      throw const ApiFailure('Bu rapor dosyasının adresi geçersiz.');
    }
    final epoch = api.sessionEpoch,
        response = await api.request('GET', package ? path : media!);
    final bytes = response.bodyBytes,
        mime = (response.headers['content-type'] ?? '')
            .split(';')
            .first
            .trim()
            .toLowerCase();
    final valid = switch (mime) {
      'application/pdf' =>
        bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-',
      'application/zip' =>
        bytes.length >= 4 &&
            bytes[0] == 80 &&
            bytes[1] == 75 &&
            ((bytes[2] == 3 && bytes[3] == 4) ||
                (bytes[2] == 5 && bytes[3] == 6)),
      'image/jpeg' =>
        bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255,
      'image/png' =>
        bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10',
      'image/webp' =>
        bytes.length >= 12 &&
            String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
      'image/heic' || 'image/heif' =>
        bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
            {
              'heic',
              'heix',
              'hevc',
              'hevx',
              'heim',
              'heis',
              'mif1',
              'msf1',
            }.contains(String.fromCharCodes(bytes.sublist(8, 12))),
      _ => false,
    };
    if (!valid || (package && mime != 'application/zip')) {
      throw const ApiFailure('Sunucu geçerli bir rapor dosyası döndürmedi.');
    }
    final temp = await temporaryDirectory();
    void check() {
      if (epoch != api.sessionEpoch) {
        throw const ApiFailure(
          'Oturum değişti. Raporu yeniden açın.',
          status: 401,
        );
      }
    }

    check();
    final dir = await temp.createTemp('yerimebak-ekspertiz-');
    final extension = const {
      'application/pdf': 'pdf',
      'application/zip': 'zip',
      'image/jpeg': 'jpg',
      'image/png': 'png',
      'image/webp': 'webp',
      'image/heic': 'heic',
      'image/heif': 'heif',
    }[mime]!;
    final file = File('${dir.path}/ekspertiz.$extension');
    await file.writeAsBytes(bytes, flush: true);
    if (epoch != api.sessionEpoch) {
      await file.delete();
      await dir.delete();
      check();
    }
    final result = await openDocument(file.path, mime);
    if (result.type != ResultType.done) {
      throw const ApiFailure(
        'Dosya indirildi. Açmak için telefona uygun bir PDF, görsel veya ZIP görüntüleyici yükleyin.',
      );
    }
  }
}

final hizmetDosyalariProvider = Provider((ref) => HizmetDosyalari());

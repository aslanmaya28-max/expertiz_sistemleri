import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';
import 'models.dart';

class AccountRepository {
  final ApiClient api;
  AccountRepository(this.api);
  Future<AppUser> currentUser() async {
    await api.get('/auth/me');
    return profile(); // /me eski sunucuda doğrulama durumunu içermez; profile yetkili kaynaktır.
  }

  Future<AppUser> profile() async =>
      AppUser.fromJson(object((await api.get('/auth/profile'))['profile']));
  Future<String> login(String email, String password) async => _token(
    await api.post('/auth/login', {
      'email': email.trim(),
      'password': password,
    }, authenticated: false),
  );
  Future<String> register(Json fields) async =>
      _token(await api.post('/auth/register', fields, authenticated: false));
  String _token(Json data) {
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure('Sunucu oturum belirteci döndürmedi.');
    }
    return token;
  }

  Future<void> forgotPassword(String email) async {
    await api.post('/auth/forgot-password', {
      'email': email.trim(),
    }, authenticated: false);
  }

  Future<AppUser> updateProfile(String name, String phone) async =>
      AppUser.fromJson(
        object(
          (await api.put('/auth/profile', {
            'full_name': name.trim(),
            'phone': phone.trim(),
          }))['profile'],
        ),
      );
  Future<void> changePassword(String oldPassword, String newPassword) async {
    await api.post('/auth/change-password', {
      'current_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<String> resendVerification() async {
    final data = await api.post('/auth/resend-verification', {});
    return data['already_verified'] == true
        ? 'E-posta adresiniz zaten doğrulanmış.'
        : 'Doğrulama e-postası tekrar gönderildi.';
  }

  Future<void> deleteAccount(String password) async {
    await api.post('/auth/delete-account', {'password': password});
  }
}

class ReportRepository {
  final ApiClient api;
  ReportRepository(this.api);
  Future<int> balance() async =>
      integer((await api.get('/credits/balance'))['credits']);
  Future<ReportPage> page({int offset = 0, int limit = 20}) async =>
      ReportPage.fromJson(
        await api.get('/valuation/reports?limit=$limit&offset=$offset'),
      );
  Future<ReportSnapshot> detail(String id) async => ReportSnapshot.fromJson(
    await api.get('/valuation/reports/${Uri.encodeComponent(id)}'),
  );
  Future<List<CreditHistoryEntry>> history() async => objects(
    (await api.get('/credits/history'))['history'],
  ).map(CreditHistoryEntry.fromJson).toList();
}

class ConfigRepository {
  final ApiClient api;
  ConfigRepository(this.api);
  Future<AppConfig> load() async {
    try {
      return AppConfig.fromJson(
        await api.get('/app/config', authenticated: false),
      );
    } on ApiFailure catch (e) {
      if (e.status == 404) return AppConfig.fromJson({}, available: false);
      rethrow;
    }
  }
}

abstract interface class PlatformServices {
  Future<String> version();
  Future<void> openLink(String url);
  Future<void> openPdf(ApiClient api, String reportId);
}

class AndroidServices implements PlatformServices {
  final Future<Directory> Function() temporaryDirectory;
  final Future<OpenResult> Function(String path) openDocument;
  AndroidServices({
    this.temporaryDirectory = getTemporaryDirectory,
    this.openDocument = _openDocument,
  });
  static Future<OpenResult> _openDocument(String path) =>
      OpenFilex.open(path, type: 'application/pdf');
  @override
  Future<String> version() async => (await PackageInfo.fromPlatform()).version;
  @override
  Future<void> openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http', 'mailto'].contains(uri.scheme) ||
        (uri.scheme != 'mailto' &&
            (!uri.hasAuthority || uri.userInfo.isNotEmpty))) {
      throw const ApiFailure('Bu bağlantı güvenli bir web adresi değil.');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const ApiFailure('Bağlantı açılamadı.');
    }
  }

  @override
  Future<void> openPdf(ApiClient api, String reportId) async {
    final epoch = api.sessionEpoch;
    final bytes = await api.getPdf(
      '/valuation/reports/${Uri.encodeComponent(reportId)}/pdf',
    );
    final temporary = await temporaryDirectory();
    if (epoch != api.sessionEpoch) {
      throw const ApiFailure(
        'Oturum değişti. Raporu yeniden açın.',
        status: 401,
      );
    }
    final parent = Directory('${temporary.path}/yerimebak-raporlar');
    await parent.create(recursive: true);
    // PDF uygulama önbelleğinde, dosya adı sunucudan veya kullanıcı girdisinden gelmez.
    final dir = await parent.createTemp('rapor-');
    final file = File('${dir.path}/degerleme.pdf');
    await file.writeAsBytes(bytes, flush: true);
    if (epoch != api.sessionEpoch) {
      await dir.delete(recursive: true);
      throw const ApiFailure(
        'Oturum değişti. Raporu yeniden açın.',
        status: 401,
      );
    }
    final result = await openDocument(file.path);
    if (result.type != ResultType.done) {
      throw const ApiFailure(
        'PDF açılamadı. Telefona bir PDF görüntüleyici yükleyin.',
      );
    }
  }
}

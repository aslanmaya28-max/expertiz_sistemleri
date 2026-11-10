import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yerimebak_sistemleri/models/user_model.dart';
import 'package:yerimebak_sistemleri/core/permissions/permission_matrix.dart';
import 'package:yerimebak_sistemleri/providers/user_provider.dart';
import 'package:yerimebak_sistemleri/providers/theme_provider.dart';
import 'package:yerimebak_sistemleri/services/central_auth_client.dart';
import 'package:yerimebak_sistemleri/services/yerimebak_expertiz_api_service.dart';
import 'package:yerimebak_sistemleri/tema/tema.dart';

const auditSizes = [
  Size(360, 800),
  Size(768, 1024),
  Size(1280, 800),
  Size(1920, 1080)
];
const auditLongName =
    'Ayşe Şule Çok Uzun Adlı Denetim Kullanıcısı Yılmaz Karacaoğlu';
const auditLongFirm =
    'İstanbul Anadolu Yakası Kurumsal Ekspertiz ve Araç İnceleme Merkezi';
const auditLongVehicle =
    'Mercedes-Benz S 580 e Long AMG Premium Plus Executive 4MATIC';
const auditLongEmail =
    'cok.uzun.adresli.deneme.kullanicisi040@yerimebak-ornek.example.test';
final _auditDetails = <String>[];

http.Response auditJson(Object data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
YerimebakExpertizApiService auditApi(http.Client client) =>
    YerimebakExpertizApiService(
        baseUrl: 'http://local.test/api/v1',
        accessToken: 'layout-test-token',
        client: client);
http.Client auditClient(Object Function(http.Request) response) =>
    MockClient((r) async => auditJson(response(r)));

class LayoutUserProvider extends ChangeNotifier implements UserProvider {
  LayoutUserProvider({UserRole role = UserRole.admin})
      : currentUser = UserModel(
            id: '040',
            email: auditLongEmail,
            fullName: auditLongName,
            role: role,
            createdAt: DateTime(2026, 11, 1),
            phone: '05550000040',
            ilId: 34,
            city: 'İstanbul',
            district: 'Kadıköy',
            address:
                'Caferağa Mahallesi Çok Uzun Sokak No: 40 Kat: 4 Kadıköy İstanbul');
  @override
  final UserModel currentUser;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isLoading => false;
  @override
  bool get isAdmin => currentUser.isAdmin;
  @override
  bool get isFieldStaff => currentUser.isFieldStaff;
  @override
  bool get isCustomer => currentUser.isCustomer;
  @override
  bool get isPersonel => isFieldStaff;
  @override
  bool get isMusteri => isCustomer;
  @override
  String get userId => currentUser.id;
  @override
  String get email => currentUser.email;
  @override
  String get fullName => currentUser.fullName;
  @override
  UserRole get role => currentUser.role;
  @override
  int? get ilId => currentUser.ilId;
  @override
  int? get bolgeId => currentUser.bolgeId;
  @override
  List<String> get permissions => currentUser.permissions;
  @override
  bool can(String permission) =>
      PermissionMatrix.hasPermission(permissions, permission);
  @override
  String? get error => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sabit zaman ilerletir; sonsuz hareketi beklemez, hiçbir Flutter hatasını gizlemez.
Future<void> auditPump(WidgetTester tester, {int frames = 24}) async {
  final errors = <Object>[];
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final error = tester.takeException();
    if (error != null) errors.add(error);
  }
  expect(errors, isEmpty,
      reason:
          [...errors.map((e) => e.toString()), ..._auditDetails].join('\n'));
}

Future<void> auditLayout(WidgetTester tester,
    {required Widget screen,
    required Size size,
    required bool dark,
    required http.Client client,
    UserRole role = UserRole.admin,
    double textScale = 1,
    Future<void> Function()? exercise}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues(
      {'theme_mode': dark ? 'dark' : 'light'});
  final user = LayoutUserProvider(role: role);
  final theme = ThemeProvider();
  CentralAuthTokenStore.accessToken = 'layout-test-token';
  final previousHandler = FlutterError.onError;
  _auditDetails.clear();
  FlutterError.onError = (details) {
    _auditDetails.add(details.toString());
    previousHandler?.call(details);
  };
  try {
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(value: user),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ],
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? YbTema.koyu : YbTema.acik,
              locale: const Locale('tr', 'TR'),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate
              ],
              supportedLocales: const [Locale('tr', 'TR')],
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.linear(textScale)),
                  child: child!),
              home: Scaffold(body: screen))));
      final initial = tester.takeException();
      expect(initial, isNull, reason: _auditDetails.join('\n'));
      await auditPump(tester);
      if (exercise != null) {
        await exercise();
        await auditPump(tester);
      }
    }, () => client);
  } finally {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    FlutterError.onError = previousHandler;
    user.dispose();
    theme.dispose();
  }
}

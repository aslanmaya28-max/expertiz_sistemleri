import 'dart:convert';
import 'package:pub_semver/pub_semver.dart';

typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) =>
    value is List ? value.whereType<Map>().map(object).toList() : [];
List<String> strings(dynamic value) => value is List
    ? value.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
    : [];
String text(dynamic value) => value?.toString() ?? '';
int integer(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(text(value)) ?? fallback;

class AppUser {
  final String id, email, name, phone, role;
  final int credits;
  final bool emailVerified;
  AppUser.fromJson(Json data)
    : id = text(data['id']),
      email = text(data['email']),
      name = text(data['full_name']),
      phone = text(data['phone']),
      role = text(data['role']),
      credits = integer(data['credits']),
      emailVerified = data['email_verified'] != false;
  bool get isCustomer => ['user', 'customer', 'musteri'].contains(role);
}

class AppConfig {
  final bool available, expertizEnabled;
  final String minimumVersion, latestVersion, storeUrl, supportEmail;
  final int analysisCost;
  AppConfig.fromJson(Json data, {this.available = true})
    : expertizEnabled = data['expertiz_enabled'] == true,
      minimumVersion = text(data['min_supported_version']).isEmpty
          ? '1.0.0'
          : text(data['min_supported_version']),
      latestVersion = text(data['latest_version']),
      storeUrl = text(data['store_url']),
      supportEmail = text(data['support_email']).isEmpty
          ? 'destek@yerimebak.com.tr'
          : text(data['support_email']),
      analysisCost = integer(data['analysis_cost'], 1);
  bool requiresUpdate(String current) {
    try {
      return Version.parse(current) < Version.parse(minimumVersion);
    } on FormatException {
      throw const FormatException('Sunucu sürüm ayarı geçersiz.');
    }
  }
}

class ReportSummary {
  final String id, reportNumber, decision;
  final DateTime? createdAt;
  final Json vehicle;
  final bool summaryOnly;
  ReportSummary.fromJson(Json data)
    : id = text(data['id']),
      reportNumber = text(data['report_no']),
      decision = text(data['karar']),
      createdAt = DateTime.tryParse(text(data['created_at'])),
      vehicle = object(data['arac']),
      summaryOnly = data['ozet_kayit'] == true;
  String get title => [
    vehicle['marka'],
    vehicle['model'],
    vehicle['yil'],
  ].where((e) => e != null && text(e).isNotEmpty).join(' ');
}

class ReportPage {
  final List<ReportSummary> reports;
  final int total, offset;
  ReportPage.fromJson(Json data)
    : reports = objects(data['reports']).map(ReportSummary.fromJson).toList(),
      total = integer(data['total']),
      offset = integer(data['offset']);
}

class ReportSnapshot {
  final Json raw;
  ReportSnapshot.fromJson(Json data) : raw = Map.unmodifiable(data);
  bool get summaryOnly => raw['ozet_kayit'] == true;
  Json get vehicle => object(raw['arac']);
  Json get market => object(raw['piyasa']);
  Json get valuation => object(raw['degerleme']);
  Json get summary => object(raw['ozet']);
  Json get plan => object(raw['pazarlikPlani']);
  Json get report => object(raw['rapor']);
}

class CreditHistoryEntry {
  final String description;
  final int? amount;
  final DateTime? createdAt;
  CreditHistoryEntry.fromJson(Json data)
    : description = text(data['description']).isNotEmpty
          ? text(data['description'])
          : 'Araç analizi',
      amount = data['credits_used'] is num
          ? integer(data['credits_used'])
          : _analysisCost(data),
      createdAt = DateTime.tryParse(text(data['created_at']));
  static int? _analysisCost(Json data) {
    dynamic value = data['valuation_json'];
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    final deduction = object(value)['credits_deducted'];
    return deduction is num ? deduction.toInt() : null;
  }
}

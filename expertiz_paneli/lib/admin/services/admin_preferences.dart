import 'package:shared_preferences/shared_preferences.dart';

/// Admin paneline özel, cihazda saklanan tercihler.
class AdminPreferences {
  AdminPreferences._();

  static const _newReportAlertsKey = 'admin_new_report_alerts';

  /// Yeni rapor onay beklerken uyarı (bildirim + titreşim) gösterilsin mi.
  static Future<bool> newReportAlertsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_newReportAlertsKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setNewReportAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newReportAlertsKey, enabled);
  }
}

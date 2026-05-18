import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesManager {
  static Future<void> setList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  static Future<List<String>?> getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }
  
  static Future<List<Object?>?> getListDynamic(String key) async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences string listesi döndürür, bunu dynamic listeye çevirmemiz gerekebilir
    // Ancak setList string listesi kaydettiği için getStringList yeterlidir.
    // Uyumluluk için Object? listesi döndüren bir yapı kuruyoruz.
    final list = prefs.getStringList(key);
    return list; 
  }

  static Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}

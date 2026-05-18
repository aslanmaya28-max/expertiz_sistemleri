import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesManager {
  static SharedPreferences? _preferences;

  // SharedPreferences instance'ını başlat
  static Future<void> init() async {
    try {
        _preferences = await SharedPreferences.getInstance();
    } catch (e) {
      throw Exception('SharedPreferences başlatılamadı: $e');
    }
  }

  // Instance'ı al (lazy loading)
  static Future<SharedPreferences> get instance async {
    if (_preferences != null) return _preferences!;
    await init();
    return _preferences!;
  }

  // STRING değer kaydet
  static Future<bool> setString(String key, String value) async {
    try {
      final prefs = await instance;
      return await prefs.setString(key, value);
    } catch (e) {
      debugPrint('String kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // STRING değer oku
  static Future<String?> getString(String key) async {
    try {
      final prefs = await instance;
      return prefs.getString(key);
    } catch (e) {
      debugPrint('String okuma hatası [$key]: $e');
      return null;
    }
  }

  // INT değer kaydet
  static Future<bool> setInt(String key, int value) async {
    try {
      final prefs = await instance;
      return await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Int kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // INT değer oku
  static Future<int?> getInt(String key) async {
    try {
      final prefs = await instance;
      return prefs.getInt(key);
    } catch (e) {
      debugPrint('Int okuma hatası [$key]: $e');
      return null;
    }
  }

  // DOUBLE değer kaydet
  static Future<bool> setDouble(String key, double value) async {
    try {
      final prefs = await instance;
      return await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('Double kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // DOUBLE değer oku
  static Future<double?> getDouble(String key) async {
    try {
      final prefs = await instance;
      return prefs.getDouble(key);
    } catch (e) {
      debugPrint('Double okuma hatası [$key]: $e');
      return null;
    }
  }

  // BOOL değer kaydet
  static Future<bool> setBool(String key, bool value) async {
    try {
      final prefs = await instance;
      return await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Bool kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // BOOL değer oku
  static Future<bool?> getBool(String key) async {
    try {
      final prefs = await instance;
      return prefs.getBool(key);
    } catch (e) {
      debugPrint('Bool okuma hatası [$key]: $e');
      return null;
    }
  }

  // STRING LİSTESİ kaydet
  static Future<bool> setList(String key, List<String> value) async {
    try {
      final prefs = await instance;
      return await prefs.setStringList(key, value);
    } catch (e) {
      debugPrint('List kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // STRING LİSTESİ oku
  static Future<List<String>?> getList(String key) async {
    try {
      final prefs = await instance;
      return prefs.getStringList(key);
    } catch (e) {
      debugPrint('List okuma hatası [$key]: $e');
      return null;
    }
  }

  // DİNAMİK LİSTE kaydet (JSON olarak)
  static Future<bool> setListDynamic(String key, List<dynamic> value) async {
    try {
      final jsonList = value.map((item) => jsonEncode(item)).toList();
      return await setList(key, jsonList);
    } catch (e) {
      debugPrint('Dynamic list kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // DİNAMİK LİSTE oku (JSON'dan)
  static Future<List<dynamic>?> getListDynamic(String key) async {
    try {
      final jsonList = await getList(key);
      if (jsonList == null) return null;
      
      return jsonList.map((jsonString) {
        try {
          return jsonDecode(jsonString);
        } catch (e) {
          debugPrint('JSON decode hatası [$key]: $e');
          return null;
        }
      }).where((item) => item != null).toList();
    } catch (e) {
      debugPrint('Dynamic list okuma hatası [$key]: $e');
      return null;
    }
  }

  // JSON OBJECT kaydet
  static Future<bool> setObject(String key, Map<String, dynamic> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await setString(key, jsonString);
    } catch (e) {
      debugPrint('Object kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // JSON OBJECT oku
  static Future<Map<String, dynamic>?> getObject(String key) async {
    try {
      final jsonString = await getString(key);
      if (jsonString == null || jsonString.isEmpty) return null;
      
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        debugPrint('Object format hatası [$key]: Beklenen Map<String, dynamic>, alınan ${decoded.runtimeType}');
        return null;
      }
    } catch (e) {
      debugPrint('Object okuma hatası [$key]: $e');
      return null;
    }
  }

  // OBJECT LİSTESİ kaydet
  static Future<bool> setObjectList(String key, List<Map<String, dynamic>> value) async {
    try {
      final jsonList = value.map((obj) => jsonEncode(obj)).toList();
      return await setList(key, jsonList);
    } catch (e) {
      debugPrint('Object list kaydetme hatası [$key]: $e');
      return false;
    }
  }

  // OBJECT LİSTESİ oku
  static Future<List<Map<String, dynamic>>?> getObjectList(String key) async {
    try {
      final jsonList = await getList(key);
      if (jsonList == null) return null;
      
      return jsonList.map((jsonString) {
        try {
          final decoded = jsonDecode(jsonString);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          } else {
            debugPrint('Object list format hatası [$key]: Beklenen Map<String, dynamic>');
            return null;
          }
        } catch (e) {
          debugPrint('JSON decode hatası [$key]: $e');
          return null;
        }
      }).where((item) => item != null).cast<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Object list okuma hatası [$key]: $e');
      return null;
    }
  }

  // Belirli bir key'i sil
  static Future<bool> remove(String key) async {
    try {
      final prefs = await instance;
      return await prefs.remove(key);
    } catch (e) {
      debugPrint('Remove hatası [$key]: $e');
      return false;
    }
  }

  // Tüm verileri temizle
  static Future<bool> clear() async {
    try {
      final prefs = await instance;
      return await prefs.clear();
    } catch (e) {
      debugPrint('Clear hatası: $e');
      return false;
    }
  }

  // Belirli bir key'in varlığını kontrol et
  static Future<bool> containsKey(String key) async {
    try {
      final prefs = await instance;
      return prefs.containsKey(key);
    } catch (e) {
      debugPrint('ContainsKey hatası [$key]: $e');
      return false;
    }
  }

  // Tüm key'leri listele
  static Future<Set<String>> getAllKeys() async {
    try {
      final prefs = await instance;
      return prefs.getKeys();
    } catch (e) {
      debugPrint('GetAllKeys hatası: $e');
      return <String>{};
    }
  }

  // Belirli prefix ile başlayan key'leri sil
  static Future<bool> removeKeysWithPrefix(String prefix) async {
    try {
      final prefs = await instance;
      final keys = prefs.getKeys();
      final keysToRemove = keys.where((key) => key.startsWith(prefix)).toList();
      
      bool allSuccess = true;
      for (String key in keysToRemove) {
        final success = await prefs.remove(key);
        if (!success) allSuccess = false;
      }
      
      return allSuccess;
    } catch (e) {
      debugPrint('RemoveKeysWithPrefix hatası [$prefix]: $e');
      return false;
    }
  }

  // Veri boyutu hesapla (yaklaşık)
  static Future<Map<String, int>> getStorageInfo() async {
    try {
      final prefs = await instance;
      final keys = prefs.getKeys();
      Map<String, int> info = {};
      int totalSize = 0;
      
      for (String key in keys) {
        final value = prefs.get(key);
        int size = 0;
        
        if (value is String) {
          size = value.length;
        } else if (value is List<String>) {
          size = value.join('').length;
        } else {
          size = value.toString().length;
        }
        
        info[key] = size;
        totalSize += size;
      }
      
      info['_TOTAL_SIZE'] = totalSize;
      info['_KEY_COUNT'] = keys.length;
      
      return info;
    } catch (e) {
      debugPrint('GetStorageInfo hatası: $e');
      return {'_ERROR': 1};
    }
  }

  // Debug: Tüm verileri yazdır
  static Future<void> debugPrintAll() async {
    try {
      final prefs = await instance;
      final keys = prefs.getKeys();
      
      debugPrint('=== SharedPreferences Debug ===');
      debugPrint('Toplam Key Sayısı: ${keys.length}');
      
      for (String key in keys) {
        final value = prefs.get(key);
        debugPrint('[$key] = $value');
      }
      debugPrint('=== Debug Sonu ===');
    } catch (e) {
      debugPrint('DebugPrintAll hatası: $e');
    }
  }

  // Kullanıcı oturumu yönetimi
  static const String _currentUserKey = 'current_user';
  static const String _loginTimeKey = 'login_time';
  static const String _autoLoginKey = 'auto_login';

  // Kullanıcı oturumunu kaydet
  static Future<bool> saveUserSession({
    required Map<String, dynamic> userData,
    bool autoLogin = false,
  }) async {
    try {
      final success1 = await setObject(_currentUserKey, userData);
      final success2 = await setString(_loginTimeKey, DateTime.now().toIso8601String());
      final success3 = await setBool(_autoLoginKey, autoLogin);
      
      return success1 && success2 && success3;
    } catch (e) {
      debugPrint('Kullanıcı oturumu kaydetme hatası: $e');
      return false;
    }
  }

  // Kullanıcı oturumunu oku
  static Future<Map<String, dynamic>?> getUserSession() async {
    try {
      return await getObject(_currentUserKey);
    } catch (e) {
      debugPrint('Kullanıcı oturumu okuma hatası: $e');
      return null;
    }
  }

  // Oturum açma zamanını oku
  static Future<DateTime?> getLoginTime() async {
    try {
      final timeString = await getString(_loginTimeKey);
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      debugPrint('Login time okuma hatası: $e');
      return null;
    }
  }

  // Otomatik giriş kontrolü
  static Future<bool> isAutoLoginEnabled() async {
    try {
      return await getBool(_autoLoginKey) ?? false;
    } catch (e) {
      debugPrint('Auto login kontrol hatası: $e');
      return false;
    }
  }

  // Kullanıcı oturumunu temizle
  static Future<bool> clearUserSession() async {
    try {
      final success1 = await remove(_currentUserKey);
      final success2 = await remove(_loginTimeKey);
      final success3 = await remove(_autoLoginKey);
      
      return success1 && success2 && success3;
    } catch (e) {
      debugPrint('Kullanıcı oturumu temizleme hatası: $e');
      return false;
    }
  }

  // Uygulama ayarları
  static const String _settingsPrefix = 'app_settings_';
  
  // Ayar kaydet
  static Future<bool> saveSetting(String settingName, dynamic value) async {
    final key = '$_settingsPrefix$settingName';
    
    if (value is String) return await setString(key, value);
    if (value is int) return await setInt(key, value);
    if (value is double) return await setDouble(key, value);
    if (value is bool) return await setBool(key, value);
    if (value is List<String>) return await setList(key, value);
    if (value is Map<String, dynamic>) return await setObject(key, value);
    
    return false;
  }

  // Ayar oku
  static Future<T?> getSetting<T>(String settingName) async {
    final key = '$_settingsPrefix$settingName';
    
    if (T == String) return await getString(key) as T?;
    if (T == int) return await getInt(key) as T?;
    if (T == double) return await getDouble(key) as T?;
    if (T == bool) return await getBool(key) as T?;
    
    return null;
  }

  // Tüm ayarları temizle
  static Future<bool> clearAllSettings() async {
    return await removeKeysWithPrefix(_settingsPrefix);
  }

  // JSON encode yardımcı metod
  static String encodeJson(Map<String, dynamic> data) {
    return jsonEncode(data);
  }

  // JSON decode yardımcı metod
  static Map<String, dynamic>? decodeJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('JSON decode hatası: $e');
      return null;
    }
  }
}

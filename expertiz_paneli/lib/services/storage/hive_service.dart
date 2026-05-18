import 'package:flutter/foundation.dart' as foundation;
import 'package:hive_flutter/hive_flutter.dart';

/// Hive Service
/// Yerel veri depolama için Hive kullanımı
/// Flutter Web ile uyumlu, hızlı ve güvenli veri saklama sağlar
class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  // Hive box referansı
  static Box? _box;

  // Debug mode flag - sadece development modunda çalışır
  static bool get kDebugMode => foundation.kDebugMode;

  /// Hive başlatır ve box'ı açar
  /// Flutter Web ile uyumlu çalışır
  static Future<void> init() async {
    try {
      foundation.debugPrint('🔧 Hive başlatılıyor...');
      
      // Hive'i başlat
      await Hive.initFlutter();
      
      // Expertiz sistemi için box'ı aç
      _box = await Hive.openBox('expertize_system');
      
      foundation.debugPrint('✅ Hive başarıyla başlatıldı');
      foundation.debugPrint('📦 Box açıldı: expertize_system');
    } catch (e) {
      foundation.debugPrint('❌ Hive başlatma hatası: $e');
      rethrow;
    }
  }

  /// Veriyi box'a kaydeder
  /// Herhangi bir veri tipini destekler (String, int, double, bool, Map, List)
  static Future<bool> saveData(String key, Object value) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Veriyi kaydet
      await _box!.put(key, value);
      
      foundation.debugPrint('💾 Veri kaydedildi: [$key] = $value');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Veri kaydetme hatası [$key]: $e');
      return false;
    }
  }

  /// Veriyi box'tan getirir
  /// Bulunamazsa null döner
  static Future<Object?> getData(String key) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Veriyi getir
      final value = _box!.get(key);
      
      if (value != null) {
        foundation.debugPrint('📖 Veri getirildi: [$key] = $value');
      } else {
        foundation.debugPrint('⚠️ Veri bulunamadı: [$key]');
      }
      
      return value;
    } catch (e) {
      foundation.debugPrint('❌ Veri getirme hatası [$key]: $e');
      return null;
    }
  }

  /// Belirli bir key'i siler
  static Future<bool> deleteData(String key) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Veriyi sil
      await _box!.delete(key);
      
      foundation.debugPrint('🗑️ Veri silindi: [$key]');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Veri silme hatası [$key]: $e');
      return false;
    }
  }

  /// Box içindeki tüm verileri temizler
  /// Test için kullanışlıdır
  static Future<bool> clearAll() async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Tüm verileri temizle
      await _box!.clear();
      
      foundation.debugPrint('🗑️ Tüm veriler temizlendi');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Tüm verileri temizleme hatası: $e');
      return false;
    }
  }

  /// Belirli bir key'in varlığını kontrol eder
  static Future<bool> containsKey(String key) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Key'in varlığını kontrol et
      final exists = _box!.containsKey(key);
      
      foundation.debugPrint('🔍 Key kontrolü: [$key] = $exists');
      return exists;
    } catch (e) {
      foundation.debugPrint('❌ Key kontrolü hatası [$key]: $e');
      return false;
    }
  }

  /// Tüm key'leri listeler
  static Future<Iterable> getAllKeys() async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Tüm key'leri getir
      final keys = _box!.keys;
      
      foundation.debugPrint('📋 Tüm keyler: ${keys.length} adet');
      return keys;
    } catch (e) {
      foundation.debugPrint('❌ Tüm keyleri getirme hatası: $e');
      return [];
    }
  }

  /// Belirli prefix ile başlayan key'leri siler
  static Future<bool> deleteKeysWithPrefix(String prefix) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Prefix ile başlayan key'leri bul
      final keys = _box!.keys.where((key) => key.toString().startsWith(prefix)).toList();
      
      // Her birini sil
      for (var key in keys) {
        await _box!.delete(key);
      }
      
      foundation.debugPrint('🗑️ ${keys.length} key silindi (prefix: $prefix)');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Prefix ile key silme hatası [$prefix]: $e');
      return false;
    }
  }

  /// Box içindeki toplam veri sayısını döndürür
  static Future<int> getLength() async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      final length = _box!.length;
      foundation.debugPrint('📊 Toplam veri sayısı: $length');
      return length;
    } catch (e) {
      foundation.debugPrint('❌ Veri sayısı alma hatası: $e');
      return 0;
    }
  }

  /// Box'ı kapatır ve kaynakları serbest bırakır
  static Future<void> close() async {
    try {
      if (_box != null) {
        await _box!.close();
        _box = null;
        foundation.debugPrint('🔒 Box kapatıldı');
      }
    } catch (e) {
      foundation.debugPrint('❌ Box kapatma hatası: $e');
    }
  }

  /// Birden fazla veriyi tek işlemde kaydeder (batch operation)
  /// Büyük veri setleri için performans optimizasyonu sağlar
  static Future<bool> putAll(Map<String, dynamic> items) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Tüm verileri tek işlemde kaydet
      await _box!.putAll(items);
      
      foundation.debugPrint('💾 ${items.length} adet veri batch olarak kaydedildi');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Batch kaydetme hatası: $e');
      return false;
    }
  }

  /// Birden fazla key'i tek işlemde siler (batch operation)
  /// Büyük veri setleri için performans optimizasyonu sağlar
  static Future<bool> deleteAll(List<String> keys) async {
    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      // Tüm key'leri tek işlemde sil
      await _box!.deleteAll(keys);
      
      foundation.debugPrint('🗑️ ${keys.length} adet key batch olarak silindi');
      return true;
    } catch (e) {
      foundation.debugPrint('❌ Batch silme hatası: $e');
      return false;
    }
  }

  /// Tüm verileri konsola yazdır (debug amaçlı)
  /// Sadece debug modunda çalışır, production'da UI dondurmasını önler
  static Future<void> debugPrintAll() async {
    // Production safety: sadece debug modunda çalışır
    if (!kDebugMode) {
      return;
    }

    try {
      // Box'ın açık olup olmadığını kontrol et
      if (_box == null) {
        foundation.debugPrint('⚠️ Box henüz açılmadı, init() çağrılıyor...');
        await init();
      }
      
      final keys = _box!.keys;
      
      foundation.debugPrint('=== Hive Debug ===');
      foundation.debugPrint('Toplam Key Sayısı: ${keys.length}');
      
      for (var key in keys) {
        final value = _box!.get(key);
        foundation.debugPrint('[$key] = $value');
      }
      
      foundation.debugPrint('=== Debug Sonu ===');
    } catch (e) {
      foundation.debugPrint('❌ Debug yazdırma hatası: $e');
    }
  }

  /// String verisi kaydetme (yardımcı metod)
  static Future<bool> saveString(String key, String value) async {
    return await saveData(key, value);
  }

  /// String verisi getirme (yardımcı metod)
  static Future<String?> getString(String key) async {
    final value = await getData(key);
    return value as String?;
  }

  /// Int verisi kaydetme (yardımcı metod)
  static Future<bool> saveInt(String key, int value) async {
    return await saveData(key, value);
  }

  /// Int verisi getirme (yardımcı metod)
  static Future<int?> getInt(String key) async {
    final value = await getData(key);
    return value as int?;
  }

  /// Double verisi kaydetme (yardımcı metod)
  static Future<bool> saveDouble(String key, double value) async {
    return await saveData(key, value);
  }

  /// Double verisi getirme (yardımcı metod)
  static Future<double?> getDouble(String key) async {
    final value = await getData(key);
    return value as double?;
  }

  /// Bool verisi kaydetme (yardımcı metod)
  static Future<bool> saveBool(String key, bool value) async {
    return await saveData(key, value);
  }

  /// Bool verisi getirme (yardımcı metod)
  static Future<bool?> getBool(String key) async {
    final value = await getData(key);
    return value as bool?;
  }

  /// Map verisi kaydetme (yardımcı metod)
  static Future<bool> saveMap(String key, Map<String, dynamic> value) async {
    return await saveData(key, value);
  }

  /// Map verisi getirme (yardımcı metod)
  static Future<Map<String, dynamic>?> getMap(String key) async {
    final value = await getData(key);
    return value as Map<String, dynamic>?;
  }

  /// List verisi kaydetme (yardımcı metod)
  static Future<bool> saveList(String key, List<dynamic> value) async {
    return await saveData(key, value);
  }

  /// List verisi getirme (yardımcı metod)
  static Future<List<dynamic>?> getList(String key) async {
    final value = await getData(key);
    return value as List<dynamic>?;
  }

  /// Box durumunu kontrol eder (açık/kapalı)
  static bool get isOpen => _box != null && _box!.isOpen;

  /// Box adını döndürür
  static String get boxName => _box?.name ?? 'expertize_system';
}

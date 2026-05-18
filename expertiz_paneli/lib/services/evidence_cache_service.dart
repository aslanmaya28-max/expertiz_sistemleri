/// EVIDENCE CACHE SERVICE
/// 
/// FAZ-1.0 / C1 — Offline Snapshot & Resilience Service
/// 
/// ⚖️ PURPOSE:
/// Provides offline caching for evidence data using SharedPreferences
/// Ensures data resilience and smooth UX during network failures
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evidence Cache Service
/// 
/// Manages offline caching of evidence data for all panel types
/// Provides automatic cache invalidation and sync mechanisms
class EvidenceCacheService {
  /// Cache key prefix
  static const String _cacheKeyPrefix = 'evidence_cache_';
  
  /// Cache timestamp key
  static const String _timestampKey = '_timestamp';
  
  /// Cache duration in hours (default: 24 hours)
  final int cacheDurationHours;
  
  /// SharedPreferences instance
  SharedPreferences? _prefs;

  EvidenceCacheService({
    this.cacheDurationHours = 24,
  });

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get cache key for panel type
  String _getCacheKey(String panelType, String? userId) {
    if (userId != null) {
      // FIXED: Removed unnecessary backslash escape
      return '$_cacheKeyPrefix${panelType}_$userId';
    }
    return '$_cacheKeyPrefix$panelType';
  }

  /// Save evidence list to cache
  Future<void> saveEvidence({
    required String panelType,
    required List<Map<String, dynamic>> evidenceList,
    String? userId,
  }) async {
    if (_prefs == null) await init();
    
    final cacheKey = _getCacheKey(panelType, userId);
    // FIXED: Removed unnecessary braces in string interpolation
    final timestampKey = '$cacheKey$_timestampKey';
    
    // Save evidence data
    await _prefs!.setString(cacheKey, jsonEncode(evidenceList));
    
    // Save timestamp
    await _prefs!.setString(
      timestampKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Load evidence list from cache
  Future<List<Map<String, dynamic>>?> loadEvidence({
    required String panelType,
    String? userId,
  }) async {
    if (_prefs == null) await init();
    
    final cacheKey = _getCacheKey(panelType, userId);
    // FIXED: Removed unnecessary braces in string interpolation
    final timestampKey = '$cacheKey$_timestampKey';
    
    // Check if cache exists
    final cachedData = _prefs!.getString(cacheKey);
    if (cachedData == null) return null;
    
    // Check if cache is expired
    final timestampStr = _prefs!.getString(timestampKey);
    if (timestampStr == null) {
      await clearCache(panelType: panelType, userId: userId);
      return null;
    }
    
    final timestamp = DateTime.parse(timestampStr);
    final now = DateTime.now();
    final age = now.difference(timestamp);
    
    if (age.inHours > cacheDurationHours) {
      // Cache expired, clear it
      await clearCache(panelType: panelType, userId: userId);
      return null;
    }
    
    // Return cached data
    try {
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      // Invalid cache, clear it
      await clearCache(panelType: panelType, userId: userId);
      return null;
    }
  }

  /// Get cache age in minutes
  Future<int?> getCacheAge({
    required String panelType,
    String? userId,
  }) async {
    if (_prefs == null) await init();
    
    final cacheKey = _getCacheKey(panelType, userId);
    // FIXED: Removed unnecessary braces in string interpolation
    final timestampKey = '$cacheKey$_timestampKey';
    
    final timestampStr = _prefs!.getString(timestampKey);
    if (timestampStr == null) return null;
    
    final timestamp = DateTime.parse(timestampStr);
    final now = DateTime.now();
    return now.difference(timestamp).inMinutes;
  }

  /// Clear cache for specific panel
  Future<void> clearCache({
    required String panelType,
    String? userId,
  }) async {
    if (_prefs == null) await init();
    
    final cacheKey = _getCacheKey(panelType, userId);
    // FIXED: Removed unnecessary braces in string interpolation
    final timestampKey = '$cacheKey$_timestampKey';
    
    await _prefs!.remove(cacheKey);
    await _prefs!.remove(timestampKey);
  }

  /// Clear all evidence caches
  Future<void> clearAllCaches() async {
    if (_prefs == null) await init();
    
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix)) {
        await _prefs!.remove(key);
      }
    }
  }

  /// Check if cache is available and fresh
  Future<bool> isCacheAvailable({
    required String panelType,
    String? userId,
  }) async {
    final cached = await loadEvidence(
      panelType: panelType,
      userId: userId,
    );
    return cached != null && cached.isNotEmpty;
  }
}

/// Evidence Stream with Offline Support
/// 
/// Combines Supabase Realtime streams with offline caching
/// Provides seamless experience even during network failures
class EvidenceStreamService {
  /// Cache service instance
  final EvidenceCacheService cacheService;
  
  /// Supabase client instance
  final SupabaseClient supabase;

  EvidenceStreamService({
    required this.cacheService,
    required this.supabase,
  });

  /// Stream admin evidence with offline fallback
  Stream<List<Map<String, dynamic>>> getAdminEvidenceStream({
    int limit = 50,
    int offset = 0,
  }) async* {
    bool hasEmitted = false;

    try {
      // Try to load from cache first
      final cached = await cacheService.loadEvidence(
        panelType: 'admin',
        userId: null,
      );

      if (cached != null && cached.isNotEmpty) {
        // Emit cached data immediately
        yield cached.map((e) => {...e, '_isCached': true}).toList();
        hasEmitted = true;
      }

      // Subscribe to realtime updates
      final stream = supabase
          .from('explainability_ledger')
          .stream(primaryKey: ['id'])
          .order('sealed_at', ascending: false)
          .limit(limit);

      await for (final data in stream) {
        // Transform data to match RPC structure
        final transformed = data.map((item) {
          final reasoning = item['reasoning'] as Map<String, dynamic>?;
          return {
            'id': item['id'],
            'sealed_at': item['sealed_at'],
            'decision_hash': item['decision_hash'],
            'report_id': item['report_id'],
            'analyst_id': item['analyst_id'],
            'observation': reasoning?['observation'] ?? '',
            'assumption': reasoning?['assumption'] ?? '',
            'limitation': reasoning?['limitation'] ?? '',
            '_isCached': false,
          };
        }).toList();

        // Update cache with fresh data
        await cacheService.saveEvidence(
          panelType: 'admin',
          evidenceList: transformed,
        );

        yield transformed;
      }
    } catch (e) {
      // If stream fails and we haven't emitted cached data, try one more time
      if (!hasEmitted) {
        final cached = await cacheService.loadEvidence(
          panelType: 'admin',
          userId: null,
        );
        if (cached != null) {
          yield cached.map((e) => {...e, '_isCached': true}).toList();
        }
      }
    }
  }

  /// Stream personnel evidence with offline fallback
  Stream<List<Map<String, dynamic>>> getPersonnelEvidenceStream({
    required String personnelId,
    int limit = 50,
    int offset = 0,
  }) async* {
    bool hasEmitted = false;

    try {
      // Try to load from cache first
      final cached = await cacheService.loadEvidence(
        panelType: 'personnel',
        userId: personnelId,
      );

      if (cached != null && cached.isNotEmpty) {
        yield cached.map((e) => {...e, '_isCached': true}).toList();
        hasEmitted = true;
      }

      // Subscribe to realtime updates
      final stream = supabase
          .from('explainability_ledger')
          .stream(primaryKey: ['id'])
          .eq('analyst_id', personnelId)
          .order('sealed_at', ascending: false)
          .limit(limit);

      await for (final data in stream) {
        final transformed = data.map((item) {
          final reasoning = item['reasoning'] as Map<String, dynamic>?;
          return {
            'id': item['id'],
            'sealed_at': item['sealed_at'],
            'decision_hash': item['decision_hash'],
            'report_id': item['report_id'],
            'analyst_id': item['analyst_id'],
            'observation': reasoning?['observation'] ?? '',
            'assumption': reasoning?['assumption'] ?? '',
            'limitation': reasoning?['limitation'] ?? '',
            '_isCached': false,
          };
        }).toList();

        await cacheService.saveEvidence(
          panelType: 'personnel',
          evidenceList: transformed,
          userId: personnelId,
        );

        yield transformed;
      }
    } catch (e) {
      if (!hasEmitted) {
        final cached = await cacheService.loadEvidence(
          panelType: 'personnel',
          userId: personnelId,
        );
        if (cached != null) {
          yield cached.map((e) => {...e, '_isCached': true}).toList();
        }
      }
    }
  }

  /// Stream customer evidence with offline fallback
  Stream<List<Map<String, dynamic>>> getCustomerEvidenceStream({
    required String customerId,
    int limit = 50,
    int offset = 0,
  }) async* {
    bool hasEmitted = false;

    try {
      // Try to load from cache first
      final cached = await cacheService.loadEvidence(
        panelType: 'customer',
        userId: customerId,
      );

      if (cached != null && cached.isNotEmpty) {
        yield cached.map((e) => {...e, '_isCached': true}).toList();
        hasEmitted = true;
      }

      // Subscribe to realtime updates
      final stream = supabase
          .from('explainability_ledger')
          .stream(primaryKey: ['id'])
          .order('sealed_at', ascending: false)
          .limit(limit);

      await for (final data in stream) {
        // Filter by customer's reports
        final reportIds = await _getCustomerReportIds(customerId);
        final filtered = data.where((item) {
          final reportId = item['report_id'];
          return reportIds.contains(reportId);
        }).toList();

        final transformed = filtered.map((item) {
          final reasoning = item['reasoning'] as Map<String, dynamic>?;
          return {
            'id': item['id'],
            'sealed_at': item['sealed_at'],
            'decision_hash': item['decision_hash'],
            'report_id': item['report_id'],
            'analyst_id': item['analyst_id'],
            'observation': reasoning?['observation'] ?? '',
            'assumption': reasoning?['assumption'] ?? '',
            'limitation': reasoning?['limitation'] ?? '',
            '_isCached': false,
          };
        }).toList();

        await cacheService.saveEvidence(
          panelType: 'customer',
          evidenceList: transformed,
          userId: customerId,
        );

        yield transformed;
      }
    } catch (e) {
      if (!hasEmitted) {
        final cached = await cacheService.loadEvidence(
          panelType: 'customer',
          userId: customerId,
        );
        if (cached != null) {
          yield cached.map((e) => {...e, '_isCached': true}).toList();
        }
      }
    }
  }

  /// Get customer report IDs
  Future<List<String>> _getCustomerReportIds(String customerId) async {
    final response = await supabase
        .from('raporlar')
        .select('id')
        .eq('musteri_id', customerId);

    return response.map((r) => r['id'] as String).toList();
  }
}
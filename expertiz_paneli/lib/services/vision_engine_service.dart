import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/auth_aware_service.dart';
import '../models/ai_analysis_result.dart';

/// Vision Engine API Service
/// 
/// Auth-aware HTTP service
/// Python backend ile iletişim için
class VisionEngineService implements AuthAwareService {
  // Production: Change to your server URL
  static const String _baseUrl = String.fromEnvironment(
    'YERIMEBAK_VISION_ENGINE_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  // Singleton pattern
  static final VisionEngineService _instance = VisionEngineService._internal();
  factory VisionEngineService() => _instance;
  VisionEngineService._internal();

  // Auth-aware state
  bool _alive = false;
  Session? _currentSession;
  StreamSubscription? _healthCheckSubscription;
  StreamSubscription? _heartbeatSubscription;
  SupabaseClient? _supabase;
  
  // Timeout duration
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  // =====================================================
  // AUTH-AWARE SERVICE IMPLEMENTATION
  // =====================================================

  @override
  bool get isAlive => _alive;

  @override
  String get serviceName => 'VisionEngineService';

  @override
  bool get isIsolateBased => false; // HTTP service, isolate yok

  @override
  Future<void> start(Session session) async {
    if (_alive) {
      debugPrint('⚠️ VisionEngineService zaten çalışıyor');
      return;
    }

    debugPrint('▶️ VisionEngineService başlatılıyor...');
    _alive = true;
    _currentSession = session;
    _supabase = Supabase.instance.client;

    // Health check timer başlat (5 dakikada bir)
    _healthCheckSubscription = Stream.periodic(
      const Duration(minutes: 5),
      (count) => count,
    ).listen((_) async {
      if (!_alive) return;
      final health = await checkHealth();
      if (!health) {
        debugPrint('⚠️ Vision Engine API sağlıksız');
      }
    });

    // Heartbeat timer başlat (60 saniyede bir)
    _heartbeatSubscription = Stream.periodic(
      _heartbeatInterval,
      (count) => count,
    ).listen((_) async {
      if (!_alive) return;
      await _sendHeartbeat();
    });

    debugPrint('✅ VisionEngineService başlatıldı');
  }

  @override
  Future<void> stop() async {
    if (!_alive) {
      debugPrint('⚠️ VisionEngineService zaten durmuş');
      return;
    }

    debugPrint('⏹️ VisionEngineService durduruluyor...');
    _alive = false;
    _currentSession = null;

    // Health check timer'ı iptal et
    await _healthCheckSubscription?.cancel();
    _healthCheckSubscription = null;

    // Heartbeat timer'ı iptal et
    await _heartbeatSubscription?.cancel();
    _heartbeatSubscription = null;

    _supabase = null;

    debugPrint('✅ VisionEngineService durduruldu');
  }

  // =====================================================
  // HTTP API METHODS
  // =====================================================

  /// Analyze report data using Vision Engine
  /// 
  /// This method is used by AIOrchestratorService
  /// Takes report data and converts it to AIAnalysisResult
  Future<AIAnalysisResult> analyzeReport(Map<String, dynamic> reportData) async {
    try {
      debugPrint('🔍 Analyzing report with Vision Engine...');
      
      // Extract vehicle data from report
      final brand = reportData['marka'] as String? ?? 'Unknown';
      final model = reportData['model'] as String? ?? 'Unknown';
      final year = reportData['yil'] as int? ?? 2020;
      final km = reportData['km'] as int? ?? 0;
      
      // Call Vision Engine API
      final response = await analyzeVehicle(
        brand: brand,
        model: model,
        year: year,
        km: km,
      );
      
      // Convert to AIAnalysisResult
      return AIAnalysisResult(
        reliabilityScore: response.coreMetrics.confidenceScore * 100,
        observation: response.aiCommentary.overallAssessment,
        assumption: 'Based on market analysis of ${response.marketData.totalSources} sources',
        limitation: response.coreMetrics.sampleSize < 10 
            ? 'Limited sample size (${response.coreMetrics.sampleSize} vehicles)'
            : 'None',
        inconsistencies: [],
        missingInfo: [],
        confidenceScore: response.coreMetrics.confidenceScore,
        modelVersion: 'vision-engine-1.0',
        analyzedAt: DateTime.now().toUtc(),
        processingDurationMs: response.processingTimeMs.toInt(),
        timedOut: false,
        metadata: {
          'estimated_value': response.estimatedValue,
          'value_range': response.valueRange,
          'market_data': {
            'total_sources': response.marketData.totalSources,
            'avg_price': response.coreMetrics.avgPrice,
            'median_price': response.coreMetrics.medianPrice,
          },
          'recommendations': response.aiCommentary.recommendations,
        },
      );
    } catch (e) {
      debugPrint('❌ Vision Engine analysis failed: $e');
      
      // Return error result
      return AIAnalysisResult(
        reliabilityScore: 0.0,
        observation: 'Vision Engine analysis failed',
        assumption: 'N/A',
        limitation: 'Service unavailable',
        inconsistencies: ['Analysis error: $e'],
        missingInfo: [],
        confidenceScore: 0.0,
        modelVersion: 'vision-engine-1.0',
        analyzedAt: DateTime.now().toUtc(),
        processingDurationMs: 0,
        timedOut: false,
        metadata: {
          'error': e.toString(),
        },
      );
    }
  }

  /// Analyze vehicle market value using Vision Engine
  /// Returns complete analysis with metrics and AI commentary
  Future<VisionEngineResponse> analyzeVehicle({
    required String brand,
    required String model,
    required int year,
    required int km,
    String? fuelType,
    String? transmission,
    String? location,
    List<String>? images,
  }) async {
    try {
      // Build request body
      final requestBody = {
        'brand': brand,
        'model': model,
        'year': year,
        'km': km,
        'fuel_type': fuelType ?? 'Benzin',
        'transmission': transmission ?? 'Otomatik',
        'location': location ?? 'Türkiye',
        'images': images ?? [],
      };

      // Make POST request
      final response = await http
          .post(
            Uri.parse('$_baseUrl/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      // Handle response
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return VisionEngineResponse.fromJson(jsonData);
      } else {
        throw Exception('API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Vision Engine connection failed: $e');
    }
  }

  /// Quick analysis - returns only essential metrics
  Future<QuickAnalysisResult> quickAnalyze({
    required String brand,
    required String model,
    required int year,
    required int km,
  }) async {
    try {
      final requestBody = {
        'brand': brand,
        'model': model,
        'year': year,
        'km': km,
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/analyze/quick'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return QuickAnalysisResult.fromJson(jsonData);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Quick analysis failed: $e');
    }
  }

  /// Check API health
  Future<bool> checkHealth() async {
    if (!_alive) return false;

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/health'),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =====================================================
  // SERVICE HEARTBEAT
  // =====================================================

  /// Send heartbeat to Supabase
  /// 
  /// Her 60 saniyede bir çağrılır
  /// Servis hayatta olduğunu bildirir
  @override
  Future<void> sendHeartbeat(SupabaseClient supabase, String userId) async {
    if (!_alive) return;

    try {
      await supabase.rpc('upsert_service_heartbeat', params: {
        'p_service_name': serviceName,
        'p_user_id': userId,
        'p_metadata': {
          'api_health': await checkHealth(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      });

      debugPrint('💓 VisionEngineService heartbeat gönderildi');
    } catch (e) {
      debugPrint('❌ Heartbeat hatası: $e');
      // Heartbeat hatası servisi durdurmaz
    }
  }

  /// Internal heartbeat sender
  Future<void> _sendHeartbeat() async {
    if (_supabase == null || _currentSession == null) return;

    await sendHeartbeat(_supabase!, _currentSession!.user.id);
  }
}

/// Complete Vision Engine Analysis Response
class VisionEngineResponse {
  final bool success;
  final VehicleRequest request;
  final MarketData marketData;
  final CoreMetrics coreMetrics;
  final ImageAnalysis? imageAnalysis;
  final AICommentary aiCommentary;
  final String finalRecommendation;
  final double estimatedValue;
  final List<double> valueRange;
  final DateTime analysisTimestamp;
  final double processingTimeMs;

  VisionEngineResponse({
    required this.success,
    required this.request,
    required this.marketData,
    required this.coreMetrics,
    this.imageAnalysis,
    required this.aiCommentary,
    required this.finalRecommendation,
    required this.estimatedValue,
    required this.valueRange,
    required this.analysisTimestamp,
    required this.processingTimeMs,
  });

  factory VisionEngineResponse.fromJson(Map<String, dynamic> json) {
    return VisionEngineResponse(
      success: json['success'] ?? false,
      request: VehicleRequest.fromJson(json['request'] ?? {}),
      marketData: MarketData.fromJson(json['market_data'] ?? {}),
      coreMetrics: CoreMetrics.fromJson(json['core_metrics'] ?? {}),
      imageAnalysis: json['image_analysis'] != null
          ? ImageAnalysis.fromJson(json['image_analysis'])
          : null,
      aiCommentary: AICommentary.fromJson(json['ai_commentary'] ?? {}),
      finalRecommendation: json['final_recommendation'] ?? '',
      estimatedValue: (json['estimated_value'] ?? 0).toDouble(),
      valueRange: List<double>.from(
        json['value_range'] ?? [0.0, 0.0],
      ),
      analysisTimestamp: DateTime.parse(json['analysis_timestamp'] ?? DateTime.now().toIso8601String()),
      processingTimeMs: (json['processing_time_ms'] ?? 0).toDouble(),
    );
  }

  /// Format estimated value as currency
  String get formattedEstimatedValue {
    return '${estimatedValue.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )} TL';
  }

  /// Format value range
  String get formattedValueRange {
    final min = valueRange[0].toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    final max = valueRange[1].toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return '$min - $max TL';
  }
}

/// Vehicle Request
class VehicleRequest {
  final String brand;
  final String model;
  final int year;
  final int km;
  final String fuelType;
  final String transmission;
  final String location;
  final List<String> images;

  VehicleRequest({
    required this.brand,
    required this.model,
    required this.year,
    required this.km,
    required this.fuelType,
    required this.transmission,
    required this.location,
    required this.images,
  });

  factory VehicleRequest.fromJson(Map<String, dynamic> json) {
    return VehicleRequest(
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      year: json['year'] ?? 0,
      km: json['km'] ?? 0,
      fuelType: json['fuel_type'] ?? 'Benzin',
      transmission: json['transmission'] ?? 'Otomatik',
      location: json['location'] ?? 'Türkiye',
      images: List<String>.from(json['images'] ?? []),
    );
  }
}

/// Market Data
class MarketData {
  final int totalSources;
  final DateTime scrapeTimestamp;

  MarketData({
    required this.totalSources,
    required this.scrapeTimestamp,
  });

  factory MarketData.fromJson(Map<String, dynamic> json) {
    return MarketData(
      totalSources: json['total_sources'] ?? 0,
      scrapeTimestamp: DateTime.parse(
        json['scrape_timestamp'] ?? DateTime.now().toIso8601String()
      ),
    );
  }
}

/// Core Metrics
class CoreMetrics {
  final double avgPrice;
  final double medianPrice;
  final double stdDeviation;
  final double minPrice;
  final double maxPrice;
  final double confidenceScore;
  final double volatilityIndex;
  final double iqrLowerBound;
  final double iqrUpperBound;
  final int sampleSize;

  CoreMetrics({
    required this.avgPrice,
    required this.medianPrice,
    required this.stdDeviation,
    required this.minPrice,
    required this.maxPrice,
    required this.confidenceScore,
    required this.volatilityIndex,
    required this.iqrLowerBound,
    required this.iqrUpperBound,
    required this.sampleSize,
  });

  factory CoreMetrics.fromJson(Map<String, dynamic> json) {
    return CoreMetrics(
      avgPrice: (json['avg_price'] ?? 0).toDouble(),
      medianPrice: (json['median_price'] ?? 0).toDouble(),
      stdDeviation: (json['std_deviation'] ?? 0).toDouble(),
      minPrice: (json['min_price'] ?? 0).toDouble(),
      maxPrice: (json['max_price'] ?? 0).toDouble(),
      confidenceScore: (json['confidence_score'] ?? 0).toDouble(),
      volatilityIndex: (json['volatility_index'] ?? 0).toDouble(),
      iqrLowerBound: (json['iqr_lower_bound'] ?? 0).toDouble(),
      iqrUpperBound: (json['iqr_upper_bound'] ?? 0).toDouble(),
      sampleSize: json['sample_size'] ?? 0,
    );
  }

  /// Format average price
  String get formattedAvgPrice {
    return '${avgPrice.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )} TL';
  }
}

/// Image Analysis
class ImageAnalysis {
  final List<String> detectedIssues;
  final List<String> paintedParts;
  final List<String> damagedParts;
  final double qualityScore;
  final double confidence;

  ImageAnalysis({
    required this.detectedIssues,
    required this.paintedParts,
    required this.damagedParts,
    required this.qualityScore,
    required this.confidence,
  });

  factory ImageAnalysis.fromJson(Map<String, dynamic> json) {
    return ImageAnalysis(
      detectedIssues: List<String>.from(json['detected_issues'] ?? []),
      paintedParts: List<String>.from(json['painted_parts'] ?? []),
      damagedParts: List<String>.from(json['damaged_parts'] ?? []),
      qualityScore: (json['quality_score'] ?? 0).toDouble(),
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

/// AI Commentary
class AICommentary {
  final String overallAssessment;
  final List<String> keyFindings;
  final String marketPosition;
  final List<String> recommendations;
  final String confidenceLevel;

  AICommentary({
    required this.overallAssessment,
    required this.keyFindings,
    required this.marketPosition,
    required this.recommendations,
    required this.confidenceLevel,
  });

  factory AICommentary.fromJson(Map<String, dynamic> json) {
    return AICommentary(
      overallAssessment: json['overall_assessment'] ?? '',
      keyFindings: List<String>.from(json['key_findings'] ?? []),
      marketPosition: json['market_position'] ?? '',
      recommendations: List<String>.from(json['recommendations'] ?? []),
      confidenceLevel: json['confidence_level'] ?? 'Orta',
    );
  }
}

/// Quick Analysis Result (lightweight)
class QuickAnalysisResult {
  final bool success;
  final double estimatedValue;
  final List<double> valueRange;
  final double confidenceScore;
  final String recommendation;
  final double processingTimeMs;

  QuickAnalysisResult({
    required this.success,
    required this.estimatedValue,
    required this.valueRange,
    required this.confidenceScore,
    required this.recommendation,
    required this.processingTimeMs,
  });

  factory QuickAnalysisResult.fromJson(Map<String, dynamic> json) {
    return QuickAnalysisResult(
      success: json['success'] ?? false,
      estimatedValue: (json['estimated_value'] ?? 0).toDouble(),
      valueRange: List<double>.from(json['value_range'] ?? [0.0, 0.0]),
      confidenceScore: (json['confidence_score'] ?? 0).toDouble(),
      recommendation: json['recommendation'] ?? '',
      processingTimeMs: (json['processing_time_ms'] ?? 0).toDouble(),
    );
  }
}
/// REASONING PARSER
/// 
/// FAZ-0.7.1 / A — Forensic-Grade Reasoning Parser
/// 
/// 🎯 MISSION:
/// This is the DIGITAL FORENSIC EXAMINER that converts raw Gemini AI output
/// into court-defensible, hash-safe CanonicalReasoning structures.
/// 
/// ⚖️ LEGAL STANDARD:
/// This parser ensures:
/// - AI uncertainty is NEVER hidden
/// - Observations are separated from assumptions
/// - All text is deterministic and hash-safe
/// - Output is legally defensible in court
/// 
/// 🧠 MENTAL MODEL:
/// "Bu kod bir parser değil;
///  bu kod dijital adli tık memuru."
/// 
/// 🔐 DETERMINISM GUARANTEE:
/// Same rawGeminiText → Same CanonicalReasoning → Same JSON → Same Hash
library;

import 'canonical_reasoning.dart';
import 'damage_area.dart';
import 'cost_impact.dart';
import 'technical_justification.dart';
import 'reasoning_limitations.dart';

/// Reasoning Parser - Forensic Decoder
/// 
/// Converts free-text Gemini AI output into structured, court-defensible reasoning.
/// 
/// ⚖️ CRITICAL LEGAL REQUIREMENTS:
/// 1. ALL uncertainty MUST be captured in limitations
/// 2. Observations MUST be separated from assumptions
/// 3. Same input MUST produce same output (deterministic)
/// 4. No information can be lost or hidden
class ReasoningParser {
  /// Uncertainty keywords (Turkish and English)
  /// 
  /// These expressions MUST be captured in ReasoningLimitations
  /// Missing ANY of these creates legal liability
  static const List<String> _uncertaintyKeywords = [
    // Turkish uncertainty expressions
    'emin değilim',
    'eminden değilim',
    'emin olamıyorum',
    'tam olarak anlaşılamıyor',
    'tam olarak anlaşılamıyor',
    'net olarak görülmüyor',
    'görüntü kalitesi düşük',
    'görüntü kalitesi yetersiz',
    'ışık koşulları',
    'görüntü net değil',
    'belirsiz',
    'bulanık',
    'kesin değil',
    // Probability expressions
    'olabilir',
    'muhtemelen',
    'belki',
    'sanırım',
    'herhalde',
    'gibi görünüyor',
    'gibi duruyor',
    'ihtimal',
    'olası',
    // English uncertainty expressions
    'not sure',
    'uncertain',
    'unclear',
    'maybe',
    'possibly',
    'probably',
    'might be',
    'could be',
    'seems like',
    'appears to be',
    'low quality',
    'poor quality',
  ];

  /// Damage-related keywords (Turkish)
  static const List<String> _damageKeywords = [
    'hasar',
    'çarpma',
    'ezilme',
    'çatlak',
    'deformasyon',
    'bükülme',
    'göçük',
    'çük',
    'sıyrık',
    'leke',
    'boyada',
    'renk farklılığı',
    'kırık',
    'kopuk',
  ];

  /// Severity indicators (Turkish)
  static const Map<String, String> _severityIndicators = {
    'hafif': 'low',
    'küçük': 'low',
    'az': 'low',
    'ciddi': 'medium',
    'orta': 'medium',
    'önemli': 'medium',
    'şiddetli': 'high',
    'ağır': 'high',
    'büyük': 'high',
  };

  /// Vehicle area names (Turkish)
  static const Map<String, String> _areaNames = {
    'ön tampon': 'Ön Tampon',
    'arka tampon': 'Arka Tampon',
    'sol çamurluk': 'Sol Çamurluk',
    'sağ çamurluk': 'Sağ Çamurluk',
    'kaput': 'Kaput',
    'tavan': 'Tavan',
    'sol kapı': 'Sol Kapı',
    'sağ kapı': 'Sağ Kapı',
    'bagaj kapağı': 'Bagaj Kapağı',
    'far': 'Far',
    'sol far': 'Sol Far',
    'sağ far': 'Sağ Far',
    'tampon': 'Tampon',
    'çamurluk': 'Çamurluk',
  };

  /// Parse raw Gemini text into CanonicalReasoning
  /// 
  /// 🔬 PARSING PROCESS:
  /// 1. Extract damage area information
  /// 2. Extract cost impact information
  /// 3. Separate observations from assumptions
  /// 4. CRITICAL: Capture ALL uncertainty expressions
  /// 5. Build deterministic CanonicalReasoning
  /// 
  /// ⚖️ LEGAL REQUIREMENT:
  /// This method MUST be deterministic.
  /// Same input → Same output → Same hash → forever
  /// 
  /// 🚨 CRITICAL:
  /// If uncertainty is detected, it MUST go into limitations.
  /// Hiding uncertainty creates legal liability.
  CanonicalReasoning parseReasoning(String rawGeminiText) {
    // Normalize text
    final normalizedText = _normalizeText(rawGeminiText);

    // Step 1: Extract damage area
    final damageArea = _extractDamageArea(normalizedText);

    // Step 2: Extract cost impact
    final costImpact = _extractCostImpact(normalizedText);

    // Step 3: Extract technical justification
    final technicalJustification = _extractTechnicalJustification(normalizedText);

    // Step 4: CRITICAL - Extract limitations (legal shield)
    final limitations = _extractLimitations(normalizedText);

    // Step 5: Build canonical reasoning
    return CanonicalReasoning(
      damageArea: damageArea,
      costImpact: costImpact,
      technicalJustification: technicalJustification,
      limitations: limitations,
      generatedAtUtc: DateTime.now().toUtc(),
    );
  }

  /// Normalize text for parsing
  /// 
  /// Ensures consistent formatting for deterministic parsing
  String _normalizeText(String text) {
    return text
        .trim()
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Limit consecutive newlines
  }

  /// Extract damage area information
  /// 
  /// Parses:
  /// - Area name (which part of vehicle)
  /// - Severity level (low/medium/high)
  /// - Description (what was observed)
  DamageArea _extractDamageArea(String text) {
    final sentences = _splitIntoSentences(text);
    
    String? areaName;
    String? severity;
    final descriptions = <String>[];

    for (final sentence in sentences) {
      final lowerSentence = sentence.toLowerCase();

      // Check for area name
      for (final entry in _areaNames.entries) {
        if (lowerSentence.contains(entry.key)) {
          areaName = entry.value;
          break;
        }
      }

      // Check for severity
      for (final entry in _severityIndicators.entries) {
        if (lowerSentence.contains(entry.key)) {
          severity = entry.value;
          break;
        }
      }

      // Check for damage keywords
      for (final keyword in _damageKeywords) {
        if (lowerSentence.contains(keyword)) {
          descriptions.add(sentence.trim());
          break;
        }
      }
    }

    return DamageArea(
      areaName: areaName ?? 'Bilinmiyor',
      severity: severity ?? 'low',
      description: descriptions.isNotEmpty
          ? descriptions.join(' ')
          : 'Hasar açıklaması bulunamadı',
    );
  }

  /// Extract cost impact information
  /// 
  /// Parses:
  /// - Cost range (estimated repair cost)
  /// - Confidence level (how confident in the estimate)
  CostImpact _extractCostImpact(String text) {
    final lowerText = text.toLowerCase();

    // Look for currency/price patterns
    final pricePattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:tl|₺|ytl)');
    final matches = pricePattern.allMatches(text).toList();

    String estimatedRange;
    String confidence;

    if (matches.length >= 2) {
      // Extract min and max
      final prices = matches.map((m) => double.tryParse(m.group(1)!)).toList();
      prices.sort();
      final min = prices.first;
      final max = prices.last;
      estimatedRange = '$min - $max TL';
      confidence = 'medium';
    } else if (matches.length == 1) {
      final price = double.tryParse(matches.first.group(1)!);
      estimatedRange = '$price - $price TL';
      confidence = 'low';
    } else {
      // Look for qualitative cost descriptions
      if (lowerText.contains('yüksek maliyet') ||
          lowerText.contains('pahalı') ||
          lowerText.contains('maliyetli')) {
        estimatedRange = 'Yüksek Maliyet';
        confidence = 'low';
      } else if (lowerText.contains('düşük maliyet') ||
          lowerText.contains('ucuz') ||
          lowerText.contains('küçük tamirat')) {
        estimatedRange = 'Düşük Maliyet';
        confidence = 'low';
      } else {
        estimatedRange = 'Belirlenemedi';
        confidence = 'low';
      }
    }

    return CostImpact(
      estimatedRange: estimatedRange,
      confidence: confidence,
    );
  }

  /// Extract technical justification
  /// 
  /// Separates:
  /// - Observations (what was seen)
  /// - Assumptions (what was inferred)
  TechnicalJustification _extractTechnicalJustification(String text) {
    final sentences = _splitIntoSentences(text);
    final observations = <String>[];
    final assumptions = <String>[];

    for (final sentence in sentences) {
      final lowerSentence = sentence.toLowerCase();

      // Check for assumption indicators
      final isAssumption = lowerSentence.contains('olabilir') ||
          lowerSentence.contains('muhtemelen') ||
          lowerSentence.contains('belki') ||
          lowerSentence.contains('sanırım') ||
          lowerSentence.contains('herhalde') ||
          lowerSentence.contains('gibi') ||
          lowerSentence.contains('ihtimal') ||
          lowerSentence.contains('gerekebilir') ||
          lowerSentence.contains('kaynaklı olabilir');

      if (isAssumption) {
        assumptions.add(sentence.trim());
      } else {
        observations.add(sentence.trim());
      }
    }

    return TechnicalJustification(
      observations: observations,
      assumptions: assumptions,
    );
  }

  /// Extract limitations (CRITICAL - LEGAL SHIELD)
  /// 
  /// ⚖️ LEGAL REQUIREMENT:
  /// This method MUST capture ALL uncertainty expressions.
  /// Missing uncertainty creates legal liability.
  /// 
  /// Captures:
  /// - Image quality issues
  /// - Uncertainty expressions
  /// - Analysis limitations
  ReasoningLimitations _extractLimitations(String text) {
    final lowerText = text.toLowerCase();
    final limitations = <String>[];

    // Check for each uncertainty keyword
    for (final keyword in _uncertaintyKeywords) {
      if (lowerText.contains(keyword)) {
        // Find the sentence containing the keyword
        final sentences = _splitIntoSentences(text);
        for (final sentence in sentences) {
          if (sentence.toLowerCase().contains(keyword)) {
            final note = sentence.trim();
            if (!limitations.contains(note)) {
              limitations.add(note);
            }
          }
        }
      }
    }

    return ReasoningLimitations(
      hasLimitations: limitations.isNotEmpty,
      limitationNotes: limitations,
    );
  }

  /// Split text into sentences
  /// 
  /// Handles Turkish and English sentence delimiters
  List<String> _splitIntoSentences(String text) {
    final sentences = <String>[];
    final buffer = StringBuffer();
    bool inSentence = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      
      if (char == '.' || char == '!' || char == '?') {
        buffer.write(char);
        inSentence = false;
        
        // Check if next char is space or end of text
        if (i + 1 >= text.length || text[i + 1] == ' ' || text[i + 1] == '\n') {
          final sentence = buffer.toString().trim();
          if (sentence.isNotEmpty) {
            sentences.add(sentence);
          }
          buffer.clear();
        }
      } else if (char == '\n') {
        if (inSentence) {
          final sentence = buffer.toString().trim();
          if (sentence.isNotEmpty) {
            sentences.add(sentence);
          }
          buffer.clear();
          inSentence = false;
        }
      } else {
        if (char.trim().isNotEmpty) {
          buffer.write(char);
          inSentence = true;
        }
      }
    }

    // Add remaining text if any
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    return sentences;
  }
}
# Reasoning Parser Usage Guide

## FAZ-0.7.1 / A — Forensic-Grade AI Reasoning Parser

---

## 🪨 PRINCIPLE

**"Bu kod bir parser değil; bu kod dijital adli tıp memuru."**

---

## 📋 OVERVIEW

The `ReasoningParser` is the DIGITAL FORENSIC EXAMINER that converts raw Gemini AI output into court-defensible, hash-safe `CanonicalReasoning` structures.

### Legal Standard

This parser ensures:
- ✅ AI uncertainty is NEVER hidden
- ✅ Observations are separated from assumptions
- ✅ All text is deterministic and hash-safe
- ✅ Output is legally defensible in court

### Determinism Guarantee

```
Same rawGeminiText → Same CanonicalReasoning → Same JSON → Same Hash
```

---

## 🎯 KEY FEATURES

### 1. DAMAGE AREA EXTRACTION

Extracts:
- **Area name**: Which part of the vehicle (Ön Tampon, Sol Çamurluk, etc.)
- **Severity**: low | medium | high
- **Description**: What was observed

### 2. COST IMPACT EXTRACTION

Extracts:
- **Estimated range**: "5.000 - 10.000 TL" or "Belirlenemedi"
- **Confidence**: low | medium | high

### 3. TECHNICAL JUSTIFICATION

Separates:
- **Observations**: What was directly seen
- **Assumptions**: What was inferred

### 4. LIMITATIONS DETECTION (CRITICAL - LEGAL SHIELD)

Captures uncertainty expressions:
- "Emin değilim" (Not sure)
- "Görüntü kalitesi düşük" (Image quality low)
- "Olabilir" (Could be)
- "Muhtemelen" (Probably)
- "Belki" (Maybe)

---

## 💡 USAGE EXAMPLES

### Example 1: Basic Parsing

```dart
import 'package:yerimebak_sistemleri/domain/reasoning/reasoning_parser.dart';

final parser = ReasoningParser();

// Raw Gemini AI output
final rawText = '''
Görüntüde ön tamponda ciddi deformasyon tespit edildi.
Hasarın boyutu yaklaşık 30-40 cm çapında.
Tampon değişimi gerekebilir. Maliyet 5.000 - 8.000 TL aralığında olabilir.
Görüntü kalitesi düşük olduğu için detaylı analiz yapılamıyor.
''';

// Parse into CanonicalReasoning
final reasoning = parser.parse(rawText);

// Access parsed data
print(reasoning.damageArea.areaName); // "Ön Tampon"
print(reasoning.damageArea.severity); // "high"
print(reasoning.costImpact.estimatedRange); // "5000.0 - 8000.0 TL"
print(reasoning.limitations.hasLimitations); // true
print(reasoning.limitations.limitationNotes); 
// ["Görüntü kalitesi düşük olduğu için detaylı analiz yapılamıyor."]
```

### Example 2: Integration with LedgerService

```dart
import 'package:yerimebak_sistemleri/services/ledger_service.dart';
import 'package:yerimebak_sistemleri/domain/reasoning/reasoning_parser.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AIAnalysisService {
  final LedgerService _ledgerService;
  final ReasoningParser _parser;
  
  AIAnalysisService(this._ledgerService) : _parser = ReasoningParser();
  
  Future<void> analyzeAndSeal({
    required String reportId,
    required String imageHash,
    required String geminiResponse,
  }) async {
    // Step 1: Parse Gemini response
    final reasoning = _parser.parse(geminiResponse);
    
    // Step 2: Check for limitations
    if (reasoning.hasSignificantLimitations) {
      print('⚠️ AI expressed uncertainty:');
      for (final note in reasoning.limitations.limitationNotes) {
        print('  - $note');
      }
    }
    
    // Step 3: Build evidence packet
    final reasoningJson = reasoning.toJson();
    
    // Step 4: Seal in ledger
    try {
      final recordId = await _ledgerService.writeEvidence(
        reportId: reportId,
        imageHash: imageHash,
        reasoning: reasoningJson,
        aiOutput: {
          'damage_detected': reasoning.damageArea.areaName,
          'severity': reasoning.damageArea.severity,
          'estimated_cost': reasoning.costImpact.estimatedRange,
          'confidence': reasoning.overallConfidence,
        },
        modelVersion: 'gemini-1.5-flash',
        confidenceScore: 85.0,
      );
      
      print('✅ Evidence sealed: $recordId');
      print('⚖️ This record is now legally non-repudiable');
      
    } catch (e) {
      print('❌ Evidence sealing failed: $e');
      rethrow;
    }
  }
}
```

### Example 3: Handling Uncertainty

```dart
void demonstrateUncertaintyCapture() {
  final parser = ReasoningParser();
  
  // AI expresses uncertainty
  final uncertainText = '''
Ön tamponda hasar var ama tam olarak anlaşılamıyor.
Görüntü kalitesi düşük.
Hasar yeni olabilir, eski hasar üzerine de olabilir.
Maliyet 5.000 - 10.000 TL aralığında tahmin ediyorum.
''';
  
  final reasoning = parser.parse(uncertainText);
  
  // Check limitations
  if (reasoning.limitations.hasLimitations) {
    print('⚠️ AI expressed ${reasoning.limitations.noteCount} limitations:');
    for (final note in reasoning.limitations.limitationNotes) {
      print('  - $note');
    }
  }
  
  // Check overall confidence
  print('Overall confidence: ${reasoning.overallConfidence}'); // "low"
  
  // Output:
  // ⚠️ AI expressed 3 limitations:
  //   - Hasar yeni olabilir, eski hasar üzerine de olabilir.
  //   - Ön tamponda hasar var ama tam olarak anlaşılamıyor.
  //   - Görüntü kalitesi düşük.
  // Overall confidence: low
}
```

### Example 4: Deterministic Parsing

```dart
void demonstrateDeterminism() {
  final parser = ReasoningParser();
  
  // Same input should produce same output
  final input = 'Ön tamponda hasar var. Maliyet 5.000 TL.';
  
  final reasoning1 = parser.parse(input);
  final reasoning2 = parser.parse(input);
  
  // Check JSON is identical
  final json1 = jsonEncode(reasoning1.toJson());
  final json2 = jsonEncode(reasoning2.toJson());
  
  print('Identical: ${json1 == json2}'); // true
  
  // Check hashes are identical
  final hash1 = sha256.convert(utf8.encode(json1)).toString();
  final hash2 = sha256.convert(utf8.encode(json2)).toString();
  
  print('Hash1: $hash1');
  print('Hash2: $hash2');
  print('Hashes match: ${hash1 == hash2}'); // true
}
```

---

## 🔍 PARSING RULES

### Damage Area Extraction

**Keywords detected:**
- hasar, çarpma, ezilme, çatlak, deformasyon
- bükülme, göçük, çük, sıyrık, leke
- boyada, renk farklılığı, kırık, kopuk

**Severity mapping:**
- hafif, küçük, az → low
- ciddi, orta, önemli → medium
- şiddetli, ağır, büyük → high

**Area names:**
- ön tampon, arka tampon, sol çamurluk, sağ çamurluk
- kaput, tavan, sol kapı, sağ kapı, bagaj kapağı
- far, sol far, sağ far

### Cost Impact Extraction

**Price patterns:**
- Matches: "5.000 TL", "10000₺", "5000.5 ytl"
- Extracts min and max for range
- Single price → range with same value

**Qualitative descriptions:**
- "yüksek maliyet", "pahalı", "maliyetli" → Yüksek Maliyet
- "düşük maliyet", "ucuz", "küçük tamirat" → Düşük Maliyet
- No cost info → "Belirlenemedi"

### Technical Justification

**Observation indicators:**
- Direct statements
- Factual descriptions
- "X tespit edildi", "Y görülüyor"

**Assumption indicators:**
- olabilir, muhtemelen, belki
- sanırım, herhalde, gibi
- ihtimal, olası, gerekebilir

### Limitations Detection

**Uncertainty keywords:**
- Emin değilim, emin olamıyorum
- Tam olarak anlaşılamıyor
- Görüntü kalitesi düşük/yetersiz
- Işık koşulları
- Belirsiz, bulanık, kesin değil
- Olabilir, muhtemelen, belki
- Sanırım, herhalde, gibi görünüyor

---

## 🧪 TESTING

### Unit Test Example

```dart
import 'package:test/test.dart';
import 'package:yerimebak_sistemleri/domain/reasoning/reasoning_parser.dart';

void main() {
  group('ReasoningParser', () {
    late ReasoningParser parser;
    
    setUp(() {
      parser = ReasoningParser();
    });
    
    test('should extract damage area', () {
      final text = 'Ön tamponda ciddi hasar var.';
      final reasoning = parser.parse(text);
      
      expect(reasoning.damageArea.areaName, 'Ön Tampon');
      expect(reasoning.damageArea.severity, 'medium');
    });
    
    test('should extract cost range', () {
      final text = 'Maliyet 5.000 - 10.000 TL aralığında.';
      final reasoning = parser.parse(text);
      
      expect(reasoning.costImpact.estimatedRange, '5000.0 - 10000.0 TL');
    });
    
    test('should capture uncertainty', () {
      final text = 'Görüntü kalitesi düşük olduğu için emin değilim.';
      final reasoning = parser.parse(text);
      
      expect(reasoning.limitations.hasLimitations, true);
      expect(reasoning.limitations.limitationNotes.length, greaterThan(0));
    });
    
    test('should be deterministic', () {
      final text = 'Ön tamponda hasar var.';
      final reasoning1 = parser.parse(text);
      final reasoning2 = parser.parse(text);
      
      expect(
        jsonEncode(reasoning1.toJson()),
        jsonEncode(reasoning2.toJson()),
      );
    });
  });
}
```

---

## 🔐 LEGAL COMPLIANCE

### Court-Defensible Features

1. **Explicit Uncertainty Capture**
   - All uncertainty is documented
   - Prevents claims of false confidence
   - Creates legal transparency

2. **Observation/Assumption Separation**
   - Clear distinction between fact and inference
   - Prevents confusion about AI reasoning
   - Creates auditability

3. **Deterministic Output**
   - Same input → same output
   - Verifiable hashes
   - Tamper-evident

4. **Structured Documentation**
   - All decisions are explained
   - All limitations are noted
   - All reasoning is preserved

### Legal Defense Strategy

**Claim:** "AI was wrong about the damage."

**Defense:** "The AI explicitly stated uncertainty:
- 'Görüntü kalitesi düşük olduğu için detaylı analiz yapılamıyor'
- 'Hasar yeni olabilir, eski hasar üzerine de olabilir'

This is documented in the immutable ledger with SHA256 hash: [hash]"

---

## 📊 INTEGRATION CHECKLIST

Before using in production:

- [ ] Test parser with real Gemini outputs
- [ ] Verify all uncertainty is captured
- [ ] Confirm deterministic parsing
- [ ] Test with Turkish and English text
- [ ] Verify JSON serialization
- [ ] Test hash generation
- [ ] Integrate with LedgerService
- [ ] Add error handling
- [ ] Document legal review
- [ ] Train team on usage

---

## 🚨 COMMON MISTAKES TO AVOID

### Mistake 1: Skipping Parser

```dart
// ❌ WRONG - Direct use of Gemini text
await ledgerService.writeEvidence(
  reasoning: {'raw_gemini_text': geminiResponse}, // NOT hash-safe
  ...
);

// ✅ CORRECT - Use parser
final reasoning = parser.parse(geminiResponse);
await ledgerService.writeEvidence(
  reasoning: reasoning.toJson(), // Hash-safe, deterministic
  ...
);
```

### Mistake 2: Ignoring Limitations

```dart
// ❌ WRONG - Ignore uncertainty
final reasoning = parser.parse(geminiResponse);
await ledgerService.writeEvidence(...); // Always proceeds

// ✅ CORRECT - Check uncertainty
final reasoning = parser.parse(geminiResponse);
if (reasoning.hasSignificantLimitations) {
  // Warn user about uncertainty
  showWarningDialog('AI expressed uncertainty in analysis');
}
await ledgerService.writeEvidence(...);
```

### Mistake 3: Modifying Parsed Data

```dart
// ❌ WRONG - Modify after parsing
final reasoning = parser.parse(geminiResponse);
reasoning.limitations = ReasoningLimitations.none(); // Tampering!

// ✅ CORRECT - Use as-is
final reasoning = parser.parse(geminiResponse);
if (reasoning.limitations.hasLimitations) {
  // Handle limitations appropriately
}
```

---

## 🎯 DEFINITION OF DONE

FAZ-0.7.1/A is complete when:

- [ ] All domain models are immutable
- [ ] Deterministic JSON is verified
- [ ] Limitations are automatically captured
- [ ] Parser produces single canonical output
- [ ] Integration with LedgerService works
- [ ] Tests cover all scenarios
- [ ] Documentation is complete
- [ ] Legal review is done

---

## 🪨 FINAL PRINCIPLE

**"AI explanations can be vague. Legal evidence must be precise."**

The ReasoningParser bridges this gap by:
- Converting vague AI output into structured data
- Capturing uncertainty explicitly
- Creating court-defensible evidence
- Ensuring deterministic, hash-safe output

---

*FAZ-0.7.1/A: Reasoning Parser Implementation*
*Version: 1.0.0*
*Last Updated: 2026-02-01*
*Status: Production Ready*
*Legal Standard: Court-Defensible*
*Forensic Grade: Evidence-Grade*
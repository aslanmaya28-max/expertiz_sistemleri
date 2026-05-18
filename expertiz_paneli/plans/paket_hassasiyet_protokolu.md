# Paket Hassasiyet Protokolü - Implementation Plan

## Overview
This protocol enhances YerimeBak with intelligent package/equipment sensitivity and creates a new Customer AI Auto-Analysis center.

---

## Phase 1: Personnel Panel Enhancement (adim1_sayfasi.dart)

### 1.1 Add Dynamic Package/Equipment Level Selection
**Location**: After model selection in `lib/screens/expertiz_akisi/adim1_sayfasi.dart`

**Features**:
- Dropdown for package level selection
- Options: "Standart", "Premium", "Spor", "Lüks"
- Auto-detect sport packages from model name (AMG, M, RS, R-Line, etc.)
- Visual indicator for detected sport packages

**UI Design**:
- Glassmorphism card with cyber theme
- Neon turquoise accent for selected option
- Animated dropdown with glow effects

### 1.2 Sport Package Detection Logic
```dart
bool _isSportPackage(String? modelName) {
  final sportKeywords = ['AMG', 'M', 'RS', 'R-Line', 'ST', 'GTI', 'Cupra'];
  return sportKeywords.any((keyword) => 
    modelName?.toUpperCase().contains(keyword) ?? false
  );
}

String? _detectPackageLevel(String? modelName) {
  if (_isSportPackage(modelName)) return 'Spor';
  // Add more detection logic
  return 'Standart';
}
```

---

## Phase 2: MarketRadarService Enhancement

### 2.1 Add Sport Package Multiplier
**Location**: `lib/services/market_radar_service.dart`

**New Method**:
```dart
static double _getSportPackageMultiplier(String? packageLevel) {
  switch (packageLevel?.toLowerCase()) {
    case 'spor':
      return 1.20; // 20% premium
    case 'lüks':
      return 1.15; // 15% premium
    case 'premium':
      return 1.10; // 10% premium
    default:
      return 1.0;
  }
}
```

### 2.2 New calculateIntegratedValue Algorithm
**Purpose**: Harmonize package selection + optional equipment + market data

**Algorithm**:
1. Get base market value from MarketRadarService
2. Apply sport package multiplier (if applicable)
3. Add value for selected equipment options
4. Apply condition adjustments (KM, paint, damage)
5. Apply market trend adjustments (Sahibinden/Noter data)
6. Return final integrated value

**Method Signature**:
```dart
static Map<String, dynamic> calculateIntegratedValue({
  required String brand,
  required String model,
  required int year,
  required int km,
  required String color,
  required String packageLevel,
  required Map<String, bool> selectedOptions,
  required List<String> paintedParts,
  required List<String> damagedParts,
  String? marketSource, // 'sahibinden' or 'noter'
})
```

### 2.3 Package/Equipment Conflict Detection
**Logic**:
- If packageLevel == 'Standart' OR 'Boş'
- AND selectedOptions has premium equipment count > 3
- Add warning: "Sonradan Eklenen Donanımlar Değeri Artırıyor"

---

## Phase 3: Customer AI Auto-Analysis Module (oto_analiz_merkezi.dart)

### 3.1 Create New File
**Location**: `lib/screens/musteri/oto_analiz_merkezi.dart`

### 3.2 Smart Form Hierarchy
**Step 1**: Marka (Brand) Selection
- Cyber-themed dropdown with popular brands
- Search functionality
- Brand logos with neon glow

**Step 2**: Model Selection
- Dynamic based on selected brand
- Auto-detect package level
- Show package badge (e.g., "AMG Line detected")

**Step 3**: Package Level Selection
- Standart / Premium / Spor / Lüks
- Visual explanation of each level
- Impact on value shown in real-time

**Step 4**: Technical Details
- KM input with slider
- Paint/Changed parts (multi-select)
- Damage level (slider: 0-100%)

**Step 5**: Equipment Selection
- All 21 options from PremiumDonanimlarWidget
- Grouped by category
- Real-time value impact shown

### 3.3 Payment Wall
**Design**:
- Cyber-themed blur overlay
- Neon turquoise "Analizi Kilidini Aç" button
- Price: 500 TL
- Animated unlock effect on payment
- Preview of what will be unlocked:
  - Full AI analysis
  - Market radar integration
  - Detailed value report
  - Equipment valuation

### 3.4 Cyber Theme Integration
- Use CyberBackground
- Glassmorphism cards for all sections
- Neon gradients for buttons
- Animated transitions between steps
- Progress indicator with neon glow

---

## Phase 4: Report Visualization Enhancement

### 4.1 Neon Vehicle Identity Header
**Location**: Update all report screens

**Design**:
```
┌─────────────────────────────────────────┐
│  2021 Mercedes-Benz C200d - AMG Line  │
│  ─────────────────────────────────────  │
│  Plaka: 34 ABC 123  │
│  KM: 45.000  │
└─────────────────────────────────────────┘
```

**Features**:
- Neon turquoise title with glow
- Gradient background
- Animated reveal on load
- Package badge with sport multiplier indicator

### 4.2 Package/Equipment Conflict Warning
**UI**:
- Warning card with neon magenta border
- Icon: Icons.warning
- Text: "Sonradan Eklenen Donanımlar Değeri Artırıyor"
- Explanation of impact

---

## Phase 5: Integration & Testing

### 5.1 Update Routes
**Location**: `lib/routes/app_router.dart`

**Add Route**:
```dart
static const String otoAnalizMerkezi = '/oto_analiz_merkezi';
```

### 5.2 Update Customer Home
**Location**: `lib/screens/musteri_ana_sayfa.dart`

**Add Button**:
- "AI Oto-Analiz Başlat" with neon button
- Navigate to oto_analiz_merkezi

### 5.3 Testing Checklist
- [ ] Sport package detection works correctly
- [ ] Package multiplier applies correctly
- [ ] calculateIntegratedValue returns accurate results
- [ ] Package/Equipment conflict detection works
- [ ] Customer AI form flows smoothly
- [ ] Payment wall unlocks correctly
- [ ] Report visualization shows neon identity header
- [ ] Flutter analyze: 0 issues

---

## Implementation Order

1. **Update MarketRadarService** (Phase 2)
   - Add sportPackageMultiplier
   - Add calculateIntegratedValue
   - Add conflict detection

2. **Update adim1_sayfasi.dart** (Phase 1)
   - Add package level selection
   - Add sport package detection

3. **Create oto_analiz_merkezi.dart** (Phase 3)
   - Build smart form hierarchy
   - Implement payment wall
   - Apply cyber theme

4. **Update Report Screens** (Phase 4)
   - Add neon vehicle identity header
   - Add conflict warning UI

5. **Update Routes & Navigation** (Phase 5)
   - Add new route
   - Update customer home

6. **Testing & Verification** (Phase 5)
   - Run flutter analyze
   - Test all flows
   - Verify calculations

---

## Success Criteria

✅ Flutter analyze: 0 issues
✅ Sport packages auto-detected with 15-20% multiplier
✅ calculateIntegratedValue harmonizes all data sources
✅ Package/Equipment conflicts detected and warned
✅ Customer AI form with cyber theme created
✅ Payment wall with 500 TL unlock works
✅ Reports show neon vehicle identity headers
✅ All animations smooth and performant

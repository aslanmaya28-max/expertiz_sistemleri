"""
Vision Engine - Image Analysis Service (Faz-1: Stateless)
Uses Gemini 1.5 Flash multimodal capabilities for expert vehicle inspection
"""

import os
import base64
import logging
import asyncio
from typing import List, Dict, Any, Optional, Tuple
from langchain_google_genai import ChatGoogleGenerativeAI
from pydantic import SecretStr
from .models import VisualFinding, ImageAnalysis, FindingType

logger = logging.getLogger(__name__)


class ImageAnalysisService:
    """
    Faz-1 Stateless Image Analysis Service
    
    Uses Gemini 1.5 Flash Vision API for:
    - Paint color difference detection
    - Part replacement suspicion
    - Panel alignment issues
    - Surface damage/scratches
    
    CONFIDENCE RULE:
    - guven_skoru >= 0.6: Include in price calculation
    - guven_skoru < 0.6: Add as manual inspection note (no price impact)
    """
    
    # Confidence threshold for price calculation
    CONFIDENCE_THRESHOLD = 0.6
    
    def __init__(self):
        # Initialize Gemini Vision API
        self.gemini_key = os.getenv("GOOGLE_API_KEY")
        self.gemini_vision = None
        
        if self.gemini_key:
            try:
                self.gemini_vision = ChatGoogleGenerativeAI(
                    model="gemini-1.5-flash",
                    google_api_key=SecretStr(self.gemini_key),
                    temperature=0.3  # Lower temp for visual analysis
                )
                logger.info("✅ Gemini Vision API initialized (Faz-1 Stateless)")
            except Exception as e:
                logger.warning(f"⚠️ Gemini Vision initialization failed: {e}")
        else:
            logger.warning("⚠️ GOOGLE_API_KEY not found - Image analysis disabled")
    
    async def analyze_images(
        self,
        images: List[str],
        max_images: int = 5
    ) -> ImageAnalysis:
        """
        Analyze vehicle images using Gemini 1.5 Flash Vision
        
        Args:
            images: List of image URLs or base64 strings
            max_images: Maximum number of images to analyze (default: 5)
        
        Returns:
            ImageAnalysis with detailed visual findings
        """
        
        if not self.gemini_vision:
            logger.warning("❌ Gemini Vision not available - returning empty analysis")
            return ImageAnalysis(
                visual_findings=[],
                quality_score=0.0,
                overall_confidence=0.0,
                total_images_analyzed=0,
                notes=["AI görüntü analizi servisi mevcut değil"]
            )
        
        if not images or len(images) == 0:
            logger.warning("⚠️ No images provided for analysis")
            return ImageAnalysis(
                visual_findings=[],
                quality_score=0.0,
                overall_confidence=0.0,
                total_images_analyzed=0,
                notes=["Görüntü sağlanmadı"]
            )
        
        # Limit number of images
        images_to_analyze = images[:max_images]
        logger.info(f"📸 Analyzing {len(images_to_analyze)} images (max: {max_images})")
        
        try:
            # Build multimodal prompt with images
            prompt = self._build_vision_prompt()
            
            # Prepare content with images
            content = [{"type": "text", "text": prompt}]
            
            for img in images_to_analyze:
                if self._is_base64(img):
                    content.append({
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{img}"}
                    })
                else:
                    content.append({
                        "type": "image_url",
                        "image_url": {"url": img}
                    })
            
            # Invoke Gemini Vision
            response = await self.gemini_vision.ainvoke(content)
            response_text = response.content
            
            # Parse response
            findings, notes = self._parse_vision_response(response_text)
            
            # Apply confidence threshold
            high_confidence_findings = []
            manual_inspection_notes = list(notes)
            
            for finding in findings:
                if finding.guven_skoru >= self.CONFIDENCE_THRESHOLD:
                    high_confidence_findings.append(finding)
                else:
                    # Convert to manual inspection note
                    manual_inspection_notes.append(
                        f"{finding.parca_adi}: Şüpheli alan, manuel kontrol önerilir (Güven: %{finding.guven_skoru*100:.0f})"
                    )
            
            # Calculate overall confidence
            overall_confidence = self._calculate_overall_confidence(findings)
            
            # Calculate quality score
            quality_score = self._calculate_quality_score(findings)
            
            result = ImageAnalysis(
                visual_findings=high_confidence_findings,
                quality_score=quality_score,
                overall_confidence=overall_confidence,
                total_images_analyzed=len(images_to_analyze),
                notes=manual_inspection_notes
            )
            
            logger.info(f"✅ Image analysis complete: {len(high_confidence_findings)} findings, {overall_confidence:.2f} confidence")
            return result
            
        except Exception as e:
            logger.error(f"❌ Image analysis failed: {e}", exc_info=True)
            return ImageAnalysis(
                visual_findings=[],
                quality_score=0.0,
                overall_confidence=0.0,
                total_images_analyzed=len(images_to_analyze),
                notes=[f"Görüntü analizi başarısız: {str(e)}"]
            )
    
    def _build_vision_prompt(self) -> str:
        """
        Build STRICT vision analysis prompt for Gemini
        
        Gemini 1.5 Flash will analyze vehicle images and detect:
        - Paint color differences (boya tonu farkı)
        - Part replacement suspicions (değişen parça)
        - Panel alignment issues (hizasızlık)
        - Surface damage/scratches (hasar/çizik)
        """
        
        return """
You are an EXPERT AUTOMOTIVE INSPECTOR with 20+ years of experience.

TASK: Analyze the provided vehicle images and identify visual defects.

ANALYSIS RULES:
1. Focus on: Paint difference, replaced parts, panel alignment, damage/scratches
2. Specify exact part name in Turkish (e.g., "Sol ön çamurluk", "Sağ kapı", "Kaput")
3. Assign confidence score (0.0 - 1.0) based on visual clarity
4. Be conservative - if uncertain, give lower confidence score

FINDING TYPES:
- boya: Paint color difference (ton farkı)
- degisen: Part replacement suspicion (şekil bozukluğu, montaj izi)
- hizaliklik: Panel alignment issue (kapı, kaput, bagaj hizası)
- hasar: Surface damage, scratch, dent (yüzey hasarı, çizik, göçük)

OUTPUT FORMAT (Strict JSON):
```json
{
  "findings": [
    {
      "parca_adi": "Sol ön çamurluk",
      "bulgu_tipi": "boya",
      "guven_skoru": 0.85
    },
    {
      "parca_adi": "Kaput",
      "bulgu_tipi": "hizaliklik",
      "guven_skoru": 0.72
    }
  ],
  "notes": [
    "Arka tampon göçük var",
    "Sol far montajında düzensizlik tespit edildi"
  ]
}
```

CONFIDENCE GUIDELINES:
- 0.9-1.0: Crystal clear, obvious defect
- 0.7-0.9: Highly likely, good visual evidence
- 0.6-0.7: Moderate confidence, some ambiguity
- 0.4-0.6: Low confidence, possible but uncertain → Will trigger manual inspection
- 0.0-0.4: Very uncertain, poor image quality → Will trigger manual inspection

IMPORTANT:
- Only report findings you are reasonably confident about
- Don't hallucinate defects that aren't visible
- If image quality is poor, reduce confidence scores
- Be thorough but conservative

Now analyze the images and provide JSON output.
"""
    
    def _parse_vision_response(self, response: str) -> Tuple[List[VisualFinding], List[str]]:
        """Parse Gemini Vision response into VisualFinding objects"""
        
        import json
        import re
        
        findings = []
        notes = []
        
        try:
            # Extract JSON from response
            json_match = re.search(r'```json\s*(.*?)\s*```', response, re.DOTALL)
            if json_match:
                json_str = json_match.group(1)
            else:
                # Try to find JSON without code blocks
                json_match = re.search(r'\{.*\}', response, re.DOTALL)
                if json_match:
                    json_str = json_match.group(0)
                else:
                    logger.warning("⚠️ No JSON found in vision response")
                    return findings, ["AI yanıt ayrıştırılamadı"]
            
            data = json.loads(json_str)
            
            # Parse findings
            for item in data.get("findings", []):
                try:
                    finding_type_str = item.get("bulgu_tipi", "").lower()
                    
                    # Map to FindingType enum
                    finding_type_map = {
                        "boya": FindingType.BOYA,
                        "degisen": FindingType.DEGISEN,
                        "hizaliklik": FindingType.HIZALIKLIK,
                        "hasar": FindingType.HASAR
                    }
                    
                    finding_type = finding_type_map.get(finding_type_str, FindingType.HASAR)
                    
                    finding = VisualFinding(
                        parca_adi=item.get("parca_adi", "Bilinmeyen parça"),
                        bulgu_tipi=finding_type,
                        guven_skoru=float(item.get("guven_skoru", 0.5))
                    )
                    
                    findings.append(finding)
                    
                except Exception as e:
                    logger.warning(f"⚠️ Failed to parse finding: {e}")
            
            # Parse notes
            notes = data.get("notes", [])
            
        except json.JSONDecodeError as e:
            logger.error(f"❌ JSON decode error: {e}")
            notes.append(f"AI yanıt ayrıştırılamadı: {str(e)}")
        except Exception as e:
            logger.error(f"❌ Parse error: {e}")
            notes.append(f"Görüntü analizi hatası: {str(e)}")
        
        return findings, notes
    
    def _calculate_overall_confidence(self, findings: List[VisualFinding]) -> float:
        """Calculate overall confidence across all findings"""
        if not findings:
            return 0.0
        
        # Average confidence weighted by finding type severity
        severity_weights = {
            FindingType.BOYA: 1.0,
            FindingType.DEGISEN: 1.2,
            FindingType.HIZALIKLIK: 0.8,
            FindingType.HASAR: 1.0
        }
        
        total_weight = 0.0
        weighted_confidence = 0.0
        
        for finding in findings:
            weight = severity_weights.get(finding.bulgu_tipi, 1.0)
            weighted_confidence += finding.guven_skoru * weight
            total_weight += weight
        
        return weighted_confidence / total_weight if total_weight > 0 else 0.0
    
    def _calculate_quality_score(self, findings: List[VisualFinding]) -> float:
        """
        Calculate overall vehicle quality score (0-100)
        
        Score = 100 - (sum of penalty factors)
        - Boya: -5 points
        - Değişen: -10 points
        - Hizasızlık: -7 points
        - Hasar: -8 points
        """
        
        if not findings:
            return 100.0
        
        penalties = {
            FindingType.BOYA: 5,
            FindingType.DEGISEN: 10,
            FindingType.HIZALIKLIK: 7,
            FindingType.HASAR: 8
        }
        
        total_penalty = 0.0
        
        for finding in findings:
            base_penalty = penalties.get(finding.bulgu_tipi, 5)
            # Apply confidence multiplier
            adjusted_penalty = base_penalty * finding.guven_skoru
            total_penalty += adjusted_penalty
        
        score = max(0.0, 100.0 - total_penalty)
        return score
    
    def _is_base64(self, image: str) -> bool:
        """Check if image string is base64 encoded"""
        # Simple heuristic: base64 strings are long and don't contain spaces
        if len(image) > 100 and ' ' not in image and '\n' not in image:
            try:
                base64.b64decode(image, validate=True)
                return True
            except:
                pass
        return False
    
    def get_paint_adjustment_factor(self, painted_parts: List[str]) -> float:
        """
        Calculate price adjustment factor for painted parts
        
        Boya: -3% per painted part (max -15%)
        """
        if not painted_parts:
            return 1.0
        
        # Use visual findings instead of legacy list
        # This is for backward compatibility
        count = len(painted_parts)
        penalty = min(count * 0.03, 0.15)  # Max 15% penalty
        return 1.0 - penalty
    
    def get_damage_adjustment_factor(self, damaged_parts: List[str]) -> float:
        """
        Calculate price adjustment factor for damaged parts
        
        Değişen: -7%, Hizasızlık: -4%, Hasar: -6%
        """
        if not damaged_parts:
            return 1.0
        
        # This is legacy - actual calculation now in core_engine
        # using visual findings with types
        return 1.0


class FactorMatching:
    """
    Match visual findings to adjustment factors
    
    CONFIDENCE RULE: Only apply adjustments if guven_skoru >= 0.6
    """
    
    # Adjustment factors for each finding type
    ADJUSTMENT_FACTORS = {
        FindingType.BOYA: -0.03,      # -3%
        FindingType.DEGISEN: -0.07,   # -7%
        FindingType.HIZALIKLIK: -0.04, # -4%
        FindingType.HASAR: -0.06      # -6%
    }
    
    def calculate_adjustment_factor(
        self,
        findings: List[VisualFinding],
        confidence_threshold: float = 0.6
    ) -> float:
        """
        Calculate total adjustment factor from visual findings
        
        Only applies adjustments for findings with guven_skoru >= threshold
        
        Returns: Multiplier (e.g., 0.85 for -15% total adjustment)
        """
        
        if not findings:
            return 1.0
        
        total_adjustment = 0.0
        
        for finding in findings:
            # Skip low confidence findings
            if finding.guven_skoru < confidence_threshold:
                continue
            
            # Get adjustment factor
            factor = self.ADJUSTMENT_FACTORS.get(finding.bulgu_tipi, 0.0)
            
            # Weight by confidence
            weighted_factor = factor * finding.guven_skoru
            
            total_adjustment += weighted_factor
        
        # Apply minimum and maximum bounds
        # Max penalty: -30% (very damaged vehicle)
        # Max bonus: 0% (no findings)
        total_adjustment = max(total_adjustment, -0.30)
        
        return 1.0 + total_adjustment
"""
Vision Engine - Expertiz AI Service (Multi-Engine Architecture)
Primary: Gemini 1.5 Flash | Secondary: GLM-4.7 | Fallback: Static
"""

import os
import logging
from typing import List, Dict, Any, Tuple
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.chat_models import ChatZhipuAI
from pydantic import SecretStr
from .models import CoreMetrics, AICommentary, AnalysisRequest

logger = logging.getLogger(__name__)


class ExpertizAIService:
    """
    Multi-Engine AI Commentary Service
    
    PRIMARY ENGINE: Gemini 1.5 Flash (Fast, professional)
    SECONDARY ENGINE: GLM-4.7 (Deep analytic, fallback)
    FALLBACK: Static deterministic commentary
    
    ALL ENGINES: Only interpret Python metrics, NEVER generate prices
    """
    
    # Critical threshold for GLM-4.7 trigger
    LIQUIDITY_CRITICAL_THRESHOLD = 0.3
    
    def __init__(self):
        # Initialize Primary Engine (Gemini 1.5 Flash)
        self.gemini_key = os.getenv("GOOGLE_API_KEY")
        self.gemini_llm = None
        
        if self.gemini_key:
            try:
                self.gemini_llm = ChatGoogleGenerativeAI(
                    model="gemini-1.5-flash",
                    google_api_key=SecretStr(self.gemini_key),
                    temperature=0.7
                )
                logger.info("✅ Gemini 1.5 Flash initialized")
            except Exception as e:
                logger.warning(f"⚠️ Gemini initialization failed: {e}")
        else:
            logger.warning("⚠️ GOOGLE_API_KEY not found")
        
        # Initialize Secondary Engine (GLM-4.7)
        self.glm_key = os.getenv("GLM_API_KEY")
        self.glm_llm = None
        
        if self.glm_key:
            try:
                self.glm_llm = ChatZhipuAI(
                    model="glm-4",
                    zhipuai_api_key=SecretStr(self.glm_key),
                    temperature=0.5  # Lower temp for analytic precision
                )
                logger.info("✅ GLM-4.7 initialized")
            except Exception as e:
                logger.warning(f"⚠️ GLM-4.7 initialization failed: {e}")
        else:
            logger.warning("⚠️ GLM_API_KEY not found")
    
    async def generate_commentary(
        self,
        request: AnalysisRequest,
        metrics: CoreMetrics,
        adjustments: Dict[str, float] = None
    ) -> Tuple[AICommentary, str]:
        """
        Generate AI commentary with automatic engine selection
        
        Returns:
            (AICommentary, engine_used)
            engine_used: "gemini" | "glm" | "static_fallback"
        """
        
        logger.info("🤖 ExpertizAIService: Starting commentary generation")
        
        # Prepare context (same for all engines)
        context = self._prepare_analysis_context(request, metrics, adjustments)
        
        # Try Primary Engine (Gemini)
        if self.gemini_llm:
            try:
                logger.info("🎯 Attempting Primary Engine: Gemini 1.5 Flash")
                commentary = await self._generate_with_gemini(context)
                if self._validate_commentary(commentary, context):
                    logger.info("✅ Gemini commentary generated successfully")
                    return commentary, "gemini"
                else:
                    logger.warning("⚠️ Gemini output validation failed")
            except Exception as e:
                logger.error(f"❌ Gemini generation failed: {e}")
        
        # Try Secondary Engine (GLM-4.7) if Gemini failed
        # OR if liquidity_index is critical
        should_use_glm = (
            self.glm_llm and (
                not self.gemini_llm or
                self._is_liquidity_critical(metrics)
            )
        )
        
        if should_use_glm:
            try:
                logger.info("🎯 Attempting Secondary Engine: GLM-4.7")
                commentary = await self._generate_with_glm(context)
                if self._validate_commentary(commentary, context):
                    logger.info("✅ GLM-4.7 commentary generated successfully")
                    return commentary, "glm"
                else:
                    logger.warning("⚠️ GLM output validation failed")
            except Exception as e:
                logger.error(f"❌ GLM generation failed: {e}")
        
        # Final Fallback: Static Deterministic Commentary
        logger.warning("🛡️ All AI engines failed - using static fallback")
        commentary = self._static_fallback_commentary(request, metrics, context)
        return commentary, "static_fallback"
    
    async def _generate_with_gemini(self, context: Dict[str, Any]) -> AICommentary:
        """Generate commentary using Gemini 1.5 Flash"""
        
        prompt = self._build_strict_prompt(context, engine_name="Gemini 1.5 Flash")
        response = await self.gemini_llm.ainvoke(prompt)
        commentary_text = response.content
        
        return self._parse_ai_response(commentary_text, context)
    
    async def _generate_with_glm(self, context: Dict[str, Any]) -> AICommentary:
        """Generate commentary using GLM-4.7"""
        
        prompt = self._build_strict_prompt(context, engine_name="GLM-4.7")
        response = await self.glm_llm.ainvoke(prompt)
        commentary_text = response.content
        
        return self._parse_ai_response(commentary_text, context)
    
    def _build_strict_prompt(self, context: Dict[str, Any], engine_name: str) -> str:
        """
        Build STRICT prompt for AI engines
        
        CRITICAL: Both engines must interpret ONLY provided metrics
        NO price generation, NO external data inference
        """
        
        return f"""
You are an AUTOMOTIVE EXPERT ANALYST using {engine_name}.

STRICT OPERATIONAL RULES:
1. Only interpret the CoreMetrics data provided by Python
2. Do NOT generate prices
3. Do NOT modify numbers
4. Do NOT infer external market data
5. Do NOT hallucinate
6. Your role: INTERPRETER, not creator

📊 VEHICLE INFORMATION:
- Brand/Model: {context['vehicle']['brand']} {context['vehicle']['model']}
- Year: {context['vehicle']['year']}
- Kilometer: {context['vehicle']['km']:,} km
- Fuel: {context['vehicle']['fuel']}
- Transmission: {context['vehicle']['transmission']}

📈 MARKET DATA (Python Core Engine - Immutable):
- Average Price: {context['market']['avg_price']}
- Median Price: {context['market']['median_price']}
- Price Range: {context['market']['price_range']}
- Sample Size: {context['market']['sample_size']} listings
- Confidence Score: {context['market']['confidence']}
- Market Status: {context['market']['position']}
- Volatility: {context['market']['volatility']}

TASK: Translate these metrics into professional expert language.

REQUIRED OUTPUT FORMAT:

OVERALL ASSESSMENT:
[2-3 sentences assessing vehicle condition based on metrics]

KEY FINDINGS:
- [Technical finding 1 from metrics]
- [Technical finding 2 from metrics]
- [Technical finding 3 from metrics]

MARKET POSITION:
[Market position based on provided data]

RECOMMENDATIONS:
- [Actionable recommendation 1]
- [Actionable recommendation 2]

CONFIDENCE LEVEL:
[High/Medium/Low based on confidence_score]

REMEMBER: You are interpreting Python metrics, not creating new data.
"""
    
    def _validate_commentary(self, commentary: AICommentary, context: Dict[str, Any]) -> bool:
        """
        Validate AI commentary output
        
        Checks:
        - All required fields present
- Overall assessment not empty
- Key findings present
- Market position not empty
- Recommendations present
- Confidence level valid
        """
        
        if not commentary:
            return False
        
        if not commentary.overall_assessment or len(commentary.overall_assessment) < 10:
            return False
        
        if not commentary.key_findings or len(commentary.key_findings) == 0:
            return False
        
        if not commentary.market_position or len(commentary.market_position) < 5:
            return False
        
        if not commentary.recommendations or len(commentary.recommendations) == 0:
            return False
        
        if commentary.confidence_level not in ["Yüksek", "Orta", "Düşük", "High", "Medium", "Low"]:
            return False
        
        logger.info("✅ Commentary validation passed")
        return True
    
    def _is_liquidity_critical(self, metrics: CoreMetrics) -> bool:
        """
        Check if liquidity index is critical
        
        Note: This is a placeholder. The actual liquidity_index
        would need to be added to CoreMetrics in a future update.
        For now, we use volatility_index as a proxy.
        """
        # Using volatility as proxy for liquidity concern
        return metrics.volatility_index > self.LIQUIDITY_CRITICAL_THRESHOLD
    
    def _static_fallback_commentary(
        self,
        request: AnalysisRequest,
        metrics: CoreMetrics,
        context: Dict[str, Any]
    ) -> AICommentary:
        """
        STATIC FALLBACK COMMENTARY (Deterministic, No AI)
        
        Uses NO AI - generates professional text directly from metrics
        Guaranteed to never return empty commentary
        """
        
        logger.info("🛡️ Generating static fallback commentary")
        
        # Build key findings directly from metrics
        findings = [
            f"Python Core Engine analizi: {metrics.sample_size} benzer ilan tarandı",
            f"Ortalama piyasa fiyatı: {metrics.avg_price:,.0f} TL",
            f"Fiyat aralığı: {metrics.min_price:,.0f} - {metrics.max_price:,.0f} TL"
        ]
        
        # Add volatility finding
        if metrics.volatility_index > 0.10:
            findings.append(f"Piyasada yüksek fiyat volatilitesi mevcut (%{metrics.volatility_index*100:.1f})")
        elif metrics.volatility_index > 0.05:
            findings.append(f"Normal piyasa volatilitesi (%{metrics.volatility_index*100:.1f})")
        else:
            findings.append("Düşük volatilite - fiyatlar stabil")
        
        # Add confidence finding
        if metrics.confidence_score >= 80:
            findings.append("Yüksek güvenilirlikte piyasa verisi")
        elif metrics.confidence_score >= 60:
            findings.append("Orta güvenilirlikte piyasa verisi")
        else:
            findings.append("Düşük güvenilirlikte piyasa verisi - dikkatli olunması önerilir")
        
        # Build recommendations
        recommendations = ["Uzman fiziksel muayenesi önerilir"]
        
        if request.km > 100000:
            recommendations.append("Yüksek kilometre - motor ve şanzıman detaylı kontrolü gerekli")
        
        if metrics.volatility_index > 0.10:
            recommendations.append("Geniş fiyat aralığı - birden fazla kaynakla karşılaştırma yapılması önerilir")
        
        if metrics.confidence_score < 60:
            recommendations.append("Sınırlı piyasa verisi - profesyonel ekspertiz hizmeti önerilir")
        
        # Determine overall assessment
        if metrics.confidence_score >= 80 and metrics.volatility_index <= 0.05:
            overall = f"{request.brand} {request.model} ({request.year}) için güvenilir piyasa analizi. {metrics.sample_size} benzer araç incelendi, fiyatlar stabil aralıkta."
        elif metrics.confidence_score >= 60:
            overall = f"{request.brand} {request.model} ({request.year}) için piyasa analizi tamamlandı. {metrics.sample_size} benzer araç temelinde değerlendirme yapıldı."
        else:
            overall = f"{request.brand} {request.model} ({request.year}) için sınırlı piyasa verisi mevcut. {metrics.sample_size} benzer araç incelendi, profesyonel ekspertiz önerilir."
        
        # Determine confidence level
        if metrics.confidence_score >= 80:
            confidence = "Yüksek"
        elif metrics.confidence_score >= 60:
            confidence = "Orta"
        else:
            confidence = "Düşük"
        
        return AICommentary(
            overall_assessment=overall,
            key_findings=findings,
            market_position=f"Piyasa ortalaması: {metrics.avg_price:,.0f} TL (Aralık: {metrics.min_price:,.0f} - {metrics.max_price:,.0f} TL)",
            recommendations=recommendations,
            confidence_level=confidence
        )
    
    def _prepare_analysis_context(
        self,
        request: AnalysisRequest,
        metrics: CoreMetrics,
        adjustments: Dict[str, float] = None
    ) -> Dict[str, Any]:
        """Prepare structured context for AI analysis"""
        
        # Market position
        if metrics.confidence_score >= 80:
            position = "Yüksek güvenilirlikte piyasa verisi"
        elif metrics.confidence_score >= 60:
            position = "Orta güvenilirlikte piyasa verisi"
        else:
            position = "Düşük güvenilirlikte piyasa verisi"
        
        # Volatility assessment
        if metrics.volatility_index <= 0.05:
            volatility = "Düşük volatilite - Fiyatlar stabil"
        elif metrics.volatility_index <= 0.10:
            volatility = "Orta volatilite - Normal fiyat aralığı"
        else:
            volatility = "Yüksek volatilite - Geniş fiyat aralığı"
        
        return {
            "vehicle": {
                "brand": request.brand,
                "model": request.model,
                "year": request.year,
                "km": request.km,
                "fuel": request.fuel_type,
                "transmission": request.transmission
            },
            "market": {
                "avg_price": f"{metrics.avg_price:,.0f} TL",
                "median_price": f"{metrics.median_price:,.0f} TL",
                "price_range": f"{metrics.min_price:,.0f} - {metrics.max_price:,.0f} TL",
                "sample_size": metrics.sample_size,
                "confidence": f"%{metrics.confidence_score:.1f}",
                "volatility": volatility,
                "position": position
            },
            "adjustments": adjustments or {}
        }
    
    def _parse_ai_response(self, response: str, context: Dict[str, Any]) -> AICommentary:
        """Parse AI response into structured model"""
        
        # Split response into sections
        lines = response.split('\n')
        
        overall = ""
        findings = []
        market_pos = ""
        recommendations = []
        confidence = "Orta"
        
        current_section = None
        
        for line in lines:
            line = line.strip()
            
            if "OVERALL ASSESSMENT" in line.upper() or "GENEL DEĞERLENDİRME" in line.upper():
                current_section = "overall"
            elif "KEY FINDINGS" in line.upper() or "ANAHTAR BULGULAR" in line.upper():
                current_section = "findings"
            elif "MARKET POSITION" in line.upper() or "PİYASA POZİSYONU" in line.upper():
                current_section = "market"
            elif "RECOMMENDATIONS" in line.upper() or "ÖNERİLER" in line.upper():
                current_section = "recommendations"
            elif "CONFIDENCE LEVEL" in line.upper() or "GÜVEN DÜZEYİ" in line.upper():
                current_section = "confidence"
            elif line and not line.startswith('-') and not line.startswith('•'):
                if current_section == "overall":
                    overall += line + " "
                elif current_section == "market":
                    market_pos += line + " "
                elif current_section == "confidence":
                    confidence = line
            elif line.startswith('-') or line.startswith('•'):
                content = line.lstrip('-•').strip()
                if current_section == "findings":
                    findings.append(content)
                elif current_section == "recommendations":
                    recommendations.append(content)
        
        return AICommentary(
            overall_assessment=overall.strip() or "Araç piyasa standartlarında değerlendirilmektedir.",
            key_findings=findings or ["Piyasa verilerine göre fiyat aralığı normal"],
            market_position=market_pos.strip() or context['market']['position'],
            recommendations=recommendations or ["Uzman incelemesi önerilir"],
            confidence_level=confidence
        )
    
    def generate_final_recommendation(
        self,
        metrics: CoreMetrics,
        commentary: AICommentary,
        asking_price: float = None
    ) -> str:
        """
        Generate final buy/sell recommendation
        Compares asking price with fair value
        """
        
        fair_value = metrics.avg_price
        lower_bound = metrics.iqr_lower_bound
        upper_bound = metrics.iqr_upper_bound
        
        if not asking_price:
            return f"PIYASA DEĞERİ: {fair_value:,.0f} TL (Aralık: {lower_bound:,.0f} - {upper_bound:,.0f} TL)"
        
        # Calculate ratio
        ratio = asking_price / fair_value
        
        if ratio <= 0.90:
            return f"🟢 FIRSAT FİYATI - Piyasa değerinin %{100 - ratio*100:.0f} altında. Şiddetle önerilir."
        elif ratio <= 0.95:
            return f"🟢 İYİ FİYAT - Piyasa değerinin hafif altında. Alınabilir."
        elif ratio <= 1.05:
            return f"🟡 PIYASA FİYATI - Normal piyasa aralığında. Müzakere edilebilir."
        elif ratio <= 1.10:
            return f"🟠 YÜKSEK FİYAT - Piyasa değerinin %{ratio*100 - 100:.0f} üstünde. Dikkatli olun."
        else:
            return f"🔴 ÇOK YÜKSEK - Piyasa değerinin %{ratio*100 - 100:.0f} üstünde. Önerilmez."
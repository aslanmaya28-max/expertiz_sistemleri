# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v6.5 - AI Valuation Engine (FORENSIC-GRADE)
Enterprise-grade AI valuation using google-genai SDK
"""

import os
import json
import logging
import time
from typing import Dict, Any, List
from google import genai
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()


class AIValuationEngine:
    """Enterprise-grade AI valuation engine v6.5"""
    
    def __init__(self, model_name: str = "gemini-2.0-flash"):
        """Initialize AI valuation engine"""
        self.model_name = model_name
        self.api_key = os.getenv("GEMINI_API_KEY")
        
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not found in environment variables")
        
        # Create genai client
        self.client = genai.Client(api_key=self.api_key)
        
        # PATCH 2: Generation Config
        self.generation_config = {
            "temperature": 0.2,
            "top_p": 0.95,
            "top_k": 40,
            "max_output_tokens": 2048,
            "response_mime_type": "application/json"
        }
        
        # PATCH 3: Response Schema (Strict JSON)
        self.response_schema = {
            "type": "object",
            "properties": {
                "forensic_price": {"type": "number"},
                "confidence_score": {"type": "number"},
                "liquidity_score": {"type": "number"},
                "risk_score": {"type": "number"},
                "days_to_sell_estimate": {"type": "number"},
                "investment_rating": {"type": "string"},
                "summary": {"type": "string"},
                "outlier_analysis": {"type": "string"}
            },
            "required": [
                "forensic_price",
                "confidence_score",
                "liquidity_score",
                "risk_score",
                "days_to_sell_estimate",
                "investment_rating",
                "summary",
                "outlier_analysis"
            ]
        }
        
        logger.info(f"AI Valuation Engine v6.5 initialized with {model_name} (NEW SDK)")
    
    def evaluate_vehicle(self, vehicle: Dict[str, Any], 
                        market_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Perform forensic AI valuation (SYNCHRONOUS)
        
        Args:
            vehicle: Normalized vehicle data
            market_data: Cleaned market listings
        
        Returns:
            Forensic valuation with all metrics
        """
        try:
            # Prepare market context
            market_context = self._prepare_market_context(market_data)
            
            # Build prompt
            prompt = self._build_forensic_prompt(vehicle, market_context)
            
            # Generate valuation using new SDK with PATCH 4
            logger.info("Requesting AI valuation from Gemini v6.5...")
            response = self._generate_with_retry(prompt)
            
            # Parse response
            valuation = self._parse_ai_response(response)
            
            # PATCH 8: Add performance metrics
            valuation['performance'] = {
                "model": self.model_name,
                "sdk": "google-genai",
                "optimization": "flash" if "flash" in self.model_name else "pro"
            }
            
            # Add metadata
            valuation['metadata'] = {
                'model': self.model_name,
                'listings_used': len(market_data),
                'timestamp': self._get_timestamp(),
                'sdk_version': 'google-genai',
                'engine_version': 'v6.5'
            }
            
            logger.info(f"AI Valuation complete: {valuation['forensic_price']:,} TL")
            return valuation
            
        except Exception as e:
            logger.error(f"AI valuation failed: {e}")
            import traceback
            traceback.print_exc()
            # Fallback to rule-based valuation
            return self._fallback_valuation(vehicle, market_data)
    
    def _prepare_market_context(self, market_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Prepare market context for AI"""
        if not market_data:
            return {'count': 0, 'avg_price': 0}
        
        prices = [l['price'] for l in market_data if l.get('price')]
        kms = [l['km'] for l in market_data if l.get('km')]
        
        return {
            'count': len(market_data),
            'price_range': {
                'min': min(prices) if prices else 0,
                'max': max(prices) if prices else 0,
                'avg': sum(prices) / len(prices) if prices else 0
            },
            'km_stats': {
                'avg': sum(kms) / len(kms) if kms else 0,
                'median': sorted(kms)[len(kms)//2] if kms else 0
            }
        }
    
    def _build_forensic_prompt(self, vehicle: Dict[str, Any], 
                              market_context: Dict[str, Any]) -> str:
        """Build forensic valuation prompt"""
        
        prompt = f"""You are an expert vehicle forensic analyst. Analyze the following vehicle and market data to provide a comprehensive forensic valuation.

VEHICLE INFORMATION:
- Brand: {vehicle.get('brand', 'Unknown')}
- Model: {vehicle.get('model', 'Unknown')}
- Year: {vehicle.get('year', 2020)}
- KM: {vehicle.get('km', 0):,}
- Fuel: {vehicle.get('fuel', 'Unknown')}
- Transmission: {vehicle.get('transmission', 'Unknown')}

MARKET DATA:
- Total Listings: {market_context['count']}
- Price Range: {market_context['price_range']['min']:,} - {market_context['price_range']['max']:,} TL
- Average Price: {market_context['price_range']['avg']:,.0f} TL
- Average KM: {market_context['km_stats']['avg']:,.0f}

TASK:
Provide a forensic valuation analysis considering:
1. Market position relative to competitors
2. Price justification based on vehicle condition
3. Liquidity (how quickly it will sell)
4. Investment risk level
5. Days to sell estimate

CRITICAL: Return ONLY valid JSON. No markdown, no code blocks, no explanations outside JSON.

REQUIRED JSON SCHEMA:
{{
  "forensic_price": <estimated_fair_market_price_in_TL>,
  "confidence_score": <0-100_confidence_level>,
  "liquidity_score": <0-100_liquidity_rating>,
  "risk_score": <0-100_investment_risk>,
  "days_to_sell_estimate": <estimated_days_to_sell>,
  "investment_rating": <"BUY"/"HOLD"/"SELL">,
  "summary": "<brief_2-3_sentence_summary>",
  "outlier_analysis": "<analysis_of_any_market_outliers>"
}}

Return the JSON now:"""

        return prompt
    
    # PATCH 5: Exponential Backoff with Performance Metrics
    def _generate_with_retry(self, prompt: str, max_retries: int = 3) -> str:
        """Generate with exponential backoff and timing metrics"""
        wait_time = 2  # Initial wait time
        
        for attempt in range(max_retries):
            try:
                start = time.time()
                
                # PATCH 4: Updated generation call with config
                response = self.client.models.generate_content(
                    model=self.model_name,
                    contents=prompt,
                    config={
                        "temperature": 0.2,
                        "max_output_tokens": 2048,
                        "response_mime_type": "application/json",
                        "response_schema": self.response_schema
                    }
                )
                
                duration = time.time() - start
                logger.info(f"✅ AI response time: {duration:.2f}s (attempt {attempt + 1})")
                
                return response.text
                
            except Exception as e:
                logger.warning(f"⚠️ Attempt {attempt + 1}/{max_retries} failed: {e}")
                
                if attempt < max_retries - 1:
                    logger.info(f"⏳ Waiting {wait_time}s before retry...")
                    time.sleep(wait_time)
                    wait_time *= 2  # Exponential backoff
                else:
                    raise
        
        raise Exception("All retry attempts failed")
    
    def _parse_ai_response(self, response: str) -> Dict[str, Any]:
        """Parse AI response and validate JSON with PATCH 6 failsafe recovery"""
        try:
            # Remove markdown code blocks if present
            cleaned = response.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            cleaned = cleaned.strip()
            
            # PATCH 6: Failsafe JSON recovery
            cleaned = cleaned.replace("\n", " ")
            cleaned = cleaned.replace("\t", " ")
            cleaned = cleaned.strip()
            
            # Parse JSON
            valuation = json.loads(cleaned)
            
            # Validate required fields
            required_fields = [
                'forensic_price', 'confidence_score', 'liquidity_score',
                'risk_score', 'days_to_sell_estimate', 'investment_rating',
                'summary', 'outlier_analysis'
            ]
            
            for field in required_fields:
                if field not in valuation:
                    raise ValueError(f"Missing required field: {field}")
            
            # Validate ranges
            if not (0 <= valuation['confidence_score'] <= 100):
                raise ValueError("confidence_score must be 0-100")
            if not (0 <= valuation['liquidity_score'] <= 100):
                raise ValueError("liquidity_score must be 0-100")
            if not (0 <= valuation['risk_score'] <= 100):
                raise ValueError("risk_score must be 0-100")
            
            return valuation
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing failed: {e}")
            logger.error(f"Response: {response[:200]}")
            raise ValueError("Invalid JSON response from AI")
        except Exception as e:
            logger.error(f"Response validation failed: {e}")
            raise
    
    def _fallback_valuation(self, vehicle: Dict[str, Any], 
                           market_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Fallback to rule-based valuation if AI fails"""
        logger.warning("Using fallback rule-based valuation")
        
        if not market_data:
            return {
                'forensic_price': 500000,
                'confidence_score': 20.0,
                'liquidity_score': 50.0,
                'risk_score': 80.0,
                'days_to_sell_estimate': 60,
                'investment_rating': 'HOLD',
                'summary': 'Insufficient market data for accurate valuation',
                'outlier_analysis': 'No market data available',
                'performance': {'model': 'fallback', 'sdk': 'rule-based', 'optimization': 'none'},
                'metadata': {'model': 'fallback', 'sdk_version': 'rule-based', 'engine_version': 'v6.5'}
            }
        
        # Calculate average price
        prices = [l['price'] for l in market_data if l.get('price')]
        avg_price = sum(prices) / len(prices) if prices else 500000
        
        return {
            'forensic_price': int(avg_price),
            'confidence_score': 60.0,
            'liquidity_score': 50.0,
            'risk_score': 50.0,
            'days_to_sell_estimate': 30,
            'investment_rating': 'HOLD',
            'summary': 'Rule-based valuation due to AI unavailability',
            'outlier_analysis': 'Standard market pricing applied',
            'performance': {'model': 'fallback', 'sdk': 'rule-based', 'optimization': 'none'},
            'metadata': {'model': 'fallback', 'sdk_version': 'rule-based', 'engine_version': 'v6.5'}
        }
    
    def _get_timestamp(self) -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().isoformat()
    
    # PATCH 7: Cost optimization modes
    def set_fast_mode(self):
        """Switch to fast mode (gemini-2.0-flash)"""
        self.model_name = "gemini-2.0-flash"
        logger.info(f"🚀 Switched to FAST mode: {self.model_name}")
    
    def set_precision_mode(self):
        """Switch to precision mode (gemini-2.0-pro)"""
        self.model_name = "gemini-2.0-pro"
        logger.info(f"🎯 Switched to PRECISION mode: {self.model_name}")
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get current model information"""
        return {
            "model": self.model_name,
            "optimization": "flash" if "flash" in self.model_name else "pro",
            "engine_version": "v6.5",
            "sdk": "google-genai"
        }


# Singleton instance
_ai_engine = None


def get_ai_valuation_engine(model_name: str = "gemini-2.0-flash") -> AIValuationEngine:
    """Get or create AI valuation engine instance"""
    global _ai_engine
    if _ai_engine is None:
        _ai_engine = AIValuationEngine(model_name)
    return _ai_engine
# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v8.1 - Unified AI Service
Centralized "Tril-Engine" failover logic for both Dashboard and Workers.
"""

import os
import json
import logging
import asyncio
from typing import Dict, List, Any, Optional, Literal
from datetime import datetime

# Core imports
from yerimebak_ai_v5.core.utils.logger import get_logger
from yerimebak_ai_v5.core.risk_engine_v8 import get_risk_engine_v8
from yerimebak_ai_v5.core.condition_analyzer import get_condition_analyzer

logger = get_logger("UnifiedAIService")

class UnifiedAIService:
    """
    Unified AI Service with Failover (Primary -> Secondary -> Fallback).
    Provides consistent car valuation narratives and forensic cross-checks.
    """
    
    def __init__(self, verbose: bool = True):
        self.verbose = verbose
        self.enabled = False
        self._client = None
        
        # Load environment variables (fail-safe)
        try:
            from dotenv import load_dotenv
            load_dotenv(override=False)
        except ImportError:
            pass

        # Engine Configuration
        self._or_key = os.getenv("OPENROUTER_API_KEY")
        self._p_model = os.getenv("PRIMARY_MODEL", "google/gemma-3-27b-it:free")
        self._s_model = os.getenv("SECONDARY_MODEL", "stepfun/step-3.5-flash:free")
        self._f_model = os.getenv("FALLBACK_MODEL", "qwen/qwen3-next-80b-a3b-instruct:free")
        
        self._failover_enabled = os.getenv("ENABLE_AI_FAILOVER", "True").lower() == "true"
        self._max_retries = int(os.getenv("MAX_AI_RETRIES", "3"))
        
        self._initialize_client()
        
        # Deterministic engines
        self.risk_engine_v8 = get_risk_engine_v8()
        self.condition_analyzer = get_condition_analyzer()

    def _initialize_client(self):
        """Initialize OpenRouter/OpenAI client"""
        try:
            import openai
            if self._or_key:
                self._client = openai.OpenAI(
                    api_key=self._or_key,
                    base_url="https://openrouter.ai/api/v1",
                )
                self.enabled = True
                if self.verbose:
                    logger.info(f"✅ Unified AI Ready: {self._p_model} -> {self._s_model} -> {self._f_model}")
            else:
                logger.warning("⚠️ OPENROUTER_API_KEY not found. AI features will be disabled.")
        except Exception as e:
            logger.error(f"❌ Failed to initialize AI client: {e}")

    async def generate_valuation_report(self, vehicle: Dict, market_stats: Dict, listings: List[Dict]) -> Dict[str, Any]:
        """
        Generate a comprehensive AI forensic report with failover.
        """
        if not self.enabled:
            return {"error": "AI_DISABLED", "message": "Unified AI Service is not enabled."}

        prompt = self._build_forensic_prompt(vehicle, market_stats, listings)
        system_msg = "You are a professional car dealer expert system. You only speak JSON. Never output conversational text."
        
        # Call with failover
        raw_json = await self._call_ai_with_failover(prompt, system_msg)
        
        if not raw_json:
            return {"error": "AI_FAILOVER_EXHAUSTED", "message": "All AI models failed or returned empty data."}
            
        # Parse and sanitize
        try:
            data = self._parse_json_response(raw_json)
            sanitized = self._sanitize_response(data, vehicle, market_stats)
            return sanitized
        except Exception as e:
            logger.error(f"❌ Failed to parse/sanitize AI response: {e}")
            return {"error": "AI_PARSE_ERROR", "message": str(e)}

    async def _call_ai_with_failover(self, prompt: str, system_msg: str) -> Optional[str]:
        """Execute failover sequence across configured models"""
        models = [self._p_model, self._s_model, self._f_model]
        
        for model in models:
            if not model: continue
            
            logger.info(f"🤖 Calling {model}...")
            for attempt in range(1, self._max_retries + 1):
                try:
                    # In a real environment, this would be an async call if the client supports it
                    # or wrapped in run_in_executor. Using sync for simplicity if appropriate.
                    # Assuming we want to be as async-friendly as possible.
                    response = await asyncio.to_thread(
                        self._client.chat.completions.create,
                        model=model,
                        messages=[
                            {"role": "system", "content": system_msg},
                            {"role": "user", "content": prompt}
                        ],
                        temperature=0.4,
                        max_tokens=2500,
                        timeout=45.0
                    )
                    
                    content = response.choices[0].message.content
                    if content and len(content.strip()) > 10:
                        logger.info(f"✅ {model} success on attempt {attempt}")
                        return content
                        
                except Exception as e:
                    logger.warning(f"⚠️ {model} attempt {attempt} failed: {e}")
                    if "429" in str(e) or "rate limit" in str(e).lower():
                        logger.info("🚀 Rate limited, jumping to next model...")
                        break # Break retry loop, go to next model
                    
                    if attempt < self._max_retries:
                        await asyncio.sleep(1) # Short delay before retry
            
            if not self._failover_enabled:
                break
                
        return None

    def _build_forensic_prompt(self, vehicle: Dict, market_stats: Dict, listings: List[Dict]) -> str:
        """Create high-fidelity forensic prompt"""
        # Compact listing data for token efficiency
        sample_listings = []
        for l in listings[:10]: # Top 10 relevant listings
            sample_listings.append({
                "p": l.get('price'),
                "k": l.get('km'),
                "y": l.get('year'),
                "s": l.get('source')
            })
            
        return f"""
# YERİMEBAK AI v8.1 FORENSIC ANALYSIS PROMPT
Role: Expert Car Dealer (20Y Experience)
Mission: Calculate realistic commercial value. NEVER be optimistic.

# VEHICLE DATA
Brand/Model: {vehicle.get('brand')} {vehicle.get('model')}
Year: {vehicle.get('year')} | KM: {vehicle.get('km'):,}
Condition: {vehicle.get('condition_note', 'Unknown')}
Damage: {vehicle.get('damage_level', 'NONE')}

# MARKET STATS
Avg: {market_stats.get('avg', 0):,} | Min: {market_stats.get('min', 0):,} | Max: {market_stats.get('max', 0):,}
Count: {market_stats.get('total', 0)}

# SAMPLE DATA (P:Price, K:Km, Y:Year, S:Source)
{json.dumps(sample_listings)}

# CONSTRAINTS
- MAX Margin: 25%
- Exit Price MUST NOT exceed market_max.
- If KM > 150k, increase finance/prep risk.

# OUTPUT (Strict JSON only)
{{
  "valuation": {{
    "market_price_avg": 0,
    "estimated_exit_price": 0,
    "confidence_score": 0
  }},
  "analysis": {{
    "opportunity_score": 0,
    "risk_index": 0,
    "liquidity_rank": "HIGH|MID|LOW"
  }},
  "commercial": {{
    "buy_price_optimal": 0,
    "max_purchase_price": 0,
    "expected_profit": 0
  }},
  "verdict": {{
    "decision": "BUY|HOLD|NEGOTIATE|AVOID",
    "note": "Dealer's technical rationale in Turkish"
  }}
}}
"""

    def _parse_json_response(self, text: str) -> Dict[str, Any]:
        """Extract and parse JSON from AI response"""
        import re
        match = re.search(r'(\{.*\})', text, re.DOTALL)
        if match:
            return json.loads(match.group(1))
        
        # Fallback if markdown tags are weird
        if "```json" in text:
            return json.loads(text.split("```json")[1].split("```")[0])
        return json.loads(text)

    def _sanitize_response(self, data: Dict, vehicle: Dict, market_stats: Dict) -> Dict:
        """Apply deterministic guards to AI output"""
        avg = market_stats.get('avg', 0)
        
        # Guard: Exit price cannot be outrageous
        exit_p = data.get('valuation', {}).get('estimated_exit_price', 0)
        if exit_p > market_stats.get('max', avg * 1.1):
            data['valuation']['estimated_exit_price'] = market_stats.get('max', avg * 1.1)
            
        # Guard: Decision override based on profit
        profit = data.get('commercial', {}).get('expected_profit', 0)
        if profit < 0:
            data['verdict']['decision'] = "AVOID"
            data['verdict']['note'] = "Negatif kar beklentisi nedeniyle 'AVOID'."
            
        return data

# Singleton
_service = None

def get_unified_ai_service(verbose: bool = True) -> UnifiedAIService:
    global _service
    if _service is None:
        _service = UnifiedAIService(verbose=verbose)
    return _service

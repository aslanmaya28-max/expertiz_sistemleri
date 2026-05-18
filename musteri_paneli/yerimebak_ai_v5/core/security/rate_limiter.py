# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Rate Limiting System (Güvenli)
Prevents site overload and implements ethical scraping
🔒 secrets kullanılır (random değil) — kriptografik güvenlik
"""

import asyncio
import time
from typing import Dict, Optional
import secrets
from yerimebak_ai_v5.core.utils.logger import get_logger

logger = get_logger(__name__)

class RateLimiter:
    """
    Rate limiting utility for web scraping with per-domain tracking
    🔒 GÜVENLİK: secrets module kullanılır, random değil
    """
    
    def __init__(self):
        # Last request timestamp per domain
        self.last_request: Dict[str, float] = {}
        
        # Per-domain minimum delay (seconds)
        self.domain_delays = {
            "arabam.com": 2.5,
            "sahibinden.com": 3.5,  # More conservative for strict sites
        }
        
        # Default delay if domain not specified
        self.default_delay = 2.0
        
        # Jitter range for human-like behavior (seconds)
        self.jitter_min = 0.3
        self.jitter_max = 0.8
    
    def _get_delay(self, domain: str) -> float:
        """Get base delay for domain"""
        return self.domain_delays.get(domain, self.default_delay)
    
    def _add_jitter(self, delay: float) -> float:
        """Add random jitter to appear more human (secrets for fairness)"""
        jitter = secrets.uniform(self.jitter_min, self.jitter_max)
        return delay + jitter
    
    async def wait_for_slot(self, domain: str):
        """
        Wait until it's safe to make next request for domain
        Applies delay and jitter
        🔒 GÜVENLİK: secrets kullanılır, memory leak önlenir
        """
        # Normalize domain (remove www, protocol)
        clean_domain = domain.replace("www.", "").replace("https://", "").replace("http://", "")
        
        # Get base delay
        base_delay = self._get_delay(clean_domain)
        actual_delay = self._add_jitter(base_delay)
        
        # Check when last request was made
        last_time = self.last_request.get(clean_domain, 0)
        elapsed = time.time() - last_time
        
        # Calculate wait time
        wait_time = max(0, actual_delay - elapsed)
        
        if wait_time > 0:
            logger.info(f"   ⏱️  Rate limiting: waiting {wait_time:.1f}s for {clean_domain}")
            await asyncio.sleep(wait_time)
        else:
            # Small random pause even if not required (more human-like)
            micro_pause = secrets.uniform(0.1, 0.3)
            await asyncio.sleep(micro_pause)
        
        # Update last request time
        self.last_request[clean_domain] = time.time()
        
        # 🔒 MEMORY CLEANUP: 24 saatten eski kayitlari temizle
        # (unbounded dict growth'u önler)
        self._cleanup_old_entries()
    
    def _cleanup_old_entries(self, max_age_seconds: int = 86400):
        """🔒 24 saatten eski rate limit kayitlarini temizle (memory leak önleme)"""
        now = time.time()
        stale = [d for d, t in self.last_request.items() if now - t > max_age_seconds]
        for domain in stale:
            del self.last_request[domain]
        if stale:
            logger.debug(f"🧹 Rate limiter: {len(stale)} stale entry cleaned")
    
    async def with_rate_limit(self, domain: str, coro):
        """
        Wrapper: Apply rate limiting before executing coroutine
        Usage: await rate_limiter.with_rate_limit("arabam.com", some_async_function())
        """
        await self.wait_for_slot(domain)
        return await coro
    
    def set_domain_delay(self, domain: str, delay: float):
        """Override default delay for specific domain"""
        clean_domain = domain.replace("www.", "").replace("https://", "").replace("http://", "")
        self.domain_delays[clean_domain] = delay
        logger.info(f"⚙️  Rate limiter: {clean_domain} delay set to {delay}s")
    
    def reset_domain(self, domain: str):
        """Reset last request time for domain (for testing)"""
        clean_domain = domain.replace("www.", "").replace("https://", "").replace("http://", "")
        if clean_domain in self.last_request:
            del self.last_request[clean_domain]
    
    def get_stats(self) -> Dict[str, float]:
        """Get current rate limiter statistics"""
        stats = {}
        for domain, last_time in self.last_request.items():
            elapsed = time.time() - last_time
            stats[domain] = elapsed
        return stats

# Global rate limiter instance
_global_limiter = None

def get_rate_limiter() -> RateLimiter:
    """Get or create global rate limiter instance"""
    global _global_limiter
    if _global_limiter is None:
        _global_limiter = RateLimiter()
    return _global_limiter
# -*- coding: utf-8 -*-
"""
Arabam Smart Collector Proxy (v6.2)
Redirects to the Arabam Detailed Collector (v2.1)
"""
from typing import List, Dict, Any
from yerimebak_ai_v5.scrapers.arabam_detailed import ArabamDetailedCollector

class ArabamSmartCollector:
    """
    Proxy component for backward compatibility.
    """
    def __init__(self, headless: bool = True):
        self.collector = ArabamDetailedCollector(headless=headless)

    async def collect_data(self, brand: str, model: str, year: int, only_new: bool = False) -> List[Dict[str, Any]]:
        return await self.collector.collect_data(brand, model, year, only_new=only_new)
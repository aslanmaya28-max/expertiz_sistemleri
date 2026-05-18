# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Dynamic Selector Registry
Intelligent selector fallback system for web scraping
"""

from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
import json
from pathlib import Path

@dataclass
class SelectorConfig:
    """Configuration for a single selector"""
    selector: str
    priority: int  # Lower = higher priority (1-10)
    type: str  # "css" or "xpath"
    description: str
    expected_min_items: int = 5  # Minimum items to consider this selector working
    
    def __str__(self):
        type_symbol = "🎯" if self.type == "css" else "🔍"
        return f"{type_symbol} {self.description} (Priority: {self.priority})"

class SelectorRegistry:
    """
    Manages and prioritizes selectors for web scraping
    Implements intelligent fallback strategy
    """
    
    def __init__(self, config_file: Optional[str] = None):
        self.selectors: Dict[str, List[SelectorConfig]] = {}
        
        # Load predefined configurations
        self._load_default_configs()
        
        # Load custom configs if provided
        if config_file:
            self.load_from_file(config_file)
    
    def _load_default_configs(self):
        """Load default selector configurations for common sites"""
        
        # SAHIBINDEN selectors
        self.selectors["sahibinden"] = [
            SelectorConfig(
                selector="tr[class*='searchResultsItem']",
                priority=1,
                type="css",
                description="Classic table rows",
                expected_min_items=5
            ),
            SelectorConfig(
                selector="div[class*='searchResultsItem']",
                priority=2,
                type="css",
                description="Div-based listings",
                expected_min_items=5
            ),
            SelectorConfig(
                selector=".searchResultsRow",
                priority=3,
                type="css",
                description="Row containers",
                expected_min_items=5
            ),
            SelectorConfig(
                selector="table tbody tr",
                priority=4,
                type="css",
                description="Generic table rows",
                expected_min_items=3
            ),
            SelectorConfig(
                selector="[data-id]",
                priority=5,
                type="css",
                description="Elements with data IDs",
                expected_min_items=3
            ),
        ]
        
        # ARABAM selectors
        self.selectors["arabam"] = [
            SelectorConfig(
                selector="a[href*='/ilan/']",
                priority=1,
                type="css",
                description="Arabam listing links",
                expected_min_items=5
            ),
            SelectorConfig(
                selector="[class*='listing-card']",
                priority=2,
                type="css",
                description="Listing cards",
                expected_min_items=5
            ),
            SelectorConfig(
                selector="div[data-id]",
                priority=3,
                type="css",
                description="Elements with data attributes",
                expected_min_items=3
            ),
        ]
    
    def get_selectors(self, site: str) -> List[SelectorConfig]:
        """
        Get selectors for a site, ordered by priority
        
        Args:
            site: Site identifier (e.g., "arabam", "sahibinden")
        
        Returns:
            List of SelectorConfig sorted by priority
        """
        configs = self.selectors.get(site, [])
        return sorted(configs, key=lambda x: x.priority)
    
    def add_selector(self, site: str, selector: str, priority: int, 
                    description: str, type: str = "css", expected_min_items: int = 5):
        """
        Add a new selector configuration
        
        Args:
            site: Site identifier
            selector: CSS or XPath selector
            priority: Priority level (1-10, lower is better)
            description: Human-readable description
            type: "css" or "xpath"
            expected_min_items: Minimum items to consider working
        """
        if site not in self.selectors:
            self.selectors[site] = []
        
        config = SelectorConfig(
            selector=selector,
            priority=priority,
            type=type,
            description=description,
            expected_min_items=expected_min_items
        )
        
        self.selectors[site].append(config)
    
    def save_to_file(self, filepath: str):
        """Save current configuration to JSON file"""
        data = {}
        for site, configs in self.selectors.items():
            data[site] = [
                {
                    "selector": c.selector,
                    "priority": c.priority,
                    "type": c.type,
                    "description": c.description,
                    "expected_min_items": c.expected_min_items
                }
                for c in configs
            ]
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
    
    def load_from_file(self, filepath: str):
        """Load selector configurations from JSON file"""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for site, configs in data.items():
                for c in configs:
                    self.add_selector(
                        site=site,
                        selector=c["selector"],
                        priority=c["priority"],
                        description=c["description"],
                        type=c.get("type", "css"),
                        expected_min_items=c.get("expected_min_items", 5)
                    )
        
        except Exception as e:
            print(f"⚠️  Error loading selector config: {e}")
    
    def track_success(self, site: str, selector: str):
        """
        Track successful selector usage for analytics
        (Can be extended to auto-prioritize working selectors)
        """
        # For future enhancement: track which selectors work best
        pass
    
    def print_selectors(self, site: str):
        """Print all selectors for a site"""
        configs = self.get_selectors(site)
        print(f"\n📋 {site.upper()} Selectors (Priority Order):")
        print("=" * 50)
        for config in configs:
            print(f"  {config}")
        print()

# Global registry instance
_global_registry = None

def get_selector_registry(config_file: Optional[str] = None) -> SelectorRegistry:
    """Get or create global selector registry"""
    global _global_registry
    if _global_registry is None:
        _global_registry = SelectorRegistry(config_file=config_file)
    return _global_registry
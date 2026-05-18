# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Cache Management System
Speeds up repeated queries for same vehicles
"""

import json
import os
import time
from pathlib import Path
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta

class CacheManager:
    """
    Disk-based JSON cache for market data
    Prevents redundant scraping for same vehicle queries
    """
    
    def __init__(self, cache_dir: Optional[str] = None, ttl_hours: int = 24):
        # Cache directory
        if cache_dir is None:
            # Default to project cache folder
            self.cache_dir = Path(__file__).parent.parent / "data" / "cache"
        else:
            self.cache_dir = Path(cache_dir)
        
        # Create cache directory if doesn't exist
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        # TTL (Time To Live) in hours
        self.ttl_hours = ttl_hours
        self.ttl_seconds = ttl_hours * 3600
        
        # Cache statistics
        self.stats = {
            "hits": 0,
            "misses": 0,
            "expired": 0
        }
    
    def _generate_cache_key(self, brand: str, model: str, year: int) -> str:
        """
        Generate unique cache key for vehicle query
        Format: brand_model_year.json
        """
        # Normalize key components
        brand_clean = brand.lower().strip().replace(" ", "_")
        model_clean = model.lower().strip().replace(" ", "_")
        
        # Create key
        key = f"{brand_clean}_{model_clean}_{year}"
        return key
    
    def _get_cache_path(self, cache_key: str) -> Path:
        """Get full path to cache file"""
        return self.cache_dir / f"{cache_key}.json"
    
    def _is_expired(self, cache_data: Dict[str, Any]) -> bool:
        """Check if cache entry has expired"""
        cached_time = cache_data.get("timestamp", 0)
        current_time = time.time()
        age = current_time - cached_time
        return age > self.ttl_seconds
    
    def get(self, brand: str, model: str, year: int) -> Optional[List[Dict[str, Any]]]:
        """
        Retrieve cached market data for vehicle
        
        Returns:
            List of market listings if valid cache found, None otherwise
        """
        cache_key = self._generate_cache_key(brand, model, year)
        cache_path = self._get_cache_path(cache_key)
        
        # Check if cache file exists
        if not cache_path.exists():
            self.stats["misses"] += 1
            return None
        
        try:
            # Read cache file
            with open(cache_path, 'r', encoding='utf-8') as f:
                cache_data = json.load(f)
            
            # Check if expired
            if self._is_expired(cache_data):
                self.stats["expired"] += 1
                # Delete expired file
                cache_path.unlink()
                return None
            
            # Cache hit!
            self.stats["hits"] += 1
            cached_time = datetime.fromtimestamp(cache_data["timestamp"])
            print(f"   🎯 CACHE HIT: {len(cache_data['data'])} listings from {cached_time.strftime('%H:%M:%S')}")
            
            return cache_data.get("data", [])
            
        except Exception as e:
            print(f"   ⚠️  Cache read error: {e}")
            self.stats["misses"] += 1
            # Corrupted file, delete it
            if cache_path.exists():
                cache_path.unlink()
            return None
    
    def set(self, brand: str, model: str, year: int, data: List[Dict[str, Any]]):
        """
        Store market data in cache
        
        Args:
            brand: Vehicle brand
            model: Vehicle model
            year: Vehicle year
            data: List of market listings to cache
        """
        if not data:
            print(f"   ⚠️  No data to cache for {brand} {model} {year}")
            return
        
        cache_key = self._generate_cache_key(brand, model, year)
        cache_path = self._get_cache_path(cache_key)
        
        try:
            # Prepare cache entry
            cache_entry = {
                "timestamp": time.time(),
                "brand": brand,
                "model": model,
                "year": year,
                "count": len(data),
                "data": data
            }
            
            # Write to file
            with open(cache_path, 'w', encoding='utf-8') as f:
                json.dump(cache_entry, f, indent=2, ensure_ascii=False)
            
            print(f"   ✅ CACHED: {len(data)} listings for {brand} {model} {year}")
            
        except Exception as e:
            print(f"   ❌ Cache write error: {e}")
    
    def invalidate(self, brand: str, model: str, year: int):
        """Invalidate specific cache entry"""
        cache_key = self._generate_cache_key(brand, model, year)
        cache_path = self._get_cache_path(cache_key)
        
        if cache_path.exists():
            cache_path.unlink()
            print(f"   🗑️  Cache invalidated: {brand} {model} {year}")
    
    def clear_all(self):
        """Clear all cache files"""
        try:
            for cache_file in self.cache_dir.glob("*.json"):
                cache_file.unlink()
            print(f"   🗑️  All cache cleared ({self.cache_dir})")
        except Exception as e:
            print(f"   ❌ Cache clear error: {e}")
    
    def cleanup_expired(self):
        """Remove all expired cache entries"""
        cleaned = 0
        try:
            for cache_file in self.cache_dir.glob("*.json"):
                try:
                    with open(cache_file, 'r', encoding='utf-8') as f:
                        cache_data = json.load(f)
                    
                    if self._is_expired(cache_data):
                        cache_file.unlink()
                        cleaned += 1
                except Exception:
                    cache_file.unlink()
                    cleaned += 1
            
            if cleaned > 0:
                print(f"   🧹 Cleaned {cleaned} expired cache entries")
        
        except Exception as e:
            print(f"   ❌ Cleanup error: {e}")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        total_requests = self.stats["hits"] + self.stats["misses"]
        hit_rate = self.stats["hits"] / total_requests if total_requests > 0 else 0
        
        return {
            "hits": self.stats["hits"],
            "misses": self.stats["misses"],
            "expired": self.stats["expired"],
            "hit_rate": f"{hit_rate:.1%}",
            "cache_dir": str(self.cache_dir),
            "ttl_hours": self.ttl_hours
        }
    
    def get_cache_info(self, brand: str, model: str, year: int) -> Optional[Dict[str, Any]]:
        """Get information about specific cache entry without loading data"""
        cache_key = self._generate_cache_key(brand, model, year)
        cache_path = self._get_cache_path(cache_key)
        
        if not cache_path.exists():
            return None
        
        try:
            with open(cache_path, 'r', encoding='utf-8') as f:
                cache_data = json.load(f)
            
            cached_time = datetime.fromtimestamp(cache_data["timestamp"])
            current_time = datetime.now()
            age = current_time - cached_time
            expires_at = cached_time + timedelta(hours=self.ttl_hours)
            
            return {
                "exists": True,
                "entries": cache_data.get("count", 0),
                "cached_at": cached_time.isoformat(),
                "age_hours": age.total_seconds() / 3600,
                "expires_at": expires_at.isoformat(),
                "is_expired": self._is_expired(cache_data)
            }
        
        except Exception as e:
            return None

# Global cache manager instance
_global_cache = None

def get_cache_manager(cache_dir: Optional[str] = None, ttl_hours: int = 24) -> CacheManager:
    """Get or create global cache manager instance"""
    global _global_cache
    if _global_cache is None:
        _global_cache = CacheManager(cache_dir=cache_dir, ttl_hours=ttl_hours)
    return _global_cache
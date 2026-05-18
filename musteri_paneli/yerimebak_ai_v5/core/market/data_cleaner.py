# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v6 - Data Cleaning Engine
Production-grade data cleaning and outlier detection
"""

import logging
from typing import List, Dict, Any, Tuple
from datetime import datetime
import statistics

logger = logging.getLogger(__name__)


class DataCleaner:
    """Production-grade data cleaning engine"""
    
    def __init__(self, debug_mode: bool = False):
        self.debug_mode = debug_mode
        
    def clean_listing_data(self, listings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Clean and validate listing data
        
        Args:
            listings: Raw listing data from scrapers
        
        Returns:
            Cleaned listings with outliers removed
        """
        if not listings:
            logger.warning("No listings to clean")
            return []
        
        initial_count = len(listings)
        logger.info(f"Starting data cleaning: {initial_count} listings")
        
        # Step 1: Remove invalid listings
        valid_listings = self._remove_invalid_listings(listings)
        logger.info(f"Removed {initial_count - len(valid_listings)} invalid listings")
        
        if not valid_listings:
            logger.error("No valid listings remaining after initial validation")
            return []
        
        # Step 2: Calculate statistics
        stats = self._calculate_statistics(valid_listings)
        logger.info(f"Market statistics: {stats}")
        
        # Step 3: Remove price outliers
        clean_listings = self._remove_price_outliers(valid_listings, stats)
        logger.info(f"Removed {len(valid_listings) - len(clean_listings)} price outliers")
        
        # Step 4: Remove KM outliers
        clean_listings = self._remove_km_outliers(clean_listings)
        logger.info(f"Removed KM outliers, remaining: {len(clean_listings)}")
        
        # Step 5: Remove duplicates
        clean_listings = self._remove_duplicates(clean_listings)
        logger.info(f"Removed duplicates, final count: {len(clean_listings)}")
        
        final_stats = self._calculate_statistics(clean_listings)
        
        logger.info(f"Data cleaning complete: {initial_count} → {len(clean_listings)} listings")
        logger.info(f"Final statistics: {final_stats}")
        
        return clean_listings
    
    def _remove_invalid_listings(self, listings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove listings with missing or invalid data"""
        valid = []
        
        for listing in listings:
            try:
                # Check required fields
                price = listing.get('price')
                if price is None or not isinstance(price, (int, float)):
                    continue
                
                # Price validation
                if price < 50000:  # Minimum valid price
                    if self.debug_mode:
                        logger.debug(f"Removed listing with price < 50000: {price}")
                    continue
                
                # Check source
                source = listing.get('source', 'unknown')
                if source == 'demo_fallback':
                    if self.debug_mode:
                        logger.debug("Skipping demo fallback listing")
                    continue
                
                # Add default values for optional fields
                if 'km' not in listing or listing['km'] is None:
                    listing['km'] = 0
                if 'year' not in listing or listing['year'] is None:
                    listing['year'] = 2020
                
                valid.append(listing)
                
            except Exception as e:
                logger.error(f"Error validating listing: {e}")
                continue
        
        return valid
    
    def _calculate_statistics(self, listings: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Calculate market statistics"""
        prices = [l['price'] for l in listings if l.get('price')]
        kms = [l['km'] for l in listings if l.get('km') and l['km'] > 0]
        
        stats = {
            'count': len(listings),
            'price_range': None,
            'price_avg': None,
            'price_std': None,
            'price_median': None,
            'km_avg': None,
            'km_median': None
        }
        
        if prices:
            stats['price_range'] = {
                'min': min(prices),
                'max': max(prices),
                'span': max(prices) - min(prices)
            }
            stats['price_avg'] = statistics.mean(prices)
            stats['price_std'] = statistics.stdev(prices) if len(prices) > 1 else 0
            stats['price_median'] = statistics.median(prices)
        
        if kms:
            stats['km_avg'] = statistics.mean(kms)
            stats['km_median'] = statistics.median(kms)
        
        return stats
    
    def _remove_price_outliers(self, listings: List[Dict[str, Any]], 
                              stats: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Remove price outliers using standard deviation method"""
        if not stats.get('price_avg') or not stats.get('price_std'):
            return listings

        avg_price = stats['price_avg']
        std_price = stats['price_std']

        if std_price > 0:
            lower_bound = avg_price - 2 * std_price
            upper_bound = avg_price + 2 * std_price
        else:
            lower_bound = avg_price * 0.6
            upper_bound = avg_price * 1.4
        
        if self.debug_mode:
            logger.debug(f"Price bounds: {lower_bound:,.0f} - {upper_bound:,.0f}")
        
        clean = []
        outliers = 0
        
        for listing in listings:
            price = listing.get('price', 0)
            
            if lower_bound <= price <= upper_bound:
                clean.append(listing)
            else:
                outliers += 1
                if self.debug_mode:
                    logger.debug(f"Removed price outlier: {price:,.0f} TL")
        
        return clean
    
    def _remove_km_outliers(self, listings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove listings with unrealistic KM values"""
        max_km = 500000
        
        clean = []
        for listing in listings:
            km = listing.get('km', 0)
            
            if km == 0 or km <= max_km:
                clean.append(listing)
            else:
                if self.debug_mode:
                    logger.debug(f"Removed listing with KM > {max_km}: {km:,}")
        
        return clean
    
    def _remove_duplicates(self, listings: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove duplicate listings based on price and KM"""
        seen = set()
        unique = []
        
        for listing in listings:
            # Create a unique key
            price = listing.get('price', 0)
            km = listing.get('km', 0)
            source = listing.get('source', 'unknown')
            
            # Round price to nearest 1000 for grouping
            price_key = round(price / 1000) * 1000
            
            key = (price_key, km, source)
            
            if key not in seen:
                seen.add(key)
                unique.append(listing)
            elif self.debug_mode:
                logger.debug(f"Removed duplicate: {price:,} TL, {km:,} KM, {source}")
        
        return unique
    
    def get_cleaning_report(self, original: List[Dict[str, Any]], 
                           cleaned: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate cleaning report"""
        original_count = len(original)
        cleaned_count = len(cleaned)
        removed_count = original_count - cleaned_count
        
        stats_original = self._calculate_statistics(original)
        stats_cleaned = self._calculate_statistics(cleaned)
        
        return {
            'original_count': original_count,
            'cleaned_count': cleaned_count,
            'removed_count': removed_count,
            'removal_rate': (removed_count / original_count * 100) if original_count > 0 else 0,
            'original_stats': stats_original,
            'cleaned_stats': stats_cleaned,
            'timestamp': datetime.now().isoformat()
        }


# Singleton instance
_cleaner = None


def get_data_cleaner(debug_mode: bool = False) -> DataCleaner:
    """Get or create data cleaner instance"""
    global _cleaner
    if _cleaner is None:
        _cleaner = DataCleaner(debug_mode=debug_mode)
    return _cleaner
# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v6 - Opportunity Detector
Detects undervalued vehicles and calculates profit potential
"""

import logging
from typing import List, Dict, Any

logger = logging.getLogger(__name__)


class OpportunityDetector:
    """Detects investment opportunities in vehicle listings"""
    
    def __init__(self, opportunity_threshold: float = 0.85):
        """
        Initialize opportunity detector
        
        Args:
            opportunity_threshold: Price threshold (0.85 = 15% below fair price)
        """
        self.opportunity_threshold = opportunity_threshold
        logger.info(f"Opportunity Detector initialized with threshold: {opportunity_threshold}")
    
    def detect_opportunities(self, listings: List[Dict[str, Any]], 
                           forensic_price: float) -> List[Dict[str, Any]]:
        """
        Detect undervalued vehicles
        
        Args:
            listings: Cleaned market listings
            forensic_price: AI-calculated fair market price
        
        Returns:
            List of opportunities with profit calculations
        """
        if not listings or forensic_price <= 0:
            logger.warning("No listings or invalid forensic price")
            return []
        
        opportunities = []
        
        for listing in listings:
            try:
                price = listing.get('price', 0)
                
                if price <= 0:
                    continue
                
                # Calculate price difference
                price_diff = forensic_price - price
                price_diff_percent = (price_diff / forensic_price) * 100
                
                # Check if it's an opportunity
                if price < forensic_price * self.opportunity_threshold:
                    opportunity = self._calculate_opportunity(
                        listing, forensic_price, price_diff, price_diff_percent
                    )
                    opportunities.append(opportunity)
                    
                    logger.info(f"Opportunity found: {price:,.0f} TL vs {forensic_price:,.0f} TL ({price_diff_percent:.1f}% below)")
            
            except Exception as e:
                logger.error(f"Error analyzing listing: {e}")
                continue
        
        # Sort by potential profit (descending)
        opportunities.sort(key=lambda x: x['potential_profit'], reverse=True)
        
        logger.info(f"Found {len(opportunities)} opportunities")
        return opportunities
    
    def _calculate_opportunity(self, listing: Dict[str, Any], 
                              forensic_price: float, 
                              price_diff: float, 
                              price_diff_percent: float) -> Dict[str, Any]:
        """Calculate detailed opportunity metrics"""
        
        # Determine rating
        if price_diff_percent > 20:
            rating = "HIGH"
        elif price_diff_percent > 10:
            rating = "MEDIUM"
        else:
            rating = "LOW"
        
        # Calculate risk score (lower price = higher risk but higher reward)
        risk_score = max(0, min(100, 100 - price_diff_percent * 2))
        
        return {
            'listing_id': listing.get('url', 'unknown')[-20:],  # Last 20 chars of URL
            'price': listing.get('price'),
            'forensic_price': int(forensic_price),
            'potential_profit': int(price_diff),
            'profit_percentage': round(price_diff_percent, 2),
            'rating': rating,
            'risk_score': round(risk_score, 2),
            'km': listing.get('km', 0),
            'source': listing.get('source', 'unknown'),
            'url': listing.get('url', ''),
            'investment_analysis': self._generate_investment_analysis(
                price_diff_percent, risk_score
            )
        }
    
    def _generate_investment_analysis(self, profit_percent: float, 
                                     risk_score: float) -> str:
        """Generate brief investment analysis"""
        
        if profit_percent > 20:
            return f"EXCELLENT opportunity: {profit_percent:.1f}% below market. Strong buy recommendation."
        elif profit_percent > 15:
            return f"GOOD opportunity: {profit_percent:.1f}% below market. Low risk, high reward."
        elif profit_percent > 10:
            return f"MODERATE opportunity: {profit_percent:.1f}% below market. Worth considering."
        else:
            return f"MINIMAL opportunity: {profit_percent:.1f}% below market. Monitor for price drops."
    
    def get_opportunity_summary(self, opportunities: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate opportunity summary statistics"""
        
        if not opportunities:
            return {
                'total_opportunities': 0,
                'total_potential_profit': 0,
                'average_profit_percent': 0,
                'best_opportunity': None
            }
        
        total_profit = sum(o['potential_profit'] for o in opportunities)
        avg_profit = sum(o['profit_percentage'] for o in opportunities) / len(opportunities)
        
        # Count by rating
        rating_counts = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
        for opp in opportunities:
            rating_counts[opp['rating']] = rating_counts.get(opp['rating'], 0) + 1
        
        return {
            'total_opportunities': len(opportunities),
            'total_potential_profit': total_profit,
            'average_profit_percent': round(avg_profit, 2),
            'rating_breakdown': rating_counts,
            'best_opportunity': opportunities[0] if opportunities else None,
            'timestamp': self._get_timestamp()
        }
    
    def _get_timestamp(self) -> str:
        """Get current timestamp"""
        from datetime import datetime
        return datetime.now().isoformat()


# Singleton instance
_detector = None


def get_opportunity_detector(threshold: float = 0.85) -> OpportunityDetector:
    """Get or create opportunity detector instance"""
    global _detector
    if _detector is None:
        _detector = OpportunityDetector(threshold)
    return _detector
import numpy as np
import pandas as pd
from typing import Dict, Any

class AnalyticsService:
    @staticmethod
    def calculate_market_metrics(df: pd.DataFrame) -> Dict[str, Any]:
        if df.empty:
            return {
                "avg_price": 0, "median_price": 0, "min_price": 0, "max_price": 0,
                "volatility": 0, "liquidity_score": 0
            }

        prices = df['price'].values
        avg_price = np.mean(prices)
        median_price = np.median(prices)
        min_price = np.min(prices)
        max_price = np.max(prices)
        
        # Volatility as coefficient of variation
        volatility = (np.std(prices) / avg_price) * 100 if avg_price > 0 else 0
        
        # Liquidity score based on count and spread (pseudo-metric)
        count_factor = min(len(df) / 50, 1.0) # More listings = better liquidity
        spread_factor = 1.0 - min(volatility / 50, 0.5) # Lower volatility = better liquidity
        liquidity_score = (count_factor * 0.7 + spread_factor * 0.3) * 100

        return {
            "avg_price": int(avg_price),
            "median_price": int(median_price),
            "min_price": int(min_price),
            "max_price": int(max_price),
            "volatility": round(volatility, 2),
            "liquidity_score": round(liquidity_score, 1)
        }

    @staticmethod
    def detect_price_drops(df: pd.DataFrame) -> pd.DataFrame:
        # Simple detection: listings priced significantly below median
        if df.empty: return df
        median = df['price'].median()
        df['opportunity_score'] = (1 - (df['price'] / median)) * 100
        return df[df['price'] < (median * 0.9)].sort_values('opportunity_score', ascending=False)

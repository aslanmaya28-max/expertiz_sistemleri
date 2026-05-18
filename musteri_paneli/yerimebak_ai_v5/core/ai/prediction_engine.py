# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Prediction Engine
3-6 Month Price Forecasting and Amortization Analysis
"""
from datetime import datetime, timedelta

class PredictionEngine:
    def __init__(self, monthly_inflation_rate: float = 0.02):
        self.annual_depreciation_base = 0.12 
        self.monthly_inflation_rate = monthly_inflation_rate

    def predict_future_price(self, current_price: float, months: int = 4) -> float:
        monthly_rate = self.annual_depreciation_base / 12
        depreciation = current_price * (monthly_rate * months)
        inflation_adjustment = current_price * (self.monthly_inflation_rate * months)
        
        predicted_price = current_price - depreciation + inflation_adjustment
        return round(predicted_price, 0)

    def calculate_amortization(self, purchase_price: float, year: int) -> dict:
        """
        Filo için amortisman analizi
        """
        age = datetime.now().year - year
        total_depreciation_pct = min(age * self.annual_depreciation_base * 100, 90)
        
        return {
            "age": age,
            "total_depreciation_pct": round(total_depreciation_pct, 1),
            "remaining_value_pct": round(100 - total_depreciation_pct, 1)
        }

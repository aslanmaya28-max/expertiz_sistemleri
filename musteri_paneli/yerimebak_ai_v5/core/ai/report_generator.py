# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v6 - Report Generator
Generates forensic reports in JSON and HTML formats
"""

import json
import logging
from typing import Dict, Any, List
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)


class ReportGenerator:
    """Generates forensic valuation reports"""
    
    def __init__(self, output_dir: str = "data/reports"):
        """Initialize report generator"""
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Report Generator initialized with output dir: {output_dir}")
    
    def generate_forensic_report(self, vehicle: Dict[str, Any],
                                listings: List[Dict[str, Any]],
                                valuation: Dict[str, Any],
                                opportunities: List[Dict[str, Any]],
                                cleaning_stats: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate complete forensic report
        
        Returns:
            Dict with json_path and html_path
        """
        try:
            # Generate report ID
            report_id = self._generate_report_id(vehicle)
            
            # Build JSON report
            json_report = self._build_json_report(
                vehicle, listings, valuation, opportunities, cleaning_stats, report_id
            )
            
            # Generate HTML report
            html_report = self._build_html_report(json_report)
            
            # Save files
            json_path = self._save_json_report(report_id, json_report)
            html_path = self._save_html_report(report_id, html_report)
            
            logger.info(f"Report generated: {json_path} and {html_path}")
            
            return {
                'report_id': report_id,
                'json_path': str(json_path),
                'html_path': str(html_path),
                'timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            logger.error(f"Report generation failed: {e}")
            raise
    
    def _generate_report_id(self, vehicle: Dict[str, Any]) -> str:
        """Generate unique report ID"""
        brand = vehicle.get('brand', 'UNKNOWN').upper()
        model = vehicle.get('model', 'UNKNOWN').upper()
        year = vehicle.get('year', 2020)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        return f"{brand}_{model}_{year}_{timestamp}"
    
    def _build_json_report(self, vehicle: Dict[str, Any],
                          listings: List[Dict[str, Any]],
                          valuation: Dict[str, Any],
                          opportunities: List[Dict[str, Any]],
                          cleaning_stats: Dict[str, Any],
                          report_id: str) -> Dict[str, Any]:
        """Build JSON report structure"""
        
        return {
            'report_id': report_id,
            'report_type': 'FORENSIC_VALUATION_V6',
            'generated_at': datetime.now().isoformat(),
            
            'vehicle': {
                'brand': vehicle.get('brand'),
                'model': vehicle.get('model'),
                'year': vehicle.get('year'),
                'km': vehicle.get('km'),
                'fuel': vehicle.get('fuel'),
                'transmission': vehicle.get('transmission')
            },
            
            'valuation': {
                'forensic_price': valuation.get('forensic_price'),
                'confidence_score': valuation.get('confidence_score'),
                'liquidity_score': valuation.get('liquidity_score'),
                'risk_score': valuation.get('risk_score'),
                'days_to_sell_estimate': valuation.get('days_to_sell_estimate'),
                'investment_rating': valuation.get('investment_rating'),
                'summary': valuation.get('summary'),
                'outlier_analysis': valuation.get('outlier_analysis')
            },
            
            'market_data': {
                'total_listings': len(listings),
                'cleaning_stats': cleaning_stats,
                'price_range': {
                    'min': min(l['price'] for l in listings if l.get('price')),
                    'max': max(l['price'] for l in listings if l.get('price')),
                    'avg': sum(l['price'] for l in listings if l.get('price')) / len(listings)
                } if listings else None
            },
            
            'opportunities': {
                'total_opportunities': len(opportunities),
                'total_potential_profit': sum(o['potential_profit'] for o in opportunities),
                'opportunities': opportunities[:10]  # Top 10
            },
            
            'listings': listings[:20]  # Top 20 listings
        }
    
    def _build_html_report(self, json_report: Dict[str, Any]) -> str:
        """Build HTML report from JSON data"""
        
        vehicle = json_report['vehicle']
        valuation = json_report['valuation']
        opportunities = json_report['opportunities']
        
        html = f"""<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Forensic Valuation Report - {vehicle['brand']} {vehicle['model']}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; }}
        .container {{ max-width: 1400px; margin: 0 auto; padding: 20px; }}
        .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }}
        .header h1 {{ font-size: 2.5em; margin-bottom: 10px; }}
        .header p {{ opacity: 0.9; }}
        .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 30px; }}
        .card {{ background: white; border-radius: 10px; padding: 25px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .card h3 {{ color: #667eea; margin-bottom: 15px; font-size: 1.3em; }}
        .metric {{ display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #eee; }}
        .metric:last-child {{ border-bottom: none; }}
        .metric-label {{ color: #666; }}
        .metric-value {{ font-weight: bold; color: #333; }}
        .price {{ font-size: 2em; color: #764ba2; font-weight: bold; }}
        .rating {{ display: inline-block; padding: 8px 16px; border-radius: 20px; color: white; font-weight: bold; }}
        .rating.buy {{ background: #10b981; }}
        .rating.hold {{ background: #f59e0b; }}
        .rating.sell {{ background: #ef4444; }}
        .score {{ display: inline-block; padding: 5px 12px; border-radius: 15px; font-weight: bold; }}
        .score.high {{ background: #d1fae5; color: #065f46; }}
        .score.medium {{ background: #fef3c7; color: #92400e; }}
        .score.low {{ background: #fee2e2; color: #991b1b; }}
        .opportunity {{ background: #ecfdf5; border-left: 4px solid #10b981; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        .opportunity h4 {{ color: #065f46; margin-bottom: 5px; }}
        .chart-container {{ background: white; border-radius: 10px; padding: 25px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); margin-bottom: 30px; }}
        .footer {{ text-align: center; padding: 30px; color: #666; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Forensic Valuation Report</h1>
            <p>{vehicle['brand']} {vehicle['model']} {vehicle['year']} • {vehicle['km']:,} KM</p>
            <p style="margin-top: 10px; font-size: 0.9em;">Generated: {json_report['generated_at']}</p>
        </div>
        
        <div class="grid">
            <div class="card">
                <h3>💰 Forensic Valuation</h3>
                <div class="price">{valuation['forensic_price']:,} TL</div>
                <p style="margin-top: 15px;">{valuation['summary']}</p>
                <div style="margin-top: 15px;">
                    <span class="rating {valuation['investment_rating'].lower()}">{valuation['investment_rating']}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>📊 Confidence Metrics</h3>
                <div class="metric">
                    <span class="metric-label">Confidence Score</span>
                    <span class="metric-value"><span class="score high">{valuation['confidence_score']}%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Liquidity Score</span>
                    <span class="metric-value"><span class="score medium">{valuation['liquidity_score']}%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Risk Score</span>
                    <span class="metric-value"><span class="score low">{valuation['risk_score']}%</span></span>
                </div>
                <div class="metric">
                    <span class="metric-label">Days to Sell</span>
                    <span class="metric-value">~{valuation['days_to_sell_estimate']} days</span>
                </div>
            </div>
            
            <div class="card">
                <h3>🎯 Investment Opportunities</h3>
                <div class="metric">
                    <span class="metric-label">Total Opportunities</span>
                    <span class="metric-value">{opportunities['total_opportunities']}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Total Potential Profit</span>
                    <span class="metric-value">{opportunities['total_potential_profit']:,} TL</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Market Listings</span>
                    <span class="metric-value">{json_report['market_data']['total_listings']}</span>
                </div>
            </div>
        </div>
        
        <div class="chart-container">
            <h3 style="margin-bottom: 20px;">📈 Market Analysis</h3>
            <canvas id="priceChart" height="100"></canvas>
        </div>
        
        {self._generate_opportunities_section(opportunities)}
        
        <div class="card" style="margin-top: 30px;">
            <h3>🔬 Outlier Analysis</h3>
            <p>{valuation['outlier_analysis']}</p>
        </div>
        
        <div class="footer">
            <p>Generated by YerimeBak AI v6 Forensic Core</p>
            <p style="font-size: 0.9em; margin-top: 10px;">Report ID: {json_report['report_id']}</p>
        </div>
    </div>
    
    <script>
        const ctx = document.getElementById('priceChart').getContext('2d');
        const prices = {json.dumps([l['price'] for l in json_report['listings'][:10]])};
        const forensicPrice = {valuation['forensic_price']};
        
        new Chart(ctx, {{
            type: 'bar',
            data: {{
                labels: prices.map((_, i) => `Listing ${{i + 1}}`),
                datasets: [{{
                    label: 'Market Price',
                    data: prices,
                    backgroundColor: 'rgba(102, 126, 234, 0.6)',
                    borderColor: 'rgba(102, 126, 234, 1)',
                    borderWidth: 1
                }}]
            }},
            options: {{
                responsive: true,
                plugins: {{
                    annotation: {{
                        annotations: {{
                            line1: {{
                                type: 'line',
                                yMin: forensicPrice,
                                yMax: forensicPrice,
                                borderColor: 'rgb(255, 99, 132)',
                                borderWidth: 2,
                                label: {{
                                    display: true,
                                    content: 'Forensic Price'
                                }}
                            }}
                        }}
                    }}
                }}
            }}
        }});
    </script>
</body>
</html>"""
        
        return html
    
    def _generate_opportunities_section(self, opportunities: Dict[str, Any]) -> str:
        """Generate HTML for opportunities section"""
        
        if not opportunities['opportunities']:
            return ""
        
        html = '<div class="card" style="margin-top: 30px;"><h3>💎 Top Opportunities</h3>'
        
        for opp in opportunities['opportunities'][:5]:
            html += f"""
            <div class="opportunity">
                <h4>{opp['rating']} Opportunity - {opp['profit_percentage']:.1f}% Below Market</h4>
                <p><strong>Price:</strong> {opp['price']:,} TL → <strong>Forensic:</strong> {opp['forensic_price']:,} TL</p>
                <p><strong>Potential Profit:</strong> {opp['potential_profit']:,} TL ({opp['km']:,} KM)</p>
                <p style="margin-top: 10px; font-size: 0.9em;">{opp['investment_analysis']}</p>
            </div>
            """
        
        html += '</div>'
        return html
    
    def _save_json_report(self, report_id: str, report: Dict[str, Any]) -> Path:
        """Save JSON report to file"""
        path = self.output_dir / f"{report_id}.json"
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
        return path
    
    def _save_html_report(self, report_id: str, html: str) -> Path:
        """Save HTML report to file"""
        path = self.output_dir / f"{report_id}.html"
        with open(path, 'w', encoding='utf-8') as f:
            f.write(html)
        return path


# Singleton instance
_generator = None


def get_report_generator(output_dir: str = "data/reports") -> ReportGenerator:
    """Get or create report generator instance"""
    global _generator
    if _generator is None:
        _generator = ReportGenerator(output_dir)
    return _generator
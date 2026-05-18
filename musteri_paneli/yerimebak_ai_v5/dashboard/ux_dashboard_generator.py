# -*- coding: utf-8 -*-
"""
🏛️ YERİMEBAK AI - ANTIGRAVITY v5.1 DASHBOARD
Forensic + Product + Sales Unified Intelligence
"""

import json
import hashlib
import asyncio
from datetime import datetime
from typing import Dict, List, Optional
import sys
import os
import webbrowser
from pathlib import Path

class QuantumThemeV51:
    """Antigravity v5.1 Quantum Theme Engine"""
    
    COLORS = {
        'background': '#001233',  # Quantum Blue
        'surface': '#001a4d',
        'primary': '#0044cc',
        'gold': '#FFD700',       # Value Highlight
        'neon_green': '#39FF14', # Approval Indicators
        'text_primary': '#ffffff',
        'text_secondary': '#a0aec0',
        'border': '#1a365d',
        'danger': '#ff0033'
    }
    
    GRADIENTS = {
        'quantum_depth': 'linear-gradient(180deg, #001233 0%, #001a4d 100%)',
        'gold_edge': 'linear-gradient(135deg, #FFD700 0%, #b8860b 100%)',
        'green_glow': 'radial-gradient(circle, rgba(57, 255, 20, 0.1) 0%, transparent 70%)'
    }

class ForensicUXEngineV52:
    """v5.2 Forensic UX & Credibility Engine"""
    
    def __init__(self):
        self.theme = QuantumThemeV51() # Theme remains consistent
        
    def get_base_css(self) -> str:
        # (CSS content remains same as 5.1 but with authority refinements)
        return f'''
        :root {{
            --quantum-blue: {self.theme.COLORS['background']};
            --quantum-surface: {self.theme.COLORS['surface']};
            --gold: {self.theme.COLORS['gold']};
            --neon-green: {self.theme.COLORS['neon_green']};
            --text-primary: {self.theme.COLORS['text_primary']};
            --text-secondary: {self.theme.COLORS['text_secondary']};
            --border: {self.theme.COLORS['border']};
        }}
        
        * {{ margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', system-ui, sans-serif; }}
        body {{ background: var(--quantum-blue); color: var(--text-primary); min-height: 100vh; line-height: 1.6; overflow-x: hidden; }}
        
        .container {{ max-width: 1000px; margin: 0 auto; padding: 40px 20px; }}
        .card {{ background: var(--quantum-surface); border: 1px solid var(--border); border-radius: 12px; padding: 30px; margin-bottom: 30px; position: relative; overflow: hidden; }}
        
        h1, h2, h3 {{ font-weight: 700; letter-spacing: -0.02em; }}
        .gold-text {{ color: var(--gold); }}
        .green-text {{ color: var(--neon-green); }}
        
        .btn {{ padding: 14px 28px; border-radius: 8px; border: none; font-weight: 600; cursor: pointer; transition: 0.3s; display: inline-flex; align-items: center; gap: 10px; }}
        .btn-primary {{ background: var(--gold); color: var(--quantum-blue); }}
        .btn-outline {{ background: transparent; border: 1px solid var(--border); color: var(--text-primary); }}
        
        .seal-badge {{ display: inline-flex; align-items: center; gap: 8px; background: rgba(57, 255, 20, 0.1); border: 1px solid var(--neon-green); color: var(--neon-green); padding: 6px 14px; border-radius: 20px; font-size: 0.8rem; font-weight: 700; }}
        
        .stage {{ margin-bottom: 60px; }}
        '''

    def create_v52_dashboard_html(self, forensic_record: dict) -> str:
        """Generates the v5.2 FINAL Digital Notary Record Dashboard"""
        
        record = forensic_record['forensic_record']
        collision = record['collision_state']
        trust = record['trust_score']
        evidence = forensic_record['evidence_attribution']
        
        # Collision Header Logic
        collision_color = "#39FF14" if collision == "ALIGNED" else ("#FFD700" if collision == "PARTIAL_CONFLICT" else "#FF0033")
        collision_text = "KANIT BÜTÜNLÜĞÜ TEYİT EDİLDİ" if collision == "ALIGNED" else ("KISMİ KANIT UYUMSUZLUĞU" if collision == "PARTIAL_CONFLICT" else "ADLİ KANIT ÇELİŞKİSİ")

        # Trust Score Breakdown HTML
        trust_breakdown_html = ""
        for tag, weight in trust['breakdown'].items():
            trust_breakdown_html += f'''
            <div style="display: flex; justify-content: space-between; font-size: 0.8rem; margin-bottom: 5px;">
                <span style="opacity: 0.7;">{tag}</span>
                <span class="gold-text">+{weight}</span>
            </div>
            '''
        
        # Evidence Attribution HTML
        evidence_html = ""
        for ev in evidence:
            rank_label = f"Rank {ev['rank']}"
            evidence_html += f'''
            <div class="card" style="padding: 15px; margin-bottom: 10px; border-left: 4px solid {'var(--neon-green)' if ev['confidence'] > 0.5 else 'var(--border)'}">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 700; font-size: 0.8rem;">{ev['tag']} <span style="opacity: 0.5;">({rank_label})</span></span>
                    <span class="seal-badge" style="font-size: 0.6rem; padding: 2px 8px;">{ev['status']}</span>
                </div>
            </div>
            '''

        html = f'''
        <!DOCTYPE html>
        <html lang="tr">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>🏛️ YERİMEBAK – Antigravity v5.2 FINAL Notary Record</title>
            <style>
                {self.get_base_css()}
                .notary-header {{ border-bottom: 2px solid {collision_color}; padding-bottom: 20px; margin-bottom: 40px; text-align: center; }}
                .trust-score-large {{ font-size: 5rem; font-weight: 800; color: var(--gold); line-height: 1; }}
                .forensic-statement {{ font-size: 1.2rem; line-height: 1.6; text-align: justify; padding: 20px; background: rgba(255,255,255,0.03); border-radius: 8px; border-left: 4px solid var(--gold); }}
                .technical-details pre {{ background: #000; padding: 15px; border-radius: 8px; color: var(--neon-green); font-size: 0.7rem; overflow-x: auto; }}
            </style>
        </head>
        <body>
            <div class="container">
                
                <!-- DIGITAL NOTARY HEADER -->
                <div class="notary-header">
                    <div class="seal-badge" style="color: {collision_color}; border-color: {collision_color}; background: transparent; margin-bottom: 15px;">
                        🏛️ v5.2 FINAL – DIGITAL NOTARY RECORD
                    </div>
                    <h1 style="color: {collision_color}; letter-spacing: 2px;">{collision_text}</h1>
                    <p style="font-size: 0.8rem; opacity: 0.6; margin-top: 5px;">ID: {forensic_record['analysis_id']} | Record Established: {forensic_record['metadata']['timestamp'] if 'metadata' in forensic_record else 'N/A'}</p>
                </div>

                <div style="display: grid; grid-template-columns: 1fr 350px; gap: 30px;">
                    
                    <!-- LEFT COLUMN: RECORD & NARRATIVE -->
                    <div>
                        <section class="stage">
                            <h2 style="margin-bottom: 15px; opacity: 0.5; font-size: 0.9rem;">🏛️ BİLİRKİŞİ HÜKMÜ (FORENSIC STATEMENT)</h2>
                            <div class="forensic-statement">
                                {record['justification']}
                            </div>
                        </section>

                        <section class="stage">
                            <h2 style="margin-bottom: 20px; opacity: 0.5; font-size: 0.9rem;">🔍 KANIT ATIFLARI (EVIDENCE ATTRIBUTION)</h2>
                            {evidence_html}
                        </section>
                    </div>

                    <!-- RIGHT COLUMN: METRICS & SEALING -->
                    <div>
                        <div class="card" style="text-align: center;">
                            <h2 style="margin-bottom: 10px; font-size: 0.9rem; opacity: 0.7;">GÜVEN ENDEKSİ</h2>
                            <div class="trust-score-large">{int(trust['final_score']*100)}<span style="font-size: 1.5rem;">%</span></div>
                            <p style="font-size: 0.7rem; opacity: 0.5; margin-bottom: 20px;">Weighted Evidence Hektograms</p>
                            
                            <div style="text-align: left; border-top: 1px solid var(--border); padding-top: 15px;">
                                {trust_breakdown_html}
                                <div style="display: flex; justify-content: space-between; font-size: 0.8rem; margin-top: 10px; color: #ff0033;">
                                    <span>Sapma Cezası</span>
                                    <span>-{trust['penalties']}</span>
                                </div>
                            </div>
                        </div>

                        <div class="card" style="background: transparent; border-style: dashed;">
                            <h3 style="font-size: 0.8rem; margin-bottom: 15px;">🔒 SHA3-512 INTEGRITY SEAL</h3>
                            <pre style="font-size: 0.6rem; word-break: break-all; white-space: pre-wrap; opacity: 0.7;">{forensic_record['seal']}</pre>
                        </div>
                    </div>
                </div>

                <!-- TECHNICAL SHELTER -->
                <details class="technical-details" style="margin-top: 60px;">
                    <summary style="cursor: pointer; opacity: 0.4;">📁 VIEW FULL FORENSIC RECORD (JSON)</summary>
                    <pre>{json.dumps(forensic_record, indent=2, ensure_ascii=False)}</pre>
                </details>

                <div style="text-align: center; margin-top: 80px; padding-bottom: 40px;">
                    <p style="font-size: 0.7rem; opacity: 0.4; max-width: 600px; margin: 0 auto;">
                        Yasal Uyarı: Bu kayıt YerimeBak Antigravity v5.2 protokolü ile oluşturulmuştur. 
                        Sistem bir dijital noter olarak "kanıt gerçekliğini" mühürler. Karar merci kurumun kendisidir.
                    </p>
                </div>

            </div>
        </body>
        </html>
        '''
        return html
        return html

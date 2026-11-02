"""Ağ kullanmadan değerleme JSON'undan filigranlı örnek PDF üretir.

Kullanım: python scripts/ornek_rapor_pdf.py rapor.json ornek.pdf
"""
import argparse
import json
from pathlib import Path
import sys

# Betik, çalışma dizininden bağımsız olarak yerel PDF üreticisini bulur.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf


def main():
    parser = argparse.ArgumentParser(description='Değerleme JSON dosyasından çevrimdışı örnek PDF üretir.')
    parser.add_argument('json_path', type=Path, help='Değerleme JSON dosyası')
    parser.add_argument('pdf_path', type=Path, help='Oluşturulacak PDF dosyası')
    args = parser.parse_args()
    if args.json_path.resolve() == args.pdf_path.resolve():
        parser.error('Girdi JSON dosyası ile çıktı PDF dosyası farklı olmalı.')
    try:
        report = json.loads(args.json_path.read_text(encoding='utf-8-sig'))
        if not isinstance(report, dict):
            raise ValueError('JSON kökü bir rapor nesnesi olmalı.')
        content = build_pdf(report, ornek=True)
        args.pdf_path.write_bytes(content)
    except (OSError, ValueError, KeyError, TypeError, AttributeError, RuntimeError) as exc:
        parser.error(f'Örnek PDF üretilemedi; dosya yollarını ve rapor alanlarını kontrol edin: {exc}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

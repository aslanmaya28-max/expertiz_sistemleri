"""Örnek raporun kimliği, tüm sayfalardaki filigranı ve çevrimdışı üretimi."""
from copy import deepcopy
import io
import json
from pathlib import Path
import runpy
import socket
import subprocess
import sys

import pdfplumber
import pytest

from yerimebak_ai_v5.services import valuation_report_pdf as renderer

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'frontend/public/ornek-rapor/degerleme.json'
CLI = ROOT / 'scripts/ornek_rapor_pdf.py'


def source_report():
    return json.loads(SOURCE.read_text(encoding='utf-8'))


def texts(content):
    with pdfplumber.open(io.BytesIO(content)) as document:
        return [page.extract_text() for page in document.pages]


def test_sample_has_diagonal_watermark_on_every_page_and_no_identity_or_seal(monkeypatch):
    report = source_report()
    report['rapor'].update(verification_code='YD-SECRET-1234', report_no='CANLI-RAPOR-1234')
    unchanged = deepcopy(report)

    def forbidden_seal(*args, **kwargs):
        pytest.fail('Örnekte mühür oluşturulmamalı')

    monkeypatch.setattr(renderer, 'seal_png', forbidden_seal)
    content = renderer.build_pdf(report, ornek=True)
    with pdfplumber.open(io.BytesIO(content)) as document:
        assert len(document.pages) > 1
        for page in document.pages:
            # Döndürülmüş metin extract_text'te harflere ayrılabilir; gerçek
            # PDF karakterlerini kullanarak hem içerik hem açı doğrulanır.
            watermark = [char for char in page.chars if char['size'] > 40]
            assert ''.join(char['text'] for char in watermark) == 'ÖRNEK'
            assert all(abs(char['matrix'][1]) > 0.1 for char in watermark)
        text = '\n'.join(page.extract_text() for page in document.pages)
    assert 'Örnek rapordur, doğrulanamaz' in text
    for hidden in ('YD-SECRET-1234', 'CANLI-RAPOR-1234', 'Dijital doğrulama', '/dogrula/'):
        assert hidden not in text
    assert report == unchanged


def test_default_and_explicit_live_mode_keep_identity_and_seal(monkeypatch):
    report = source_report()
    report['rapor'].update(verification_code='YD-LIVE-1234', report_no='CANLI-1234')
    calls = []
    original = renderer.seal_png

    def seal(*args):
        calls.append(args)
        return original(*args)

    monkeypatch.setattr(renderer, 'seal_png', seal)
    default = texts(renderer.build_pdf(report))
    explicit = texts(renderer.build_pdf(report, ornek=False))
    assert default == explicit
    assert len(calls) == 2
    assert 'Dijital doğrulama' in '\n'.join(default)
    assert 'YD-LIVE-1234' in '\n'.join(default)
    assert 'Örnek rapordur, doğrulanamaz' not in '\n'.join(default)


def test_cli_uses_same_json_without_mutating_input(tmp_path):
    source = tmp_path / 'rapor.json'
    source.write_bytes(SOURCE.read_bytes())
    before = source.read_bytes()
    output = tmp_path / 'ornek.pdf'
    result = subprocess.run([sys.executable, str(CLI), str(source), str(output)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert source.read_bytes() == before
    assert texts(output.read_bytes()) == texts(renderer.build_pdf(source_report(), ornek=True))


@pytest.mark.parametrize('payload', ['{bozuk', '[]', '{"arac": {}}'])
def test_cli_reports_invalid_input_without_traceback(tmp_path, payload):
    source = tmp_path / 'hatali.json'
    source.write_text(payload, encoding='utf-8')
    output = tmp_path / 'ornek.pdf'
    result = subprocess.run([sys.executable, str(CLI), str(source), str(output)], capture_output=True)
    assert result.returncode != 0
    assert b'error:' in result.stderr
    assert b'PDF' in result.stderr
    assert b'Traceback' not in result.stderr
    assert not output.exists()


def test_cli_refuses_to_overwrite_input():
    before = SOURCE.read_bytes()
    result = subprocess.run([sys.executable, str(CLI), str(SOURCE), str(SOURCE)], capture_output=True)
    assert result.returncode != 0
    assert SOURCE.read_bytes() == before


def test_cli_does_not_open_network_connections(tmp_path, monkeypatch):
    def forbidden_network(*args, **kwargs):
        pytest.fail('Örnek PDF betiği ağ bağlantısı açmamalı')

    monkeypatch.setattr(socket.socket, 'connect', forbidden_network)
    monkeypatch.setattr(socket, 'create_connection', forbidden_network)
    output = tmp_path / 'ag-yok.pdf'
    monkeypatch.setattr(sys, 'argv', [str(CLI), str(SOURCE), str(output)])
    with pytest.raises(SystemExit) as result:
        runpy.run_path(str(CLI), run_name='__main__')
    assert result.value.code == 0
    assert output.read_bytes().startswith(b'%PDF')


def test_public_pdf_matches_current_json_and_contains_no_verification_identity():
    artifact = ROOT / 'frontend/public/ornek-rapor/degerleme-ornek.pdf'
    pages = texts(artifact.read_bytes())
    assert pages == texts(renderer.build_pdf(source_report(), ornek=True))
    text = '\n'.join(pages)
    for hidden in ('YD-', 'Dijital doğrulama', '/dogrula/'):
        assert hidden not in text

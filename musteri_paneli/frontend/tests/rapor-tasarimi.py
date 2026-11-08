"""032: gerçek örnek/kayıtlı rapor, mobil/print ve kopyalama denetimleri; ağ sahte."""
import json
import base64
import os
from pathlib import Path
import unittest
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('YERIMEBAK_PREVIEW_URL', 'http://127.0.0.1:3032')
FIXTURE = json.loads((Path(__file__).parents[1] / 'public/ornek-rapor/degerleme.json').read_text(encoding='utf-8'))


class ReportDesign(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = sync_playwright().start()
        cls.browser = cls.p.chromium.launch()

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.p.stop()

    def open(self, width=1440):
        context = self.browser.new_context(viewport={'width': width, 'height': 1000 if width > 1000 else 844}, reduced_motion='reduce')
        self.addCleanup(context.close)
        context.route('**/api/v1/**', lambda r: r.fulfill(status=200, json={'credits': 0, 'notifications': []}))
        page = context.new_page()
        errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.goto(BASE + '/ornek-rapor', wait_until='networkidle')
        self.assertFalse(errors)
        return page

    def test_layout_and_marker_boundaries(self):
        for width in (390, 1440):
            page = self.open(width)
            self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), width)
            report = page.locator('.yb-valuation')
            expect(report.get_by_role('heading', name='Fiat Egea', exact=True)).to_be_visible()
            expect(report.get_by_role('link', name='Doğrulama kodu:', exact=False)).to_have_count(0)
            expect(page.locator('[data-price="target"]')).to_have_text('646.000 ₺')
            expect(page.locator('[data-price="ceiling"]')).to_have_text('726.000 ₺')
            for marker in page.locator('[data-marker]').all():
                left = float(marker.evaluate('(e)=>e.style.left').rstrip('%'))
                self.assertGreaterEqual(left, 0)
                self.assertLessEqual(left, 100)
            for region in ['.yb-price-overview', '.yb-plan-overview', '.yb-analysis-overview']:
                columns = page.locator(region).evaluate('(e)=>getComputedStyle(e).gridTemplateColumns.split(" ").length')
                self.assertEqual(columns, 2 if width == 1440 else 1)
            for hidden in ['Hesaplanan eğilim', 'Veri güveni', 'EK DOĞRULAMA GEREKLİ']:
                self.assertNotIn(hidden, report.inner_text())

    def test_details_keyboard_copy_and_print(self):
        page = self.open(390)
        details = page.locator('.yb-risk-row details').first
        if details.count():
            summary = details.locator('summary')
            summary.focus()
            page.keyboard.press('Enter')
            expect(details).to_have_attribute('open', '')
            expect(details.locator('.yb-risk-detail')).to_be_visible()
            summary.press('Enter')
        page.evaluate('window.__copied = ""; Object.defineProperty(navigator, "clipboard", {value: {writeText: async (v)=>{window.__copied=v}}})')
        page.get_by_role('button', name='Kopyala', exact=True).click()
        expect(page.get_by_role('button', name='Kopyalandı', exact=True)).to_be_visible()
        self.assertEqual(page.evaluate('window.__copied'), FIXTURE['pazarlikPlani']['saticiMesaji'])
        link = page.locator('.yb-report-final a')
        self.assertIn('brand=Fiat', link.get_attribute('href'))
        page.emulate_media(media='print')
        expect(page.locator('.yb-report-header')).to_have_css('background-color', 'rgb(255, 255, 255)')
        if details.count():
            expect(details.locator('.yb-risk-detail')).to_be_visible()

    def test_saved_report_uses_same_design_with_real_verification_link(self):
        page = self.open(390)
        live = json.loads(json.dumps(FIXTURE))
        live['rapor'] = {**live['rapor'], 'id': '42', 'report_no': 'YD 2026-000042', 'verification_code': 'TEST42'}
        payload = base64.urlsafe_b64encode(json.dumps({'sub': 42, 'email': 'test@example.test', 'role': 'user', 'credits': 1}).encode()).decode().rstrip('=')
        token = 'test.' + payload + '.test'
        page.evaluate('(token)=>localStorage.setItem("yerimebak_token",token)', token)
        page.route('**/api/v1/valuation/reports/42', lambda r: r.fulfill(status=200, json=live))
        page.goto(BASE + '/panel/degerlemeler/42', wait_until='networkidle')
        header = page.get_by_role('banner', name='Değerleme raporu başlığı')
        # Nested report header is a named region through its aria-label, regardless of banner mapping.
        header = page.locator('.yb-report-header')
        expect(header).to_contain_text('YD 2026-000042')
        expect(header.get_by_role('link', name='Doğrulama kodu: TEST42')).to_have_attribute('href', '/dogrula/TEST42')
        self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), 390)


if __name__ == '__main__':
    unittest.main(verbosity=2)

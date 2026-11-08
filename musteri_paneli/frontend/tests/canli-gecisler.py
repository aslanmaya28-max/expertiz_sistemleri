"""031: gerçek CSS/kaydırma, kısa ekran ve hareket tercihi davranışları."""
import os
import unittest
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('YERIMEBAK_PREVIEW_URL', 'http://127.0.0.1:3031')


class CanliGecisler(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = sync_playwright().start()
        cls.browser = cls.p.chromium.launch()

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.p.stop()

    def open(self, route='/', width=1440, height=900, reduced=False, javascript=True):
        context = self.browser.new_context(viewport={'width': width, 'height': height},
            reduced_motion='reduce' if reduced else 'no-preference', java_script_enabled=javascript)
        self.addCleanup(context.close)
        context.route('**/api/v1/**', lambda r: r.fulfill(status=200, json={'credits': 0, 'notifications': []}))
        page = context.new_page()
        page.goto(BASE + route, wait_until='networkidle')
        if javascript:
            expect(page.locator('.yb-home')).to_have_attribute('data-motion', 'reduced' if reduced else 'ready')
        return page

    def test_stacking_desktop_mobile_and_service_pages(self):
        for route in ['/', '/arac-degerleme', '/yerinde-inceleme']:
            for width, height in [(1440, 900), (390, 844), (390, 700)]:
                page = self.open(route, width, height)
                card = page.locator('.yb-stack-card').first
                # Kural (ScrollSahnesi): yığın yalnız bütün kartlar ekrana sığıyorsa yapışır. 033 ile iç sayfalarda
                # yazı 17 px oldu; mobilde uzun hizmet kartları sığmaz ve okunabilirlik için normal akar (09.11.2026).
                sigar = page.evaluate('''() => [...document.querySelector('[data-stack]').querySelectorAll('.yb-stack-card')]
                    .every((c, i) => c.offsetHeight + 136 + i * 16 < innerHeight)''')
                expect(card).to_have_css('position', 'sticky' if height >= 800 and sigar else 'relative')
                if route == '/' or width > 1000:
                    self.assertTrue(height < 800 or sigar, f'{route} {width}x{height}: yığın yapışmalı')
                card.scroll_into_view_if_needed()
                self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), width)
                expect(card).to_be_visible()

    def test_reduced_motion_cancels_all_chapter_transforms_dynamically(self):
        page = self.open()
        page.locator('#raporlar').scroll_into_view_if_needed()
        page.emulate_media(reduced_motion='reduce')
        expect(page.locator('.yb-home')).to_have_attribute('data-motion', 'reduced')
        for selector in ['.yb-report', '.yb-benefit', '.yb-step-no', '.yb-expertise-copy', '.yb-faq-list', '.yb-final-cta']:
            for element in page.locator(selector).all():
                expect(element).to_have_css('transform', 'none')
                expect(element).to_have_css('opacity', '1')
        expect(page.locator('.yb-stack-card').first).to_have_css('position', 'relative')

    def test_service_content_visible_without_javascript(self):
        page = self.open('/arac-degerleme', javascript=False)
        for card in page.locator('.yb-stack-card').all():
            expect(card).to_have_css('position', 'relative')
            expect(card).to_have_css('opacity', '1')
        expect(page.get_by_role('heading', level=1)).to_contain_text('İlan fiyatı doğru mu?')

    def test_floating_header_and_mobile_escape_preserve_focus(self):
        page = self.open(width=390, height=844)
        page.evaluate('window.scrollTo(0, 500)')
        header = page.locator('.yb-header')
        expect(header).to_have_attribute('data-floating', 'true')
        toggle = header.get_by_role('button', name='Menüyü aç', exact=True)
        toggle.click()
        menu = page.get_by_role('navigation', name='Mobil menü', exact=True)
        expect(menu).to_be_visible()
        menu.get_by_role('link', name='Yerinde inceleme', exact=True).focus()
        page.keyboard.press('Escape')
        expect(menu).to_have_count(0)
        expect(header.get_by_role('button', name='Menüyü aç', exact=True)).to_be_focused()


if __name__ == '__main__':
    unittest.main(verbosity=2)

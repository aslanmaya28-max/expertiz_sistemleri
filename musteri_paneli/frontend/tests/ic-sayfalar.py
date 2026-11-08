"""033: yerel tasarım ve etkileşim denetimi; bütün API/oturum yanıtları sahte."""
import base64
import json
from pathlib import Path
import unittest
from playwright.sync_api import sync_playwright, expect

BASE = 'http://localhost:3033'


def reply(route):
    path = route.request.url
    data = {'credits': 5, 'notifications': [], 'requests': [], 'reports': [], 'movements': [], 'total': 0}
    if '/payments/packages' in path:
        data = {'packages': {'tek': {'name': 'Tek Rapor', 'credits': 1, 'price': 100, 'popular': False},
            'bes': {'name': '5 Rapor', 'credits': 5, 'price': 400, 'popular': True},
            'on': {'name': '10 Rapor', 'credits': 10, 'price': 750, 'popular': False}}}
    elif '/valuation/parts' in path:
        data = {'parts': [], 'statuses': [], 'cost_credits': 1}
    elif '/expertiz/packages' in path:
        data = {'service_fee_tl': 5000, 'vat_rate': .2, 'firms': [{'id': 'f1', 'name': 'Örnek Firma', 'packages': [
            {'id': 'p1', 'name': 'Örnek Paket', 'price_tl': 3000, 'features': ['Motor kontrolü']}]}]}
    elif '/auth/login' in path:
        return route.fulfill(status=401, json={'detail': 'Test giriş hatası'})
    elif '/valuation/generation' in path:
        data = {'bulundu': False}
    route.fulfill(status=200, json=data)


class InnerPages(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = sync_playwright().start()
        cls.browser = cls.p.chromium.launch()

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.p.stop()

    def page(self, path, width=390, authenticated=False, reduced=True):
        context = self.browser.new_context(viewport={'width': width, 'height': 900 if width > 1000 else 844}, reduced_motion='reduce' if reduced else 'no-preference')
        self.addCleanup(context.close)
        if authenticated:
            payload = base64.urlsafe_b64encode(json.dumps({'sub': 33, 'email': 'test@example.test', 'full_name': 'Örnek Kullanıcı', 'credits': 5, 'role': 'user'}).encode()).decode().rstrip('=')
            context.add_init_script('localStorage.setItem("yerimebak_token",' + json.dumps('test.' + payload + '.test') + ')')
        context.route('**/api/v1/**', reply)
        page = context.new_page()
        errors = []
        console_errors = []
        page.on('pageerror', lambda e: errors.append(str(e)))
        page.on('console', lambda message: console_errors.append(message.text) if message.type == 'error' else None)
        page.goto(BASE + path, wait_until='networkidle')
        self.assertFalse(errors, errors)
        self.assertFalse([message for message in console_errors if 'hydrat' in message.lower()], console_errors)
        if console_errors:
            (Path(__file__).parents[3] / 'kopru/log/033-console-errors.json').write_text(json.dumps(console_errors, ensure_ascii=False, indent=2), encoding='utf-8')
        return page

    def test_service_bands_faq_and_safe_mobile_layout(self):
        for path in ['/arac-degerleme', '/yerinde-inceleme', '/fiyatlar']:
            for width in [390, 1440]:
                page = self.page(path, width)
                self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), width, path)
                expect(page.locator('main .yb-band h1')).to_be_visible()
                expect(page.locator('main .yb-band h1')).to_have_css('color', 'rgb(255, 255, 255)')
                if path != '/fiyatlar':
                    self.assertEqual(page.locator('.yb-service-chips dd').count(), 4)
                    details = page.locator('#sorular details').first
                    details.locator('summary').click()
                    expect(details).to_have_attribute('open', '')
                    expect(details.locator('p')).to_be_visible()
                    page.emulate_media(media='print')
                    expect(page.locator('.yb-service-band')).to_have_css('background-color', 'rgb(255, 255, 255)')

    def test_forms_keep_touch_sizes_and_prefilled_values(self):
        for path, selector in [('/arac-analiz', 'input[aria-label="Kilometre"]'),
                ('/ekspertiz-talebi?brand=Fiat&model=Egea&year=2019&km=90000&price=800000', 'input[placeholder="65.000"]')]:
            page = self.page(path, authenticated=True)
            field = page.locator(selector)
            expect(field).to_have_css('font-size', '16px')
            self.assertGreaterEqual(field.bounding_box()['height'], 48)
            self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), 390)
            if path.startswith('/ekspertiz'):
                expect(field).to_have_value('90.000')
                expect(page.get_by_placeholder('Marka yazın veya seçin')).to_have_value('Fiat')

    def test_package_prices_links_and_account_hydration(self):
        page = self.page('/fiyatlar')
        popular = page.locator('.yb-package-card.yb-card-dark')
        expect(popular).to_contain_text('400 ₺')
        expect(popular.get_by_role('link', name='Satın Al')).to_have_attribute('href', '/kredi-yukle?paket=bes')
        page = self.page('/giris')
        page.get_by_label('E-posta', exact=True).fill('test@example.test')
        page.get_by_label('Şifre', exact=True).fill('test-password')
        page.get_by_role('button', name='Giriş yap', exact=True).click()
        expect(page.locator('.yb-form-error[role="alert"]')).to_have_text('Test giriş hatası')

    def test_info_auth_and_panel_mobile(self):
        for path in ['/giris', '/kayit-ol', '/panel', '/panel/degerlemeler', '/profil', '/dogrula', '/rehber', '/kvkk']:
            page = self.page(path, authenticated=path.startswith('/panel') or path == '/profil')
            self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'), 390, path)
            expect(page.locator('main h1')).to_be_visible()

    def test_print_keeps_dark_card_prices_and_credits_readable(self):
        for path, selector in [('/fiyatlar', '.yb-package-card.yb-card-dark .yb-big-number'),
                ('/panel', '.yb-card-dark .yb-big-number')]:
            page = self.page(path, authenticated=path == '/panel')
            page.emulate_media(media='print')
            number = page.locator(selector).first
            expect(number).to_have_css('color', 'rgb(16, 44, 54)')

    def test_account_story_contrast_and_mobile_visibility(self):
        page = self.page('/giris', width=1440)
        story = page.locator('.yb-account-story')
        expect(story.locator('h2')).to_have_css('color', 'rgb(255, 255, 255)')
        expect(story.locator('h2 em')).to_have_css('font-style', 'normal')
        page.set_viewport_size({'width': 390, 'height': 844})
        expect(story).not_to_be_visible()


if __name__ == '__main__':
    unittest.main(verbosity=2)

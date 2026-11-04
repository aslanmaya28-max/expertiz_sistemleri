"""019 web kabul testi; API taklit edilir, gerçek hesaba dokunulmaz.

YERIMEBAK_PREVIEW_URL=http://127.0.0.1:18819 python tests/hesap-silme-experience.py
"""
import base64
import json
import os
import time
import unittest
from pathlib import Path

from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('YERIMEBAK_PREVIEW_URL', 'http://127.0.0.1:18819')


class AccountDeletion(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runtime = sync_playwright().start()
        cls.browser = cls.runtime.chromium.launch()

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.runtime.stop()

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width': 1280, 'height': 960})
        self.page = self.context.new_page()
        self.calls = []
        self.errors = []
        self.page.on('pageerror', lambda error: self.errors.append(str(error)))
        self.context.route('**/api/v1/**', self.api)

    def tearDown(self):
        self.context.close()

    def api(self, route):
        request = route.request
        if request.url.endswith('/auth/delete-account'):
            self.calls.append(request)
            assert request.headers.get('authorization', '').startswith('Bearer ')
            assert request.method == 'POST'
            if request.post_data_json['password'] == 'wrong':
                route.fulfill(status=403, json={'detail': 'Şifreniz yanlış.'})
            else:
                assert request.post_data_json == {'password': 'Musteri123!'}
                route.fulfill(json={'success': True, 'message': 'Hesabınız silindi.'})
        elif request.url.endswith('/credits/balance'):
            route.fulfill(json={'credits': 5})
        else:
            route.fulfill(json={})

    def login(self, role='customer'):
        payload = {'sub': '19', 'email': 'sentetik@example.test', 'role': role,
                   'credits': 5, 'exp': int(time.time()) + 3600}
        encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')
        token = f'e30.{encoded}.test'
        self.page.add_init_script(f"localStorage.setItem('yerimebak_token', {json.dumps(token)})")

    def test_public_page_and_admin_restriction(self):
        self.page.goto(BASE + '/hesap-silme')
        expect(self.page.get_by_role('heading', name='YerimeBak hesabını silme')).to_be_visible()
        expect(self.page.get_by_role('link', name='Hesabınızı silmek için giriş yapın')).to_be_visible()
        expect(self.page.get_by_label('Şifreniz', exact=True)).to_have_count(0)
        self.login('admin')
        self.page.reload()
        expect(self.page.get_by_text('Admin ve personel hesapları için yöneticinizle iletişime geçin.')).to_be_visible()
        expect(self.page.get_by_label('Şifreniz', exact=True)).to_have_count(0)
        assert not self.errors, self.errors

    def test_password_confirmation_error_and_logout(self):
        self.login()
        self.page.goto(BASE + '/hesap-silme')
        submit = self.page.get_by_role('button', name='Hesabımı kalıcı olarak sil')
        expect(submit).to_be_disabled()
        password = self.page.get_by_label('Şifreniz', exact=True)
        password.fill('wrong')
        expect(submit).to_be_disabled()
        self.page.get_by_role('checkbox').check()
        submit.click()
        expect(self.page.get_by_role('alert').filter(has_text='Şifreniz yanlış.')).to_be_visible()
        assert self.page.evaluate("!!localStorage.getItem('yerimebak_token')")
        password.fill('Musteri123!')
        submit.click()
        expect(self.page.get_by_role('status').filter(has_text='Hesabınız silindi')).to_be_visible()
        assert self.page.evaluate("localStorage.getItem('yerimebak_token')") is None
        assert len(self.calls) == 2
        assert not self.errors, self.errors


if __name__ == '__main__':
    unittest.main()

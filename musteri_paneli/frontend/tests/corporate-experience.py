"""Browser acceptance checks. Every API request is intercepted; no DB or paid calls."""
import json
import os
import base64
import tempfile
import time
import unittest
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('YERIMEBAK_PREVIEW_URL', 'http://127.0.0.1:18802')
SHOTS = Path(os.environ.get('YERIMEBAK_SCREENSHOTS', str(Path(tempfile.gettempdir()) / 'yerimebak-corporate-review')))

class CorporateExperience(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p = sync_playwright().start()
        cls.browser = cls.p.chromium.launch()
        SHOTS.mkdir(exist_ok=True)

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.p.stop()

    def setUp(self):
        self.context = self.browser.new_context(viewport={'width':1440,'height':1050}, reduced_motion='reduce')
        self.page = self.context.new_page()
        self.errors = []
        self.page.on('pageerror', lambda e: self.errors.append(str(e)))
        self.calls = []
        self.register_success = False
        self.login_success = False
        self.package_reads = 0
        self.request_created = False
        self.context.route('**/api/v1/**', self.api)

    def api(self, route):
        request = route.request
        if request.url.endswith('/auth/login') and request.method == 'POST':
            self.calls.append(request.post_data_json)
            payload = base64.urlsafe_b64encode(json.dumps({'sub':'preview-only','email':'preview@example.test','exp':int(time.time())+3600,'role':'user'}).encode()).decode().rstrip('=')
            route.fulfill(status=200 if self.login_success else 401, json={'token':f'preview.{payload}.preview'} if self.login_success else {'detail':'E-posta veya şifre hatalı.'})
        elif request.url.endswith('/expertiz/requests/unpaid') and request.method == 'POST':
            self.assertTrue(request.headers.get('authorization','').startswith('Bearer '),'Request must belong to an authenticated account')
            self.request_created=True
            route.fulfill(status=200,json={'success':True,'request_id':'preview-request','payment_status':'not_collected'})
        elif request.url.endswith('/expertiz/requests'):
            route.fulfill(status=200,json={'requests':[{'id':'preview-request','status':'draft','city':'İstanbul','district':'Kadıköy','vehicle_json':{'brand':'Seat','model':'Arona'},'listing_snapshot':{'brand':'Seat','model':'Arona'},'firm_name':'Test firması','package_name':'Test paketi'}] if self.request_created else []})
        elif request.url.endswith('/expertiz/packages'):
            self.package_reads += 1
            route.fulfill(status=200,json={'service_fee_tl':100,'vat_rate':.2,'firms':[{'id':'test-firm','name':'Test firması','packages':[{'id':'test-package','name':'Test paketi','price':100,'features':[]}]}]})
        elif request.url.endswith('/auth/register') and request.method == 'POST':
            self.calls.append(request.post_data_json)
            route.fulfill(status=200 if self.register_success else 400, json={
                'message':'Test account created' if self.register_success else 'Bu e-posta adresi zaten kayıtlı.',
                'detail':'Bu e-posta adresi zaten kayıtlı.',
                **({'token':self.fake_token()} if self.register_success else {})})
        else:
            route.fulfill(status=200,json={'vehicles':[], 'stats':{}, 'credits':0, 'notifications':[]})

    def tearDown(self):
        self.assertEqual(self.errors, [], 'Unhandled browser error')
        self.context.close()

    def fake_token(self):
        payload=base64.urlsafe_b64encode(json.dumps({'sub':'preview-only','email':'preview@example.test','exp':int(time.time())+3600,'role':'user'}).encode()).decode().rstrip('=')
        return f'preview.{payload}.preview'

    def test_guest_request_requires_registration_before_loading_form(self):
        self.page.goto(BASE+'/ekspertiz-talebi?aracId=123',wait_until='networkidle')
        expect(self.page).to_have_url(BASE+'/kayit-ol?donus=%2Fekspertiz-talebi%3FaracId%3D123')
        self.assertEqual(self.package_reads,0,'No request data is loaded before membership')
        expect(self.page.get_by_role('heading',name='Önce hesabınızı oluşturun.',exact=True)).to_be_visible()
        expect(self.page.get_by_role('link',name='Giriş yapın',exact=True).last).to_have_attribute('href','/giris?donus=%2Fekspertiz-talebi%3FaracId%3D123')

    def test_registered_customer_can_continue_to_request_and_track_in_panel(self):
        self.page.goto(BASE+'/kayit-ol?donus=%2Fekspertiz-talebi',wait_until='networkidle')
        for label,value in [('Ad','Deneme'),('Soyad','Müşteri'),('E-posta','preview@example.test'),('Telefon','05550000000'),('Şifre','Deneme123!')]:
            self.page.get_by_label(label,exact=True).fill(value)
        self.page.get_by_role('checkbox').check()
        self.register_success=True
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        expect(self.page.get_by_role('heading',name='Hesabınız oluşturuldu',exact=True)).to_be_visible()
        self.page.get_by_role('link',name='İnceleme talebi oluştur',exact=True).first.click()
        expect(self.page).to_have_url(BASE+'/ekspertiz-talebi')
        expect(self.page.get_by_role('heading',name='Ekspertiz ve Raporlama Talebi',exact=True)).to_be_visible()
        self.assertGreater(self.package_reads,0)
        self.page.get_by_label('Marka (zorunlu)',exact=True).fill('Seat')
        self.page.get_by_label('Model (zorunlu)',exact=True).fill('Arona')
        self.page.get_by_label('Aracın bulunduğu il (zorunlu)').select_option(label='İstanbul')
        self.page.get_by_label('İlçe (zorunlu)',exact=True).fill('Kadıköy')
        self.page.get_by_role('button',name='Devam',exact=True).click()
        self.page.get_by_role('button',name='Devam',exact=True).click()
        self.page.get_by_role('button').filter(has_text='Test paketi').first.click()
        self.page.get_by_role('button',name='Devam',exact=True).click()
        self.page.get_by_role('button',name='Talep oluştur',exact=True).click()
        expect(self.page.get_by_role('heading',name='Ekspertiz talebiniz alındı',exact=True)).to_be_visible()
        self.page.get_by_role('link',name='Panelde takip et',exact=True).click()
        expect(self.page).to_have_url(BASE+'/panel')
        expect(self.page.get_by_role('heading',name='Araç dosyanız, elinizin altında.',exact=True)).to_be_visible()
        expect(self.page.get_by_text('Kadıköy',exact=False).first).to_be_visible()

    def test_home_explains_service_and_real_coverage(self):
        self.page.goto(BASE,wait_until='networkidle')
        expect(self.page.get_by_role('heading',level=1)).to_contain_text('Siz gitmeden')
        for label in ['İç ekspertiz raporu','Dış ekspertiz raporu','Yapay zekâ değerleme raporu','Kurumsal ekspertiz raporu']:
            expect(self.page.get_by_role('heading',name=label,exact=True)).to_be_visible()
        expect(self.page.get_by_text('İstanbul’da pilot hizmet',exact=True).first).to_be_visible()
        expect(self.page.get_by_role('heading',name='Misyonumuz',exact=True)).to_be_visible()
        expect(self.page.get_by_role('heading',name='Vizyonumuz',exact=True)).to_be_visible()
        expect(self.page.locator('#gelecek-hizmetler')).to_contain_text('Planlanan hizmetler')
        expect(self.page.locator('#gelecek-hizmetler')).to_contain_text('Vekâleten araç satın alma')
        self.assertEqual(self.page.get_by_text('1.250',exact=True).count(),0)
        expect(self.page.get_by_role('link',name='İnceleme talebi oluştur',exact=True).first).to_have_attribute('href','/kayit-ol?donus=%2Fekspertiz-talebi')
        self.page.screenshot(path=str(SHOTS/'home-desktop.png'),full_page=True)

    def test_mobile_menu_and_no_horizontal_overflow(self):
        for width in [360,390,768]:
            self.page.set_viewport_size({'width':width,'height':844})
            self.page.goto(BASE,wait_until='networkidle')
            self.assertLessEqual(self.page.evaluate('document.documentElement.scrollWidth'),width)
            button=self.page.locator('button[aria-controls="mobil-menu"]')
            expect(button).to_be_visible()
            button.click()
            expect(button).to_have_attribute('aria-expanded','true')
            self.page.get_by_role('navigation',name='Mobil menü').get_by_role('link',name='Nasıl çalışır?',exact=True).click()
            expect(self.page.get_by_role('button',name='Menüyü aç',exact=True)).to_have_attribute('aria-expanded','false')
        self.page.set_viewport_size({'width':390,'height':844})
        self.page.goto(BASE,wait_until='networkidle')
        self.page.screenshot(path=str(SHOTS/'home-phone.png'),full_page=True)

    def test_registration_payload_error_and_success(self):
        self.page.goto(BASE+'/kayit-ol',wait_until='networkidle')
        self.page.get_by_label('Ad',exact=True).fill('Deneme')
        self.page.get_by_label('Soyad',exact=True).fill('Müşteri')
        self.page.get_by_label('E-posta',exact=True).fill('preview@example.test')
        self.page.get_by_label('Telefon',exact=False).fill('05550000000')
        self.page.get_by_label('Şifre',exact=True).fill('Deneme123!')
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        self.assertEqual(self.calls,[], 'Consent must still be required')
        self.page.get_by_role('checkbox').check()
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        expect(self.page.locator('form').get_by_role('alert')).to_contain_text('zaten kayıtlı')
        self.assertEqual(self.calls[-1],{'email':'preview@example.test','password':'Deneme123!','full_name':'Deneme Müşteri','phone':'05550000000','terms_accepted':True})
        self.register_success=True
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        expect(self.page.get_by_role('heading',name='Hesabınız oluşturuldu',exact=True)).to_be_visible()
        expect(self.page.get_by_role('link',name='Panelime git',exact=True)).to_have_attribute('href','/panel')

    def test_registration_requires_email_and_phone(self):
        self.page.goto(BASE+'/kayit-ol',wait_until='networkidle')
        phone=self.page.get_by_label('Telefon',exact=True)
        expect(phone).to_have_attribute('required','')
        expect(self.page.get_by_label('E-posta',exact=True)).to_have_attribute('required','')
        self.page.get_by_label('Ad',exact=True).fill('Deneme')
        self.page.get_by_label('Soyad',exact=True).fill('Müşteri')
        self.page.get_by_label('E-posta',exact=True).fill('preview@example.test')
        self.page.get_by_label('Şifre',exact=True).fill('Deneme123!')
        self.page.get_by_role('checkbox').check()
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        self.assertEqual(self.calls,[],'Phone cannot be omitted')
        self.assertFalse(phone.evaluate('(e)=>e.checkValidity()'))
        phone.fill('telefon')
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        self.assertEqual(self.calls,[],'Non-numeric phone cannot be submitted')
        phone.fill('0555 000 00 00')
        self.page.get_by_role('button',name='Kayıt ol',exact=True).click()
        expect(self.page.locator('form').get_by_role('alert')).to_contain_text('zaten kayıtlı')
        self.assertEqual(self.calls[-1]['phone'],'0555 000 00 00')

    def test_auth_pages_mobile_labels_and_keyboard(self):
        for path in ['/kayit-ol','/giris']:
            self.page.set_viewport_size({'width':390,'height':844})
            self.page.goto(BASE+path,wait_until='networkidle')
            self.assertLessEqual(self.page.evaluate('document.documentElement.scrollWidth'),390)
            expect(self.page.get_by_label('E-posta',exact=True)).to_be_visible()
            self.page.get_by_label('E-posta',exact=True).focus()
            expect(self.page.get_by_label('E-posta',exact=True)).to_be_focused()
            self.page.evaluate('document.activeElement.blur();window.scrollTo(0,0)')
            self.page.screenshot(path=str(SHOTS/(path.strip('/')+'-phone.png')),full_page=True)

    def test_login_error_then_customer_dashboard(self):
        self.page.goto(BASE+'/giris',wait_until='networkidle')
        self.page.get_by_label('E-posta',exact=True).fill('preview@example.test')
        self.page.get_by_label('Şifre',exact=True).fill('Deneme123!')
        self.page.get_by_role('button',name='Giriş yap',exact=True).click()
        expect(self.page.locator('form').get_by_role('alert')).to_contain_text('şifre hatalı')
        self.login_success=True
        self.page.get_by_role('button',name='Giriş yap',exact=True).click()
        expect(self.page).to_have_url(BASE+'/panel')
        expect(self.page.get_by_role('heading',name='Araç dosyanız, elinizin altında.',exact=True)).to_be_visible()
        expect(self.page.get_by_role('button',name='Raporlarım',exact=True)).to_be_visible()
        self.assertEqual(self.calls[-1], {'email':'preview@example.test','password':'Deneme123!'})
        self.page.screenshot(path=str(SHOTS/'customer-dashboard-desktop.png'),full_page=True)
        self.page.set_viewport_size({'width':390,'height':844})
        self.assertLessEqual(self.page.evaluate('document.documentElement.scrollWidth'),390)
        self.page.screenshot(path=str(SHOTS/'customer-dashboard-phone.png'),full_page=True)

    def test_faq_and_keyboard_menu(self):
        self.page.goto(BASE,wait_until='networkidle')
        question=self.page.locator('summary').filter(has_text='Raporlarıma nereden ulaşırım?')
        question.focus()
        self.page.keyboard.press('Enter')
        expect(question.locator('..')).to_have_attribute('open','')
        expect(question.locator('..')).to_contain_text('müşteri panelinizde')
        self.page.set_viewport_size({'width':390,'height':844})
        toggle=self.page.locator('button[aria-controls="mobil-menu"]')
        toggle.focus()
        self.page.keyboard.press('Enter')
        expect(toggle).to_have_attribute('aria-expanded','true')
        self.page.keyboard.press('Escape')
        expect(toggle).to_have_attribute('aria-expanded','false')

    def test_login_internal_return_and_external_return_rejection(self):
        from urllib.parse import quote
        self.login_success=True
        for target, expected in [('/hakkimizda','/hakkimizda'),('https://example.invalid','/panel'),('//example.invalid','/panel')]:
            self.page.goto(BASE+'/giris?donus='+quote(target,safe=''),wait_until='networkidle')
            self.page.get_by_label('E-posta',exact=True).fill('preview@example.test')
            self.page.get_by_label('Şifre',exact=True).fill('Deneme123!')
            self.page.get_by_role('button',name='Giriş yap',exact=True).click()
            expect(self.page).to_have_url(BASE+expected)

if __name__=='__main__': unittest.main(verbosity=2)

"""Real scroll/lifecycle checks. No model calls or database writes."""
import os
import tempfile
import unittest
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

BASE = os.environ.get('YERIMEBAK_PREVIEW_URL', 'http://127.0.0.1:18802')
SHOTS = Path(os.environ.get('YERIMEBAK_SCREENSHOTS', str(Path(tempfile.gettempdir())/'yerimebak-scroll-review')))

class ScrollExperience(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.p=sync_playwright().start()
        cls.browser=cls.p.chromium.launch()
        SHOTS.mkdir(exist_ok=True)
    @classmethod
    def tearDownClass(cls):
        cls.browser.close(); cls.p.stop()
    def open(self, width=1440, reduced=False, javascript=True, block_engine=False):
        context=self.browser.new_context(viewport={'width':width,'height':900 if width>760 else 844},reduced_motion='reduce' if reduced else 'no-preference',java_script_enabled=javascript)
        self.addCleanup(context.close)
        context.add_init_script("Element.prototype.requestPointerLock=()=>{throw Error('Pointer lock is forbidden')};Element.prototype.setPointerCapture=()=>{throw Error('Pointer capture is forbidden')}")
        context.route('**/api/v1/**',lambda route:route.fulfill(status=200,json={'credits':0,'vehicles':[],'notifications':[]}))
        if block_engine: context.route('**/vendor/scrollcraft/scrollcraft.js',lambda route:route.abort())
        page=context.new_page()
        page.goto(BASE,wait_until='networkidle')
        return page
    def test_actual_engine_and_spa_cleanup(self):
        page=self.open()
        page.wait_for_function('window.ScrollCraft?.instances.length===1')
        expect(page.locator('header .yb-brand svg')).to_be_visible()
        self.assertEqual(page.locator('header img[src*="logo-yerimebak"]').count(),0)
        before=page.locator('.yb-hero-photo-plane').evaluate('(e)=>getComputedStyle(e).transform')
        page.evaluate('window.scrollTo({top:240,behavior:"instant"})')
        page.wait_for_timeout(120)
        after=page.locator('.yb-hero-photo-plane').evaluate('(e)=>getComputedStyle(e).transform')
        foreground=page.locator('.yb-hero-detail').evaluate('(e)=>getComputedStyle(e).transform')
        self.assertNotEqual(before,after,'Hero photograph must actually respond to scroll')
        self.assertNotEqual(after,foreground,'Hero photograph and cockpit must move independently')
        page.evaluate('window.scrollTo({top:0,behavior:"instant"})')
        for _ in range(2):
            page.locator('header').get_by_role('link',name='Kayıt ol',exact=True).click()
            page.wait_for_function('window.ScrollCraft?.instances.length===0')
            page.locator('header').get_by_role('link',name='YerimeBak ana sayfa',exact=True).click()
            page.wait_for_function('window.ScrollCraft?.instances.length===1')
    def test_report_scroll_changes_and_reaches_resolved_state(self):
        page=self.open()
        page.wait_for_function('window.ScrollCraft?.instances.length===1')
        scene=page.locator('[data-report-scene]')
        box=scene.bounding_box()
        top=box['y']+page.evaluate('window.scrollY')
        height=box['height']
        states=[]
        for i,progress in enumerate([0,.25,.5,.75,1]):
            page.evaluate('(y)=>window.scrollTo({top:y,behavior:"instant"})',top+(height-900)*progress)
            page.wait_for_timeout(180)
            states.append(page.locator('.yb-report-paper-0').evaluate('(e)=>getComputedStyle(e).transform'))
            page.screenshot(path=str(SHOTS/f'reports-desktop-{i}.png'))
        self.assertGreater(len(set(states)),3)
        self.assertNotEqual(states[-2],states[-1], 'The final scroll segment must still visibly assemble reports')
        self.assertGreater(float(page.evaluate('(e)=>getComputedStyle(e).getPropertyValue("--sc-p")',scene.element_handle())),.9)
        expect(scene).to_contain_text('Müşteri paneliniz')
    def test_mobile_and_reduced_motion_stay_readable(self):
        for width,reduced in [(390,False),(360,True),(1440,True)]:
            page=self.open(width,reduced)
            if not reduced: page.wait_for_function('window.ScrollCraft?.instances.length===1')
            self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'),width)
            for target in ['.yb-hero','[data-report-scene]','#nasil-calisir']:
                element=page.locator(target)
                element.scroll_into_view_if_needed()
                page.wait_for_timeout(250)
                self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'),width)
                if target=='[data-report-scene]':
                    expect(element).to_contain_text('Müşteri paneliniz')
                    if reduced or width<761:
                        self.assertEqual(page.locator('.yb-dossier-stage').evaluate('(e)=>getComputedStyle(e).position'),'relative')
            page.evaluate('window.scrollTo({top:0,behavior:"instant"})')
            page.screenshot(path=str(SHOTS/f'home-{width}-reduce-{reduced}.png'))
    def test_missing_javascript_or_engine_keeps_content(self):
        for javascript,blocked in [(False,False),(True,True)]:
            page=self.open(javascript=javascript,block_engine=blocked)
            expect(page.get_by_role('heading',level=1)).to_contain_text('Siz gitmeden')
            expect(page.get_by_role('link',name='İnceleme talebi oluştur',exact=True).first).to_be_visible()
            scene=page.locator('[data-report-scene]')
            expect(scene).to_contain_text('Müşteri paneliniz')
            self.assertEqual(page.locator('.yb-dossier-stage').evaluate('(e)=>getComputedStyle(e).position'),'relative')

    def test_whole_page_has_visible_scroll_motion_and_inspection_photo(self):
        page=self.open()
        page.wait_for_function('window.ScrollCraft?.instances.length===1')
        expect(page.get_by_alt_text('Liftteki aracı kontrol eden personel, temsili görsel')).to_be_visible()
        for section,child in [('#hizmetimiz','.yb-benefit'),('#raporlar','.yb-report'),('#nasil-calisir','.yb-step-no'),('.yb-expertise','.yb-expertise-image img'),('#hakkimizda','.yb-coverage'),('.yb-faq-section','.yb-faq-list'),('.yb-final-section','.yb-final-cta')]:
            parent=page.locator(section)
            self.assertEqual(parent.get_attribute('data-page-motion'),'true',section)
            rect=parent.bounding_box()
            top=rect['y']+page.evaluate('window.scrollY')
            states=[]
            for y in [top-675,top+rect['height']*.25-180]:
                page.evaluate('(y)=>window.scrollTo({top:y,behavior:"instant"})',y)
                page.wait_for_timeout(180)
                states.append(parent.locator(child).first.evaluate('(e)=>getComputedStyle(e).transform'))
            self.assertNotEqual(states[0],states[1],section+' must visibly animate')
            page.screenshot(path=str(SHOTS/(section.strip('#.').replace('-','_')+'-motion.png')))
        page.set_viewport_size({'width':390,'height':844})
        for section in ['#hizmetimiz','#raporlar','#nasil-calisir','.yb-expertise','#hakkimizda','.yb-faq-section','.yb-final-section']:
            page.locator(section).scroll_into_view_if_needed()
            page.wait_for_timeout(200)
            self.assertLessEqual(page.evaluate('document.documentElement.scrollWidth'),390,section)
            if section in ['#hakkimizda','.yb-faq-section']:
                page.screenshot(path=str(SHOTS/(section.strip('#.').replace('-','_')+'-phone.png')))

    def test_short_desktop_and_dynamic_motion_preference(self):
        page=self.open(1024)
        page.wait_for_function('window.ScrollCraft?.instances.length===1')
        page.set_viewport_size({'width':1024,'height':400})
        page.locator('[data-report-scene]').scroll_into_view_if_needed()
        expect(page.locator('.yb-dossier-stage')).to_have_css('position','relative')
        page.set_viewport_size({'width':1440,'height':900})
        expect(page.locator('.yb-dossier-stage')).to_have_css('position','sticky')
        page.emulate_media(reduced_motion='reduce')
        page.wait_for_function('window.ScrollCraft.instances.length===0')
        expect(page.locator('.yb-dossier-stage')).to_have_css('position','relative')
        page.emulate_media(reduced_motion='no-preference')
        page.wait_for_function('window.ScrollCraft.instances.length===1')

if __name__=='__main__': unittest.main(verbosity=2)

"""Gerçek uygulama PNG'sini SVG kompozisyonuna gömüp Chromium ile render eder.

Çalıştırma: python magaza/one-cikan-uret.py (musteri_uygulamasi içinden).
Gereksinim: playwright ve Chromium. Ekran görüntüsünün içeriği değiştirilmez.
"""
import asyncio
import base64
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
    folder = Path(__file__).resolve().parent
    shot = folder/'ekranlar/03-rapor-basi.png'
    data = 'data:image/png;base64,'+base64.b64encode(shot.read_bytes()).decode('ascii')
    svg = (folder/'one-cikan-1024x500.svg').read_text('utf-8')
    svg = svg.replace('ekranlar/03-rapor-basi.png', data)
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width':1024,'height':500},device_scale_factor=1)
        await page.set_content('<!doctype html><html><head><meta charset="utf-8">'
          '<style>html,body{margin:0;width:1024px;height:500px;overflow:hidden}svg{display:block}</style>'
          '</head><body>'+svg+'</body></html>')
        await page.evaluate('''async (src) => {
          const img = new Image(); img.src=src; await img.decode();
          await document.fonts.ready;
          await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));
        }''',data)
        await page.screenshot(path=str(folder/'one-cikan-1024x500.png'))
        await browser.close()
    print('1024×500 öne çıkan görsel üretildi.')

if __name__=='__main__':
    asyncio.run(main())

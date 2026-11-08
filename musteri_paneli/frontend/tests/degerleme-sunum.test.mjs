import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const localRequire = createRequire(import.meta.url);
const dependency = (name) => localRequire(name);
const ts = dependency('typescript');
const React = dependency('react');
const { renderToStaticMarkup } = dependency('react-dom/server');

function load(relative) {
  const filename = resolve(here, '../src', relative);
  const source = ts.transpileModule(readFileSync(filename, 'utf8'), {
    compilerOptions: { jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText;
  const module = { exports: {} };
  const require = (name) => {
    if (name === 'next/link') return { default: ({ children, ...props }) => React.createElement('a', props, children) };
    if (name === './AkilliAliciBolumleri') return load('bilesenler/AkilliAliciBolumleri.tsx');
    if (['./Ikon', './Marka', './RaporBasligi', './FiyatOzeti'].includes(name)) return load(`bilesenler/${name.slice(2)}.tsx`);
    if (name === '@/lib/ekspertizOnDoldurma') return load('lib/ekspertizOnDoldurma.ts');
    return dependency(name);
  };
  vm.runInNewContext(source, { module, exports: module.exports, require, URL, URLSearchParams }, { filename });
  return module.exports;
}

const { default: DegerlemeSonucu } = load('bilesenler/DegerlemeSonucu.tsx');
const { AkilliAliciBolumleri } = load('bilesenler/AkilliAliciBolumleri.tsx');
const result = {
  arac: { marka: 'Hyundai', model: 'Tucson', yil: 2021, km: 66000, ilanFiyati: 2200000 },
  piyasa: { emsalSayisi: 5, kaynaklar: [], uyarilar: [], guvenSkoru: 35 },
  degerleme: { kalemler: [] },
  karar: { sonuc: 'EK DOĞRULAMA GEREKLİ', aciklama: 'YALNIZ ADMIN', hesaplananEgilim: 'ALMA', guvenSeviyesi: 'dusuk' },
  kredi: { dusulen: 1, kalan: 5 },
};
const render = (Component, sonuc) => renderToStaticMarkup(React.createElement(Component, { sonuc }));

test('ekspertiz kaynağı ve ciddi/kozmetik bulgular web raporunda aynı metinle görünür', () => {
  const html = render(DegerlemeSonucu, { ...result, ekspertizRaporu: {
    aciklama: 'Ekspertiz raporu (Sentetik, 2026-11-05) — YerimeBak uzmanı tarafından doğrulanmadı',
    bulgular: [{ ciddiyet: 'ciddi', metin: 'Motorda yağ kaçağı' },
              { ciddiyet: 'pazarlik', metin: 'Tamponda çizik' },
              { ciddiyet: 'bilgi', metin: 'Lastik kontrolü önerilir' }],
  } });
  assert.ok(html.includes('YerimeBak uzmanı tarafından doğrulanmadı'));
  assert.ok(html.includes('Yerinde doğrulatın: Motorda yağ kaçağı'));
  assert.ok(html.includes('Kozmetik / küçük onarım: Tamponda çizik'));
  assert.ok(html.includes('Bilgi: Lastik kontrolü önerilir'));
});

test('yeni risk görünümü altı kategori, kanıt, kaynaklı masraf ve kilometreyi gösterir', () => {
  const titles = ['Motor', 'Şanzıman', 'Kaporta', 'Alt takım', 'Elektronik', 'Diğer'];
  const keys = ['motor', 'sanziman', 'kaporta', 'alt_takim', 'elektronik', 'diger'];
  const risks = keys.map((kategori, i) => ({ baslik: `Başlık ${i}`, kategori, guven: 'orta',
    onem: 'orta', kontrol: 'Servis kaydı', kaynaklar: ['https://servis.test/risk'],
    kanitSeviyesi: 'Teknik kaynak', ...(i === 1 ? {
      tahminiMaliyet: { min: 25000, max: 30000 }, tipikKm: { min: 80000, max: 100000 },
      kilometreUyarisi: 'Bu kilometrede dikkat',
      maliyetKaynagi: { url: 'https://servis.test/fiyat', tarih: '2026-11-05', onarim: 'Mekatronik onarımı' },
    } : {}) }));
  const html = render(AkilliAliciBolumleri, { ...result, modelRiskleri: { gorunumSurumu: 2, riskler: risks },
    kullaniciSikayetleri: [{ baslik: 'Şikâyet', kategori: 'motor', kaynakSayisi: 2, kaynaklar: [],
      tahminiMaliyet: { min: 9999, max: 9999 } }] });
  assert.ok(html.includes('Bu araçta dikkat edilecekler'));
  for (const title of titles) assert.ok(html.includes(`>${title}</h3>`));
  assert.ok(html.includes('25.000–30.000 TL'));
  assert.ok(html.includes('80.000–100.000 km'));
  assert.ok(html.includes('Bu kilometrede dikkat'));
  assert.ok(html.includes('href="https://servis.test/fiyat"'));
  assert.ok(html.includes('Erişim: 2026-11-05'));
  assert.ok(html.includes('Teknik kaynak') && html.includes('Kullanıcı deneyimi'));
  assert.ok(!html.includes('9.999'));
  assert.ok(html.includes('kaynakta belirtilmemiş'));
});

const risk = (baslik, extra = {}) => ({ baslik, belirtiler: [], kontrol: 'Servise sorun', kaynaklar: [], guven: 'orta', ...extra });
const complaint = (baslik, extra = {}) => ({ baslik, aciklama: 'Kullanıcı beyanı', kaynakSayisi: 2, kaynaklar: [], ...extra });
const section = (html, title) => html.match(new RegExp(`<section[^>]*aria-label="${title}"[^>]*>([\\s\\S]*?)</section>`))?.[1] || '';
const criticalTitle = 'Bu araçta en çok dikkat etmeniz gerekenler';
const expertText = 'YerimeBak uzmanı bunu yerinde kontrol eder.';

test('iki listede gruplar ve önem sırası korunur, girdi değişmez', () => {
  const items = [
    { baslik: 'Kasa düşük', kategori: 'trim_kasa', onem: 'dusuk' },
    { baslik: 'Motor düşük', kategori: 'mekanik_motor', onem: 'dusuk' },
    { baslik: 'Elektronik orta', kategori: 'elektronik', onem: 'orta' },
    { baslik: 'Motor yüksek', kategori: 'mekanik_motor', onem: 'yuksek' },
    { baslik: 'Motor orta', kategori: 'mekanik_motor', onem: 'orta' },
  ];
  const sonuc = { ...result, modelRiskleri: { riskler: items.map(i => risk(i.baslik, i)) }, kullaniciSikayetleri: items.map(i => complaint(i.baslik, i)) };
  const original = JSON.stringify(sonuc);
  const html = render(AkilliAliciBolumleri, sonuc);
  for (const title of ['Modelin bilinen sorunları', 'Kullanıcıların en sık şikâyet ettiği konular']) {
    const part = section(html, title);
    const ordered = ['Mekanik ve motor', 'Motor yüksek', 'Motor orta', 'Motor düşük', 'Elektronik ve sensör', 'Elektronik orta', 'Trim, şasi ve kasa', 'Kasa düşük'];
    ordered.forEach((text, i) => { assert.ok(part.includes(text), text); if (i) assert.ok(part.indexOf(ordered[i - 1]) < part.indexOf(text), text); });
    // 032: semantik rozet sınıfları ortak marka tokenlarını kullanır; önem/metin değişmez.
    assert.match(part, /yb-risk-high[^>]*>Yüksek masraf/);
    assert.match(part, /yb-risk-medium[^>]*>Orta/);
    assert.match(part, /yb-risk-small[^>]*>Küçük \/ konfor/);
  }
  assert.equal(JSON.stringify(sonuc), original);
});

test('boş grup yok; eski ve kısmi kategorili listeler hiçbir madde kaybetmeden grupsuz kalır', () => {
  const grouped = render(AkilliAliciBolumleri, { ...result, kullaniciSikayetleri: [complaint('Sensör', { kategori: 'elektronik' })] });
  assert.ok(grouped.includes('Elektronik ve sensör'));
  assert.ok(!grouped.includes('Mekanik ve motor'));
  assert.ok(!grouped.includes('Trim, şasi ve kasa'));
  for (const extra of [{}, { kategori: 'elektronik', onem: 'dusuk' }]) {
    const html = render(AkilliAliciBolumleri, { ...result, modelRiskleri: { riskler: [risk('Eski risk'), risk('Kısmi risk', extra)] }, kullaniciSikayetleri: [complaint('Eski şikâyet'), complaint('Kısmi şikâyet', extra)] });
    for (const title of ['Eski risk', 'Kısmi risk', 'Eski şikâyet', 'Kısmi şikâyet']) assert.ok(html.includes(title));
    for (const title of ['Mekanik ve motor', 'Elektronik ve sensör', 'Trim, şasi ve kasa', criticalTitle, expertText]) assert.ok(!html.includes(title));
  }
});

test('kritik kutu doğrulanmış yüksek sorunu önce seçer ve kalan yeri en kaynaklı yüksek şikâyetle doldurur', () => {
  const html = render(AkilliAliciBolumleri, { ...result, modelRiskleri: { riskler: [risk('Gizli risk', { guven: 'dusuk', onem: 'yuksek' }), risk('Doğrulanmış risk', { onem: 'yuksek' })] }, kullaniciSikayetleri: [complaint('Az kaynak', { onem: 'yuksek' }), complaint('Çok kaynak', { onem: 'yuksek', kaynakSayisi: 8 }), complaint('Orta kaynak', { onem: 'yuksek', kaynakSayisi: 4 })] });
  const critical = section(html, criticalTitle);
  assert.ok(critical.includes('Doğrulanmış risk'));
  assert.ok(critical.includes('Çok kaynak'));
  assert.ok(critical.indexOf('Doğrulanmış risk') < critical.indexOf('Çok kaynak'));
  for (const text of ['Gizli risk', 'Az kaynak', 'Orta kaynak', expertText]) assert.ok(!critical.includes(text));
  assert.equal((critical.match(/<li[ >]/g) || []).length, 2);
  assert.ok(html.indexOf(criticalTitle) < html.indexOf('aria-label="Modelin bilinen sorunları"'));
});

test('kritik kutu iki doğrulanmış yüksek sorunla dolar; yüksek yokken kutu ve uzman satırı yoktur', () => {
  const html = render(AkilliAliciBolumleri, { ...result, modelRiskleri: { riskler: [risk('Birinci', { guven: 'yuksek', onem: 'yuksek' }), risk('İkinci', { onem: 'yuksek' }), risk('Üçüncü', { onem: 'yuksek' })] }, kullaniciSikayetleri: [complaint('Şikâyet', { onem: 'yuksek', kaynakSayisi: 99 })] });
  const critical = section(html, criticalTitle);
  assert.ok(critical.includes('Birinci') && critical.includes('İkinci'));
  assert.ok(!critical.includes('Üçüncü') && !critical.includes('Şikâyet'));
  for (const onem of [undefined, 'orta', 'dusuk']) {
    const low = render(AkilliAliciBolumleri, { ...result, modelRiskleri: { riskler: [risk('Triger yüksek maliyet', { onem, tahminiMaliyet: { min: 50000, max: 80000 } })] }, kullaniciSikayetleri: [complaint('Turbo', { onem })] });
    assert.ok(!low.includes(criticalTitle));
    assert.ok(!low.includes(expertText));
    assert.ok(!low.includes('Yüksek masraf'));
  }
});

test('uzman bağlantıları ayrıntılarda yüksek önem için rapor genelinde en fazla üç kez görünür', () => {
  const sonuc = { ...result, modelRiskleri: { riskler: [risk('Risk yüksek', { onem: 'yuksek' }), risk('Risk orta', { onem: 'orta' })] }, kullaniciSikayetleri: [complaint('İlk yüksek', { onem: 'yuksek' }), complaint('İkinci yüksek', { onem: 'yuksek' }), complaint('Üçüncü yüksek', { onem: 'yuksek' }), complaint('Şikâyet düşük', { onem: 'dusuk' })] };
  const html = render(AkilliAliciBolumleri, sonuc);
  assert.equal(html.split(expertText).length - 1, 3);
  const href = '/ekspertiz-talebi?brand=Hyundai&amp;model=Tucson&amp;year=2021&amp;km=66000&amp;price=2200000';
  const links = [...html.matchAll(/<a[^>]+href="([^"]+)"[^>]*>YerimeBak uzmanı bunu yerinde kontrol eder\.<\/a>/g)];
  assert.equal(links.length, 3);
  for (const link of links) assert.equal(link[1], href);
  const details = [...html.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/g)].map(m => m[1]);
  for (const title of ['Risk orta', 'Şikâyet düşük', 'Üçüncü yüksek']) {
    const item = details.find(m => m.includes(title));
    assert.ok(item);
    assert.ok(!item.includes(expertText));
  }
});

test('karar verisi müşteriye gösterilmez; fiyatlar ve küçük emsal notu korunur', () => {
  for (const count of [2, 3, 4, 5, 8]) {
    const legacyWarning = `Yalnızca ${count} doğrulanmış emsal ilan bulundu (hedef 5)`;
    const sonuc = { ...result, piyasa: { ...result.piyasa, emsalSayisi: count, uyarilar: [legacyWarning, 'Fiyat aralığı geniş; ilanları karşılaştırın.'] } };
    sonuc.ozet = { piyasaKonumu: { metin: 'Piyasa üstünde' }, adilFiyat: {}, riskler: [`${legacyWarning}.`, 'Boya beyanını doğrulayın.'], pazarlikGerekceleri: [], simdiNeYapmali: 'Uzman incelemesi isteyin.' };
    const original = JSON.stringify(sonuc);
    const html = render(DegerlemeSonucu, sonuc);
    for (const hidden of ['EK DOĞRULAMA', 'YALNIZ ADMIN', 'Hesaplanan eğilim', 'Veri güveni']) assert.ok(!html.includes(hidden));
    assert.ok(html.includes('Tavsiye alım fiyatı'));
    assert.equal(html.includes("5&#x27;ten az olduğu için fiyatlar yön göstericidir."), [3, 4].includes(count));
    assert.equal(html.includes(legacyWarning), ![3, 4].includes(count));
    assert.ok(html.includes('Fiyat aralığı geniş; ilanları karşılaştırın.'));
    assert.ok(html.includes('Boya beyanını doğrulayın.'));
    assert.equal(JSON.stringify(sonuc), original);
  }
});

test('şikâyet bölümü eski kayıtta gizli, boş listede açıklamalı, dolu listede güvenli kaynaklıdır', () => {
  const title = 'Kullanıcıların en sık şikâyet ettiği konular';
  assert.ok(!render(AkilliAliciBolumleri, result).includes(title));
  const empty = render(AkilliAliciBolumleri, { ...result, kullaniciSikayetleri: [] });
  assert.ok(empty.includes(title));
  assert.ok(empty.includes('Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.'));
  assert.ok(empty.includes('Forum ve kullanıcı yorumlarından derlenmiştir; kullanıcı beyanıdır, arıza teşhisi değildir.'));
  const html = render(AkilliAliciBolumleri, { ...result, kullaniciSikayetleri: [{ baslik: 'Vites geçişi', aciklama: 'Kullanıcı beyanı', kaynakSayisi: 2, kaynaklar: ['https://forum.example/tucson', 'javascript:alert(1)'] }] });
  assert.ok(html.includes('Vites geçişi'));
  assert.ok(html.includes('2 farklı kaynakta geçiyor'));
  assert.ok(html.includes('href="https://forum.example/tucson"'));
  assert.ok(html.includes('rel="noopener noreferrer nofollow"'));
  assert.ok(!html.includes('javascript:'));
});

const designed = { ...result,
  rapor: { id: '42', report_no: 'YD 2026-000042', verification_code: 'KOD42', created_at: '2026-11-08T12:00:00Z' },
  arac: { ...result.arac, paket: '1.6 CRDi', yakit: 'Dizel', vites: 'Otomatik' },
  degerleme: { ...result.degerleme, aiDegeri: 1810000, adilFiyatAraligi: { min: 1645000, max: 1970000 }, tavsiyeFiyat: 1750000 },
  ozet: { piyasaKonumu: { durum: 'uyumlu', metin: 'Piyasayla uyumlu' }, adilFiyat: { min: 1645000, max: 1970000 }, riskler: ['Boya beyanını doğrulayın.'], pazarlikGerekceleri: [], simdiNeYapmali: 'Servis geçmişini doğrulayın.' },
  pazarlikPlani: { acilisTeklifi: 1705000, hedefFiyat: 1750000, ustSinir: 1785000, potansiyelKazanc: 0, adimlar: [], gerekceler: [], kanitIlanlar: [], saticiMesaji: 'Servis kayıtlarını paylaşır mısınız?' },
};

test('rapor başlığında kimlik, araç ve piyasa konumu var; karar verisi yok', () => {
  const html = render(DegerlemeSonucu, designed);
  const header = html.match(/<header[^>]*aria-label="Değerleme raporu başlığı"[^>]*>([\s\S]*?)<\/header>/)?.[1];
  assert.ok(header);
  for (const text of ['YD 2026-000042', 'Hyundai Tucson', '1.6 CRDi', 'Piyasayla uyumlu', '/dogrula/KOD42']) assert.ok(header.includes(text), text);
  for (const hidden of ['EK DOĞRULAMA', 'YALNIZ ADMIN', 'Veri güveni', 'ALMA']) assert.ok(!html.includes(hidden));
});

test('tavsiye alım hedefi tek tutardır; üst sınır ayrı alanda kalır', () => {
  const html = render(DegerlemeSonucu, designed);
  assert.match(html, /data-price="target"[^>]*>1\.750\.000 ₺</);
  assert.match(html, /data-price="ceiling"[^>]*>1\.785\.000 ₺</);
  assert.ok(!html.includes('1.750.000 ₺ – 1.785.000 ₺'));
});

test('örnek rapor kimliği görünür ama gerçek doğrulama bağlantısı sunulmaz', () => {
  const html = renderToStaticMarkup(React.createElement(DegerlemeSonucu, { sonuc: designed, ornek: true }));
  assert.ok(html.includes('YD 2026-000042'));
  assert.ok(!html.includes('/dogrula/KOD42'));
  assert.ok(html.includes('Örnek rapordur, doğrulanamaz.'));
});

test('ilan ve hesaplanan değer ölçeğin uçlarından dışarı taşmaz', () => {
  for (const price of [1, 9000000]) {
    const html = render(DegerlemeSonucu, { ...designed, arac: { ...designed.arac, ilanFiyati: price } });
    const marker = html.match(/data-marker="listing"[^>]*style="([^"]+)"/);
    assert.ok(marker);
    const left = Number(marker[1].match(/left:([\d.]+)%/)[1]);
    assert.ok(left >= 0 && left <= 100);
    assert.ok(html.includes('Adil fiyat ölçeği'));
  }
});

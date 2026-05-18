/**
 * YERİMEBAK AI - Sahibinden Content Script
 * Extracts vehicle listing data from Sahibinden.com detail pages.
 */

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'EXTRACT_DATA') {
    const data = extractSahibindenData();
    sendResponse(data);
  }
  return true;
});

function extractSahibindenData() {
  const data = {
    source: 'sahibinden',
    url: window.location.href,
    title: document.title,
  };

  // Title from h1
  const h1 = document.querySelector('h1');
  if (h1) data.title = h1.textContent.trim();

  // Description
  const descDiv = document.querySelector('#classifiedDescription');
  if (descDiv) data.description = descDiv.textContent.trim();

  // Price
  data.price = 0;
  const priceDataEl = document.querySelector('.classifiedInfo [data-price]');
  if (priceDataEl) {
    const raw = priceDataEl.getAttribute('data-price') || '0';
    data.price = parseInt(raw.replace(/[^\d]/g, '')) || 0;
  } else {
    const priceH3 = document.querySelector('.classifiedInfo h3');
    if (priceH3) data.price = parseInt(priceH3.textContent.replace(/[^\d]/g, '')) || 0;
  }

  // Features from classifiedInfoList
  const infoItems = document.querySelectorAll('.classifiedInfoList li');
  infoItems.forEach((li) => {
    const strong = li.querySelector('strong');
    const span = li.querySelector('span');
    if (!strong || !span) return;

    const key = strong.textContent.trim().toLowerCase()
      .replace('ý', 'i').replace('i̇', 'i').replace('ı', 'i');
    const val = span.textContent.trim();

    if (key.includes('marka')) data.brand = val;
    else if (key.includes('seri')) data.series = val;
    else if (key.includes('model')) data.model = val;
    else if (key.includes('yıl') || key.includes('yil')) data.year = parseInt(val) || 0;
    else if (key.includes('km') || key.includes('kilometre')) data.km = parseInt(val.replace(/[^\d]/g, '')) || 0;
    else if (key.includes('yakıt') || key.includes('yakit')) data.fuel = val;
    else if (key.includes('vites')) data.transmission = val;
    else if (key.includes('renk')) data.color = val;
    else if (key.includes('motor hacmi')) data.engine_size = val;
    else if (key.includes('motor gücü') || key.includes('gucu')) data.horsepower = val;
    else if (key.includes('kasa tipi')) data.body_type = val;
    else if (key.includes('çekiş') || key.includes('cekis')) data.drive_type = val;
    else if (key.includes('durumu')) data.condition = val;
    else if (key.includes('ilan no') || (key.includes('no') && !key.includes('tarihi'))) data.listing_no = val;
    else if (key.includes('ilan tarihi') || key.includes('tarihi')) data.listing_date = val;
  });

  // Brand fallback from breadcrumbs
  if (!data.brand) {
    const crumbs = document.querySelectorAll('.navigation .navigation-item span, .breadcrumb span');
    if (crumbs.length >= 4) {
      data.brand = crumbs[2]?.textContent.trim() || '';
      data.series = crumbs[3]?.textContent.trim() || data.series;
      data.model = crumbs[4]?.textContent.trim() || data.model;
    }
  }

  // Brand fallback from title string
  if (!data.brand) {
    const titleUpper = (data.title || '').toUpperCase();
    const brands = ['FIAT','RENAULT','VOLKSWAGEN','BMW','MERCEDES','AUDI','FORD','TOYOTA','HYUNDAI','HONDA','KIA','OPEL','PEUGEOT','CITROEN','SKODA','DACIA','VOLVO','SEAT'];
    for (const b of brands) {
      if (titleUpper.includes(b)) {
        data.brand = b.charAt(0) + b.slice(1).toLowerCase();
        const afterBrand = titleUpper.split(b)[1];
        if (afterBrand && !data.model) {
          data.model = afterBrand.trim().split(/\s+/)[0];
        }
        break;
      }
    }
  }

  // Paint / damage info from description
  const descLower = (data.description || '').toLowerCase();
  const paintInfo = { has_paint: false, has_changed: false, details: [] };
  if (descLower.includes('boya') && !descLower.includes('yok')) {
    paintInfo.has_paint = true;
    paintInfo.details.push('Açıklamada boya belirtilmiş');
  }
  if (descLower.includes('değişen') && !descLower.includes('yok')) {
    paintInfo.has_changed = true;
    paintInfo.details.push('Açıklamada değişen belirtilmiş');
  }
  data.paint_info = paintInfo;
  data.accident_record = descLower.includes('hasar kaydı')
    ? 'Açıklamada hasar kaydı belirtilmiş'
    : 'Bilinmiyor';

  // Location
  const locH2 = document.querySelector('.classifiedInfo h2');
  data.location = locH2 ? locH2.textContent.trim() : '';

  // Image
  const imgEl = document.querySelector('img.classifiedDetailMainPhoto');
  data.image_url = imgEl ? (imgEl.getAttribute('src') || '') : '';

  // Build full model name for API
  const fullModel = [data.series, data.model].filter(Boolean).join(' ') || data.brand || '';

  return {
    brand: data.brand || '',
    model: fullModel || data.model || '',
    year: data.year || 0,
    mileage_km: data.km || 0,
    fuel_type: data.fuel || 'Bilinmiyor',
    gear_type: data.transmission || 'Bilinmiyor',
    listed_price: data.price || 0,
    damage_level: 'NONE',
    source: 'sahibinden',
    url: data.url,
    title: data.title,
    color: data.color || '',
    engine_size: data.engine_size || '',
    horsepower: data.horsepower || '',
    body_type: data.body_type || '',
    drive_type: data.drive_type || '',
    location: data.location || '',
    image_url: data.image_url || '',
    listing_no: data.listing_no || '',
    listing_date: data.listing_date || '',
    paint_info: data.paint_info,
    description: data.description || '',
  };
}
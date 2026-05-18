/**
 * YERİMEBAK AI - Arabam.com Content Script
 * Extracts vehicle listing data from Arabam.com detail pages.
 */

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'EXTRACT_DATA') {
    const data = extractArabamData();
    sendResponse(data);
  }
  return true;
});

function extractArabamData() {
  const data = {
    source: 'arabam',
    url: window.location.href,
    title: document.title,
  };

  // Title
  const h1 = document.querySelector('h1, .detail-title h1, .ad-detail-title');
  if (h1) data.title = h1.textContent.trim();

  // Price
  data.price = 0;
  const priceEl = document.querySelector('.detail-price, .price, [itemprop="price"], .ad-price');
  if (priceEl) data.price = parseInt(priceEl.textContent.replace(/[^\d]/g, '')) || 0;

  // Features table - arabam uses table or definition lists
  const pairs = document.querySelectorAll('.detail-features tr, .feature-list tr, .ad-info-table tr, dl dt, dl dd');
  const features = {};
  let lastKey = '';

  // Table rows approach
  document.querySelectorAll('tr, .property-item, .feature-item').forEach((row) => {
    const cells = row.querySelectorAll('td, th, span, strong');
    if (cells.length >= 2) {
      const key = cells[0].textContent.trim().toLowerCase();
      const val = cells[1].textContent.trim();
      if (key && val) features[key] = val;
    }
  });

  // Definition list approach
  document.querySelectorAll('dt').forEach((dt) => {
    const dd = dt.nextElementSibling;
    if (dd && dd.tagName === 'DD') {
      features[dt.textContent.trim().toLowerCase()] = dd.textContent.trim();
    }
  });

  // Label-value pairs
  document.querySelectorAll('.info-item, .detail-info-item, .spec-item, .ad-spec-item').forEach((item) => {
    const label = item.querySelector('.label, .info-label, span:first-child');
    const value = item.querySelector('.value, .info-value, span:last-child, strong');
    if (label && value) {
      features[label.textContent.trim().toLowerCase()] = value.textContent.trim();
    }
  });

  // Map features to data
  for (const [key, val] of Object.entries(features)) {
    const k = key.replace(/[İı]/g, 'i').replace('ý', 'i').replace('i̇', 'i');
    if (k.includes('marka')) data.brand = val;
    else if (k.includes('model')) data.model = val;
    else if (k.includes('yil') || k.includes('yıl') || k.includes('model yil')) data.year = parseInt(val) || 0;
    else if (k.includes('km') || k.includes('kilometre')) data.km = parseInt(val.replace(/[^\d]/g, '')) || 0;
    else if (k.includes('yakit') || k.includes('yakıt')) data.fuel = val;
    else if (k.includes('vites')) data.transmission = val;
    else if (k.includes('renk')) data.color = val;
    else if (k.includes('motor hacmi')) data.engine_size = val;
    else if (k.includes('beygir') || k.includes('guc') || k.includes('güç')) data.horsepower = val;
    else if (k.includes('kasa')) data.body_type = val;
    else if (k.includes('cekis') || k.includes('çekiş')) data.drive_type = val;
  }

  // Description
  const descEl = document.querySelector('.detail-description, .description, .ad-description, [itemprop="description"]');
  if (descEl) data.description = descEl.textContent.trim();

  // Parse paint/damage from description
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

  // Location
  const locEl = document.querySelector('.detail-location, .location, .ad-location, [itemprop="address"]');
  data.location = locEl ? locEl.textContent.trim() : '';

  // Image
  const imgEl = document.querySelector('.detail-image img, .ad-image img, .gallery img, [itemprop="image"]');
  data.image_url = imgEl ? (imgEl.getAttribute('src') || imgEl.getAttribute('data-src') || '') : '';

  // Brand fallback from title
  if (!data.brand) {
    const titleUpper = (data.title || '').toUpperCase();
    const brands = ['FIAT','RENAULT','VOLKSWAGEN','BMW','MERCEDES','AUDI','FORD','TOYOTA','HYUNDAI','HONDA','KIA','OPEL','PEUGEOT','CITROEN','SKODA','DACIA','VOLVO','SEAT'];
    for (const b of brands) {
      if (titleUpper.includes(b)) {
        data.brand = b.charAt(0) + b.slice(1).toLowerCase();
        if (!data.model) {
          const afterBrand = titleUpper.split(b)[1];
          if (afterBrand) data.model = afterBrand.trim().split(/\s+/)[0];
        }
        break;
      }
    }
  }

  return {
    brand: data.brand || '',
    model: data.model || '',
    year: data.year || 0,
    mileage_km: data.km || 0,
    fuel_type: data.fuel || 'Bilinmiyor',
    gear_type: data.transmission || 'Bilinmiyor',
    listed_price: data.price || 0,
    damage_level: 'NONE',
    source: 'arabam',
    url: data.url,
    title: data.title,
    color: data.color || '',
    engine_size: data.engine_size || '',
    horsepower: data.horsepower || '',
    body_type: data.body_type || '',
    drive_type: data.drive_type || '',
    location: data.location || '',
    image_url: data.image_url || '',
    paint_info: paintInfo,
    description: data.description || '',
  };
}
/**
 * YERİMEBAK AI - Letgo Content Script
 * Extracts vehicle listing data from Letgo.com detail pages.
 */

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'EXTRACT_DATA') {
    const data = extractLetgoData();
    sendResponse(data);
  }
  return true;
});

function extractLetgoData() {
  const data = {
    source: 'letgo',
    url: window.location.href,
    title: document.title,
  };

  // Title - Letgo uses various selectors
  const h1 = document.querySelector('h1, [data-testid="listing-title"], .listing-title, .ad-title');
  if (h1) data.title = h1.textContent.trim();

  // Price
  data.price = 0;
  const priceEl = document.querySelector(
    '[data-testid="listing-price"], .price, .listing-price, .ad-price, [itemprop="price"]'
  );
  if (priceEl) data.price = parseInt(priceEl.textContent.replace(/[^\d]/g, '')) || 0;

  // Features from detail sections
  const features = {};

  // Letgo often uses structured property lists
  document.querySelectorAll(
    '.item-properties li, .listing-properties li, .attribute-item, .spec-item, ' +
    '[data-testid*="attribute"], [data-testid*="property"]'
  ).forEach((item) => {
    const text = item.textContent.trim();
    const parts = text.split(':').map(s => s.trim());
    if (parts.length >= 2) {
      features[parts[0].toLowerCase()] = parts[1];
    } else {
      // Single-value attributes (e.g., just "Otomatik")
      const label = item.getAttribute('data-label') || item.getAttribute('aria-label') || '';
      if (label) features[label.toLowerCase()] = text;
    }
  });

  // Generic label-value pairs
  document.querySelectorAll('.property, .detail-row, .info-row, .feature-row').forEach((row) => {
    const label = row.querySelector('.label, .key, .name, span:first-child');
    const value = row.querySelector('.value, .val, strong, span:last-child');
    if (label && value) {
      features[label.textContent.trim().toLowerCase()] = value.textContent.trim();
    }
  });

  // Map features
  for (const [key, val] of Object.entries(features)) {
    const k = key.replace(/[İı]/g, 'i').replace('ý', 'i').replace('i̇', 'i');
    if (k.includes('marka')) data.brand = val;
    else if (k.includes('model')) data.model = val;
    else if (k.includes('yil') || k.includes('yıl')) data.year = parseInt(val) || 0;
    else if (k.includes('km') || k.includes('kilometre')) data.km = parseInt(val.replace(/[^\d]/g, '')) || 0;
    else if (k.includes('yakit') || k.includes('yakıt')) data.fuel = val;
    else if (k.includes('vites')) data.transmission = val;
    else if (k.includes('renk')) data.color = val;
    else if (k.includes('kasa')) data.body_type = val;
    else if (k.includes('motor')) data.engine_size = val;
  }

  // Description
  const descEl = document.querySelector(
    '[data-testid="listing-description"], .description, .listing-description, ' +
    '.ad-description, [itemprop="description"]'
  );
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
  const locEl = document.querySelector(
    '[data-testid="listing-location"], .location, .ad-location, [itemprop="address"]'
  );
  data.location = locEl ? locEl.textContent.trim() : '';

  // Image
  const imgEl = document.querySelector(
    '.listing-image img, .gallery img, .ad-image img, [itemprop="image"], img[src*="letgo"]'
  );
  data.image_url = imgEl ? (imgEl.getAttribute('src') || imgEl.getAttribute('data-src') || '') : '';

  // Brand fallback from title
  if (!data.brand) {
    const titleUpper = (data.title || '').toUpperCase();
    const brands = [
      'FIAT','RENAULT','VOLKSWAGEN','BMW','MERCEDES','AUDI','FORD','TOYOTA',
      'HYUNDAI','HONDA','KIA','OPEL','PEUGEOT','CITROEN','SKODA','DACIA','VOLVO','SEAT',
    ];
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
    source: 'letgo',
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
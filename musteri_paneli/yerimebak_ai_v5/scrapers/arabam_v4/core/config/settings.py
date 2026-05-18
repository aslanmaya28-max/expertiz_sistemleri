# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Configuration Settings
Konfigürasyon sabitleri
"""

from typing import Dict, List


# ==================== BASE URLs ====================
BASE_URL = "https://www.arabam.com"
SEARCH_URL = f"{BASE_URL}/ikinci-el/otomobil"
DETAIL_URL_TEMPLATE = f"{BASE_URL}/ilan/{{listing_id}}"

# ==================== BROWSER SETTINGS ====================
DEFAULT_VIEWPORT = {"width": 1920, "height": 1080}
DEFAULT_LOCALE = "tr-TR"
DEFAULT_TIMEZONE = "Europe/Istanbul"
DEFAULT_GEOLOCATION = {"latitude": 41.0082, "longitude": 28.9784}  # Istanbul

# ==================== USER AGENT ====================
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"

# ==================== HTTP HEADERS ====================
HTTP_HEADERS = {
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Cache-Control': 'max-age=0'
}

# ==================== BROWSER LAUNCH ARGUMENTS (6) ====================
# Letgo v4.0 pattern - 6 browser args
BROWSER_ARGS = [
    '--disable-blink-features=AutomationControlled',  # KRİTİK
    '--disable-dev-shm-usage',
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-infobars',
    '--disable-extensions',
]

# ==================== JS STEALTH SCRIPTS (5) ====================
# Letgo v4.0 pattern - 5 JS stealth scripts
STEALTH_SCRIPTS = """
// Script 1: Hide WebDriver
Object.defineProperty(navigator, 'webdriver', {
    get: () => undefined
});

// Script 2: Fake Plugins
Object.defineProperty(navigator, 'plugins', {
    get: () => [
        { name: 'Chrome PDF Plugin' },
        { name: 'Chrome PDF Viewer' },
        { name: 'Native Client' }
    ]
});

// Script 3: Fake Languages
Object.defineProperty(navigator, 'languages', {
    get: () => ['tr-TR', 'tr', 'en-US', 'en']
});

// Script 4: Fake Hardware
Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 8 });
Object.defineProperty(navigator, 'deviceMemory', { get: () => 8 });

// Script 5: Clean Automation Traces
delete window.__playwright;
delete window.__pw_manual;
delete window.chrome.runtime;
"""

# ==================== TIMING SETTINGS ====================
PAGE_LOAD_TIMEOUT = 60  # seconds
NAVIGATION_TIMEOUT = 60  # seconds
DEFAULT_WAIT_AFTER_LOAD = 2.0  # seconds (REDUCED from 3.0 for performance)
DEFAULT_WAIT_AFTER_SCROLL = 0.3  # seconds (REDUCED from 0.5 for performance)
MIN_WAIT_BETWEEN_REQUESTS = 1.0  # seconds (REDUCED from 2.0 for performance)
MAX_WAIT_BETWEEN_REQUESTS = 2.0  # seconds (REDUCED from 4.0 for performance)

# ==================== SCROLL SETTINGS ====================
SCROLL_STEPS = 3  # REDUCED from 5 for performance
MIN_SCROLL_AMOUNT = 300
MAX_SCROLL_AMOUNT = 800
FINAL_SCROLL_DELAY = 1.0  # seconds (REDUCED from 2.0 for performance)

# ==================== RATE LIMITING ====================
MAX_REQUESTS_PER_MINUTE = 30
MAX_REQUESTS_PER_HOUR = 100
RATE_LIMIT_RETRY_DELAY = 5.0  # seconds

# ==================== RETRY SETTINGS ====================
MAX_RETRY_ATTEMPTS = 3
RETRY_BASE_DELAY = 1000  # ms
RETRY_MAX_DELAY = 30000  # ms
RETRY_EXPONENTIAL_BASE = 2.0

# ==================== SCRAPING LIMITS ====================
DEFAULT_MAX_LISTINGS = 15
MAX_LISTINGS_PER_SEARCH = 20
MAX_CONCURRENT_REQUESTS = 3

# ==================== DATA VALIDATION ====================
VALID_PRICE_RANGE = (10000, 100000000)  # TL
VALID_KM_RANGE = (0, 500000)
VALID_YEAR_RANGE = (1990, 2026)

# ==================== LOGGING ====================
LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# ==================== ERROR MESSAGES ====================
ERROR_BOT_DETECTED = "Bot tespit edildi"
ERROR_NO_LISTINGS = "İlan bulunamadı"
ERROR_TIMEOUT = "İşlem zaman aşımına uğradı"
ERROR_NETWORK = "Ağ hatası"
ERROR_PARSING = "Veri ayrıştırma hatası"
ERROR_BLOCKED = "Erişim engellendi"

# ==================== SUCCESS CRITERIA ====================
TARGET_SUCCESS_RATE = 0.95  # 95%
TARGET_LISTING_COUNT = 15
TARGET_DATA_ACCURACY = 0.95  # 95%
TARGET_PERFORMANCE = 15.0  # seconds

# ==================== TURKISH CHARACTER MAP ====================
TURKISH_CHAR_MAP = {
    "ç": "c", "Ç": "C",
    "ğ": "g", "Ğ": "G",
    "ı": "i", "İ": "I",
    "ö": "o", "Ö": "O",
    "ş": "s", "Ş": "S",
    "ü": "u", "Ü": "U",
}

# ==================== BODY PARTS FOR PAINT DETECTION ====================
BODY_PARTS = [
    'ön tampon', 'arka tampon', 'ön kaput', 'bagaj kapağı',
    'sağ ön çamurluk', 'sol ön çamurluk', 'sağ arka çamurluk', 'sol arka çamurluk',
    'sağ ön kapı', 'sol ön kapı', 'sağ arka kapı', 'sol arka kapı',
    'tavan', 'sağ ön panel', 'sol ön panel', 'sağ arka panel', 'sol arka panel',
    'amortisör', 'far', 'stop lambası', 'tampon',
]

# ==================== PAINT KEYWORDS ====================
PAINT_KEYWORDS = {
    'boyalı': ['boyalı', 'boya var', 'lokal boya'],
    'değişen': ['değişen', 'parça değişen', 'değişmiş'],
    'orijinal': ['orijinal', 'boyasız', 'değişensiz'],
}

# ==================== PACKAGE KEYWORDS ====================
PACKAGE_KEYWORDS = {
    'safety': ['abs', 'esp', 'airbag', 'yokuş kalkış'],
    'comfort': ['klima', 'deri', 'sunroof'],
    'technology': ['navigasyon', 'kamera', 'bluetooth'],
    'performance': ['spor', 'gti', 'gt'],
}

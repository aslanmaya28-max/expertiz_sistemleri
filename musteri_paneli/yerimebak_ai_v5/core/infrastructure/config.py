import os
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Project Paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
LOGS_DIR = BASE_DIR / "logs"

# Ensure directories exist
DATA_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)

# Database Configuration — PostgreSQL Only (SQLite removed)
from yerimebak_ai_v5.core.database_config import DatabaseConfig
DATABASE_URL = os.getenv("DATABASE_URL", "")

# Scraper Settings
# Environment variable'dan oku, yoksa varsayılan değer kullan
DEFAULT_HEADLESS = os.getenv("HEADLESS", "True").lower() not in ("false", "0", "no")
RETRY_COUNT = int(os.getenv("RETRY_COUNT", "3"))
DELAY_BETWEEN_REQUESTS = float(os.getenv("DELAY_BETWEEN_REQUESTS", "2.0"))

# API Settings
API_VERSION = "v7.0"
DEBUG = os.getenv("DEBUG", "False").lower() == "true"

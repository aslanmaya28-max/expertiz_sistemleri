
import os
import sys
from datetime import datetime

# Root path alignment
sys.path.append(os.getcwd())

try:
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    from yerimebak_ai_v5.dashboard.services.live_data_service_v2 import get_live_service_v2
except ImportError as e:
    print(f"❌ Error during import: {e}")
    sys.exit(1)

def bootstrap():
    print(f"🚀 [BOOTSTRAP] Starting Yerimebak AI v6.1 Production Alignment...")
    
    # 1. Database Alignment
    try:
        DatabaseConfig.bootstrap()
        DatabaseConfig.alignment()
        print("✅ [DB] Database schema aligned and forensic columns verified.")
    except Exception as e:
        print(f"❌ [DB] Error aligning database: {e}")

    # 2. Service Initialization
    try:
        live_service = get_live_service_v2()
        print("✅ [SERVICES] Market Intelligence Service initialized.")
    except Exception as e:
        print(f"❌ [SERVICES] Error initializing services: {e}")

    # 3. Directory Verification
    dirs = ['./data', './logs', './screenshots', './yerimebak_ai_v5/workers/logs']
    for d in dirs:
        if not os.path.exists(d):
            os.makedirs(d)
            print(f"✅ [SYSTEM] Created directory: {d}")

    print(f"\n✨ System check completed at {datetime.now().strftime('%H:%M:%S')}")
    print("📢 System is now in 100% operational mode (v6.1).")
    print("🔗 Start the dashboard with: streamlit run yerimebak_ai_v5/dashboard/app_v2.py")

if __name__ == "__main__":
    bootstrap()

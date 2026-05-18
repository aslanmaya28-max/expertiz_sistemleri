import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv
load_dotenv(override=False)
from yerimebak_ai_v5.core.database_config import DatabaseConfig

conn = DatabaseConfig.get_connection()
cur = conn.cursor()

cur.execute("SELECT id, email, full_name, phone, role, credits, tier FROM users ORDER BY id")
for r in cur.fetchall():
    print(dict(r))

conn.close()

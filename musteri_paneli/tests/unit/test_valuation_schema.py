"""Açılış şemasının veritabanına gönderdiği güvenlik sözleşmesi."""
import re

from yerimebak_ai_v5.services.valuation_reports import ensure_schema


def test_snapshot_fonksiyonu_cagiranin_arama_yolunu_kullanmaz():
    class SchemaCursor:
        def __init__(self):
            self.statements = []

        def execute(self, sql):
            self.statements.append(sql)

        def fetchall(self):
            return []

    cursor = SchemaCursor()
    ensure_schema(cursor)
    function_sql = next(sql for sql in cursor.statements
                        if 'CREATE OR REPLACE FUNCTION protect_valuation_snapshot()' in sql)
    # SQL sınırında doğrula: aynı açılış mevcut fonksiyonun ayarını da düzeltmeli.
    declaration = function_sql.split('$$')[0]
    options = function_sql.rsplit('$$', 1)[-1]
    assert re.search(r'\bSET\s+search_path\s*=\s*public\b', declaration + options, re.I)

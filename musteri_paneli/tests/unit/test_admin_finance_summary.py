import unittest

from yerimebak_ai_v5.services.finance_service import PERSONNEL_SHARE_RATE, summarize


def _req(total, vat, report_status, personel=None, status="Islemde", payment_status="paid_simulation", fee=6500):
    data = {}
    if personel:
        data = {"assigned_personel_id": personel, "assigned_personel_name": f"Personel {personel}"}
    return {
        "total_tl": total,
        "vat_tl": vat,
        "service_fee_tl": fee,
        "status": status,
        "payment_status": payment_status,
        "report_status": report_status,
        "report_data": data,
    }


class AdminFinanceSummaryTests(unittest.TestCase):
    def test_revenue_vat_and_personnel_share(self):
        result = summarize(
            [
                _req(12000, 2000, "published", personel="7"),
                _req(6000, 1000, "published", personel="7"),
                _req(6000, 1000, "pending_admin", personel="8"),
                _req(9999, 999, "published", personel="7", status="Iptal"),
            ],
            [],
        )

        ekspertiz = result["ekspertiz"]
        self.assertEqual(ekspertiz["request_count"], 3)
        self.assertEqual(ekspertiz["ciro_tl"], 24000)
        self.assertEqual(ekspertiz["kdv_tl"], 4000)
        self.assertEqual(ekspertiz["net_tl"], 20000)
        self.assertEqual(ekspertiz["simulated_payment_count"], 3)
        self.assertEqual(ekspertiz["report_status_counts"], {"published": 2, "pending_admin": 1})

        # Hakedis sadece yayinlanan raporlarin hizmet bedeli uzerinden tahakkuk eder
        # (paket ucreti personelle paylasilmaz).
        personel = result["personel"]
        self.assertEqual(personel["hakedis_tl"], round(2 * 6500 * PERSONNEL_SHARE_RATE, 2))
        self.assertEqual(len(personel["by_personnel"]), 1)
        self.assertEqual(personel["by_personnel"][0]["report_count"], 2)
        self.assertFalse(personel["payout_tracking"])

    def test_assignment_object_and_json_string_data(self):
        row = _req(1200, 200, "published")
        row["report_data"] = '{"assignment": {"personnel_id": "9", "personnel_name": "Ayse"}}'
        result = summarize([row], [])
        self.assertEqual(result["personel"]["by_personnel"][0]["personnel_name"], "Ayse")

    def test_credit_sales(self):
        result = summarize(
            [],
            [
                {"status": "approved", "adet": 3, "toplam": 1500},
                {"status": "pending", "adet": 1, "toplam": 500},
                {"status": "rejected", "adet": 2, "toplam": 900},
            ],
        )
        self.assertEqual(
            result["kredi_satislari"],
            {"approved_tl": 1500, "approved_count": 3, "pending_tl": 500, "pending_count": 1},
        )

    def test_route_registered(self):
        from yerimebak_ai_v5.api.v1.endpoints.expertiz import router

        self.assertIn("/admin/finance/summary", {r.path for r in router.routes})


if __name__ == "__main__":
    unittest.main()

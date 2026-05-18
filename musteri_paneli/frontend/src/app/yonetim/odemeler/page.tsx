"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { getToken } from "@/lib/yetki";
import YonetimLayout from "@/bilesenler/YonetimLayout";

interface Siparis {
  id: string;
  user_email: string;
  package_name: string;
  credits: number;
  amount_tl: number;
  status: string;
  payment_method: string;
  created_at: string;
}

export default function OdemeOnaylari() {
  const { user } = useAuth();
  const [siparisler, setSiparisler] = useState<Siparis[]>([]);
  const [yukleniyor, setYukleniyor] = useState(true);

  const authHeaders = (): Record<string, string> => {
    const token = getToken();
    const h: Record<string, string> = { "Content-Type": "application/json" };
    if (token) h["Authorization"] = `Bearer ${token}`;
    return h;
  };

  useEffect(() => {
    if (!user || user.role !== "admin") {
      if (typeof window !== "undefined") window.location.href = "/";
      return;
    }
    fetch("/api/v1/payments/admin/orders", { headers: authHeaders() })
      .then((r) => r.json())
      .then((d) => setSiparisler(d.orders || []))
      .catch(console.error)
      .finally(() => setYukleniyor(false));
  }, [user]);

  const onayla = async (id: string) => {
    try {
      const r = await fetch("/api/v1/payments/approve", { method: "POST", headers: authHeaders(), body: JSON.stringify({ order_id: id }) });
      const d = await r.json();
      if (!r.ok) throw new Error(d.detail);
      setSiparisler((p) => p.map((s) => (s.id === id ? { ...s, status: "approved" } : s)));
    } catch (e) {
      alert(e instanceof Error ? e.message : "Hata");
    }
  };

  const reddet = async (id: string) => {
    try {
      const r = await fetch("/api/v1/payments/reject", { method: "POST", headers: authHeaders(), body: JSON.stringify({ order_id: id }) });
      const d = await r.json();
      if (!r.ok) throw new Error(d.detail);
      setSiparisler((p) => p.map((s) => (s.id === id ? { ...s, status: "rejected" } : s)));
    } catch (e) {
      alert(e instanceof Error ? e.message : "Hata");
    }
  };

  if (!user || user.role !== "admin") return null;

  return (
    <YonetimLayout aktif="/yonetim/odemeler">
      <h2 className="text-lg font-semibold text-metin-birincil mb-4">Ödeme Onayları</h2>
      {yukleniyor ? (
        <p className="text-metin-ikincil">Yükleniyor...</p>
      ) : siparisler.length === 0 ? (
        <p className="text-metin-ikincil">Bekleyen sipariş yok</p>
      ) : (
        <div className="space-y-3">
          {siparisler.map((s) => (
            <div key={s.id} className="bg-white border border-kenarlik-acik rounded-xl p-4 flex items-center justify-between">
              <div>
                <div className="font-medium text-metin-birincil">{s.package_name}</div>
                <div className="text-xs text-metin-ikincil">{s.user_email} • {s.amount_tl.toLocaleString("tr-TR")} ₺ • {s.credits} kredi</div>
                <div className="text-xs text-metin-ikincil mt-1">{new Date(s.created_at).toLocaleString("tr-TR")}</div>
              </div>
              <div className="flex items-center gap-3">
                <span className={`text-xs px-2 py-1 rounded-full font-medium ${s.status === "approved" ? "bg-green-100 text-green-700" : s.status === "rejected" ? "bg-red-100 text-red-700" : "bg-yellow-100 text-yellow-700"}`}>
                  {s.status === "approved" ? "Onaylı" : s.status === "rejected" ? "Reddedildi" : "Bekliyor"}
                </span>
                {s.status === "pending" && (
                  <div className="flex gap-2">
                    <button onClick={() => onayla(s.id)} className="px-3 py-1.5 bg-basarili text-white text-xs font-medium rounded hover:opacity-90">Onayla</button>
                    <button onClick={() => reddet(s.id)} className="px-3 py-1.5 bg-tehlike text-white text-xs font-medium rounded hover:opacity-90">Reddet</button>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </YonetimLayout>
  );
}

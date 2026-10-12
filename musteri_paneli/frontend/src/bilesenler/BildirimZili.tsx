"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { getMyNotifications, markNotificationsRead, type AppNotification } from "@/lib/api";

const YOKLAMA_MS = 30_000;
/** Yeni bildirim geldiginde panel taleplerini yenilesin diye yayinlanir. */
export const BILDIRIM_EVENT = "yerimebak:notifications";

function zaman(value: string) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return new Intl.DateTimeFormat("tr-TR", { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }).format(date);
}

export default function BildirimZili() {
  const [items, setItems] = useState<AppNotification[]>([]);
  const [unread, setUnread] = useState(0);
  const [acik, setAcik] = useState(false);
  const sonId = useRef<number | null>(null);
  const kutu = useRef<HTMLDivElement>(null);

  const yukle = useCallback(async () => {
    try {
      const res = await getMyNotifications(20);
      setItems(res.notifications);
      setUnread(res.unread);
      const enYeni = res.notifications[0]?.id ?? null;
      if (sonId.current !== null && enYeni !== null && enYeni !== sonId.current) {
        window.dispatchEvent(new Event(BILDIRIM_EVENT));
      }
      sonId.current = enYeni;
    } catch {
      // oturum dusmus olabilir; bir sonraki yoklamada tekrar denenir
    }
  }, []);

  useEffect(() => {
    const ilk = window.setTimeout(yukle, 0);
    const timer = window.setInterval(() => {
      if (document.visibilityState === "visible") yukle();
    }, YOKLAMA_MS);
    return () => {
      window.clearTimeout(ilk);
      window.clearInterval(timer);
    };
  }, [yukle]);

  useEffect(() => {
    if (!acik) return;
    const kapat = (e: MouseEvent) => {
      if (kutu.current && !kutu.current.contains(e.target as Node)) setAcik(false);
    };
    document.addEventListener("mousedown", kapat);
    return () => document.removeEventListener("mousedown", kapat);
  }, [acik]);

  async function ac() {
    const yeni = !acik;
    setAcik(yeni);
    if (yeni && unread > 0) {
      setUnread(0);
      setItems((list) => list.map((n) => ({ ...n, read: true })));
      try {
        await markNotificationsRead();
      } catch {
        yukle();
      }
    }
  }

  return (
    <div className="relative" ref={kutu}>
      <button type="button" onClick={ac} aria-label="Bildirimler" className="relative p-2 text-metin-ikincil hover:text-birincil">
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.4-1.4A2 2 0 0118 14.2V11a6 6 0 10-12 0v3.2a2 2 0 01-.6 1.4L4 17h5m6 0a3 3 0 11-6 0" />
        </svg>
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 min-w-[18px] h-[18px] px-1 rounded-full bg-tehlike text-white text-[10px] font-bold flex items-center justify-center">
            {unread > 9 ? "9+" : unread}
          </span>
        )}
      </button>
      {acik && (
        <div className="absolute right-0 mt-2 w-80 max-w-[calc(100vw-2rem)] rounded-lg border border-kenarlik-acik bg-white shadow-lg z-50">
          <div className="px-4 py-3 border-b border-kenarlik-acik text-sm font-semibold text-metin-birincil">Bildirimler</div>
          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 ? (
              <p className="px-4 py-6 text-center text-sm text-metin-ikincil">Henüz bildirim yok.</p>
            ) : (
              items.map((n) => (
                <Link key={n.id} href="/panel" onClick={() => setAcik(false)}
                  className={`block px-4 py-3 border-b border-kenarlik-acik last:border-0 hover:bg-gray-50 ${n.read ? "" : "bg-birincil/5"}`}>
                  <div className="text-sm font-medium text-metin-birincil">{n.title}</div>
                  {n.body && <div className="mt-0.5 text-xs text-metin-ikincil">{n.body}</div>}
                  <div className="mt-1 text-[11px] text-metin-ikincil">{zaman(n.created_at)}</div>
                </Link>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}

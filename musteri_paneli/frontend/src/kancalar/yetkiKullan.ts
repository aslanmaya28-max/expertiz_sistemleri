"use client";

import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { getToken, setToken, removeToken } from "@/lib/yetki";
import { API_BASE } from "@/lib/api";

interface User {
  id: number;
  email: string;
  full_name?: string;
  credits: number;
  role: string;
}

const AUTH_EVENT = "yerimebak:auth";
const CREDITS_EVENT = "yerimebak:credits";

function decodeUser(token: string | null): User | null {
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) throw new Error("invalid");
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    // Suresi dolmus oturum: kullanici girisli gorunmesin (islemler 401 verirdi)
    if (typeof payload.exp === "number" && payload.exp * 1000 <= Date.now()) return null;
    return {
      id: payload.sub,
      email: payload.email,
      full_name: payload.full_name,
      credits: payload.credits || 0,
      role: payload.role || "user",
    };
  } catch {
    return null;
  }
}

function subscribe(callback: () => void) {
  window.addEventListener("storage", callback);
  window.addEventListener(AUTH_EVENT, callback);
  return () => {
    window.removeEventListener("storage", callback);
    window.removeEventListener(AUTH_EVENT, callback);
  };
}

const noopSubscribe = () => () => undefined;

function notifyAuthChanged() {
  window.dispatchEvent(new Event(AUTH_EVENT));
}

/** Kredi bakiyesi degisti (satin alma / analiz): ust cubuk ve panel yenilensin. */
export function notifyCreditsChanged() {
  window.dispatchEvent(new Event(CREDITS_EVENT));
}

/**
 * Oturum: token localStorage'da. Sunucu cizimi ve hydration sirasinda "yukleniyor"
 * (user=null, loading=true) doner; boylece sunucu ve istemci HTML'i ayni kalir.
 */
export function useAuth() {
  const token = useSyncExternalStore(subscribe, getToken, () => null);
  const hydrated = useSyncExternalStore(noopSubscribe, () => true, () => false);
  const user = useMemo(() => decodeUser(token), [token]);

  const login = async (email: string, password: string) => {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "Giris basarisiz");
    if (data.token) setToken(data.token);
    notifyAuthChanged();
    return data;
  };

  const register = async (email: string, password: string, full_name: string, phone: string | undefined, termsAccepted: boolean) => {
    const res = await fetch(`${API_BASE}/auth/register`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, full_name, phone, terms_accepted: termsAccepted }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "Kayit basarisiz");
    if (data.token) setToken(data.token);
    notifyAuthChanged();
    return data;
  };

  const logout = () => {
    removeToken();
    notifyAuthChanged();
  };

  return { user, loading: !hydrated, login, register, logout };
}

/** Sunucudaki guncel kredi bakiyesi (token icindeki deger giris anina aittir). */
export function useCredits(): number | null {
  const { user } = useAuth();
  const [credits, setCredits] = useState<number | null>(null);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    const load = () => {
      fetch(`${API_BASE}/credits/balance`, { headers: { Authorization: `Bearer ${getToken()}` } })
        .then((r) => (r.ok ? r.json() : null))
        .then((d) => {
          if (!cancelled && d && typeof d.credits === "number") setCredits(d.credits);
        })
        .catch(() => undefined);
    };
    load();
    window.addEventListener(CREDITS_EVENT, load);
    return () => {
      cancelled = true;
      window.removeEventListener(CREDITS_EVENT, load);
    };
  }, [user]);

  return user ? credits ?? user.credits : null;
}

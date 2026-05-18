"use client";

import { useState } from "react";
import { getToken, setToken, removeToken } from "@/lib/yetki";

interface User {
  id: number;
  email: string;
  full_name?: string;
  credits: number;
  tier: string;
  role: string;
}

function readUserFromToken(): User | null {
  const token = getToken();
  if (!token) return null;
  try {
    const parts = token.split(".");
    if (parts.length !== 3) throw new Error("invalid");
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const payload = JSON.parse(atob(b64 + "=".repeat((4 - (b64.length % 4)) % 4)));
    return {
      id: payload.sub,
      email: payload.email,
      full_name: payload.full_name,
      credits: payload.credits || 0,
      tier: payload.tier || "free",
      role: payload.role || "user",
    };
  } catch {
    removeToken();
    return null;
  }
}

export function useAuth() {
  const [user, setUser] = useState<User | null>(() => readUserFromToken());
  const [loading] = useState(false);

  const login = async (email: string, password: string) => {
    const res = await fetch("/api/v1/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "Giris basarisiz");
    if (data.token) setToken(data.token);
    setUser(readUserFromToken());
    return data;
  };

  const register = async (email: string, password: string, full_name: string, phone?: string) => {
    const res = await fetch("/api/v1/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, full_name, phone }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || "Kayit basarisiz");
    if (data.token) setToken(data.token);
    setUser(readUserFromToken());
    return data;
  };

  const logout = () => {
    removeToken();
    setUser(null);
  };

  return { user, loading, login, register, logout };
}

"use client";

import { useState } from "react";

const TOKEN_KEY = "yerimebak_token";

function decodeJWT(token: string) {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(padded));
  } catch {
    return null;
  }
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  if (typeof window === "undefined") return;
  localStorage.setItem(TOKEN_KEY, token);
}

export function removeToken() {
  if (typeof window === "undefined") return;
  localStorage.removeItem(TOKEN_KEY);
}

function readUserFromToken() {
  const token = getToken();
  if (!token) return null;

  const payload = decodeJWT(token);
  if (!payload) {
    removeToken();
    return null;
  }

  return {
    id: payload.sub,
    email: payload.email,
    credits: payload.credits || 0,
  };
}

export function useAuth() {
  const [user, setUser] = useState<{ id: number; email: string; credits: number } | null>(() => readUserFromToken());

  const logout = () => {
    removeToken();
    setUser(null);
  };

  return { user, loading: false, logout, setUser };
}

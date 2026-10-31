"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useAuth } from "@/kancalar/yetkiKullan";
import { uyelikAdresi } from "@/lib/uyelikYonlendirme";

export default function IncelemeBaglantisi({ children, className }: { children: ReactNode; className?: string }) {
  const { user } = useAuth();
  return <Link href={user ? "/ekspertiz-talebi" : uyelikAdresi("/ekspertiz-talebi")} className={className} title={user ? undefined : "İnceleme talebi için önce kayıt olun veya giriş yapın"}>{children}</Link>;
}

export function UyelikNotu() {
  const { user } = useAuth();
  return <p className="yb-membership-note">{user ? "Talebinizi bu hesabınızdan oluşturun; sürecinizi ve raporlarınızı müşteri panelinizden takip edin." : "Önce kayıt olun veya giriş yapın. Talebinizi ve raporlarınızı kendi müşteri panelinizden takip edin."}</p>;
}

export function HesapBaglantisi({ className, children }: { className?: string; children: ReactNode }) {
  const { user } = useAuth();
  return <Link href={user ? "/panel" : "/kayit-ol"} className={className}>{user ? "Müşteri panelim" : "Kayıt ol"} {children}</Link>;
}

"use client";

import Link from "next/link";

const menuler = [
  { href: "/yonetim", label: "Genel Bakis", code: "DB" },
  { href: "/yonetim/kaziyici", label: "Kaziyici Kontrol", code: "KZ" },
  { href: "/yonetim/veri-merkezi", label: "Veri Merkezi", code: "VM" },
  { href: "/yonetim/vitrin", label: "Vitrin Yonetimi", code: "VT" },
  { href: "/yonetim/odemeler", label: "Odeme Onaylari", code: "OD" },
];

export default function YonetimLayout({ children, aktif }: { children: React.ReactNode; aktif?: string }) {
  return (
    <div className="mx-auto max-w-7xl px-4 py-8">
      <div className="mb-8 flex items-center gap-3">
        <h1 className="text-2xl font-bold text-metin-birincil">Yonetim Paneli</h1>
        <span className="rounded bg-birincil/10 px-2 py-0.5 text-xs font-medium text-birincil">Admin</span>
      </div>

      <div className="grid gap-8 lg:grid-cols-[240px_1fr]">
        <nav className="space-y-1">
          {menuler.map((menu) => (
            <Link
              key={menu.href}
              href={menu.href}
              className={`flex items-center gap-3 rounded-lg px-4 py-2.5 text-sm font-medium transition-colors ${
                aktif === menu.href ? "bg-birincil text-white" : "text-metin-ikincil hover:bg-gray-50"
              }`}
            >
              <span
                className={`inline-flex h-6 w-7 items-center justify-center rounded text-[10px] font-bold ${
                  aktif === menu.href ? "bg-white/20 text-white" : "bg-black/5 text-metin-ikincil"
                }`}
              >
                {menu.code}
              </span>
              {menu.label}
            </Link>
          ))}
        </nav>
        <main>{children}</main>
      </div>
    </div>
  );
}

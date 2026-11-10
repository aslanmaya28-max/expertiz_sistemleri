import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./kurumsal.css";
import "./scroll-deneyimi.css";
import "./tasarim-temel.css";
import "./ana-sayfa.css";
import "./ic-sayfalar.css";
import "./rehber-turu.css";
import UstCubuk from "@/bilesenler/UstCubuk";
import AltBilgi from "@/bilesenler/AltBilgi";
import { ISLETME, SITE_URL } from "@/lib/hizmetBilgisi";

export const viewport: Viewport = {
  themeColor: "#102c36",
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  metadataBase: new URL("https://www.yerimebak.com.tr"),
  title: {
    default: "YerimeBak — Araç almadan önce doğru bilgiye ulaşın",
    template: "%s | YerimeBak",
  },
  description: "İkinci el araç almadan önce: İstanbul'da uzman personelle yerinde araç inceleme ve ekspertiz; Türkiye genelinde ilan fiyatının doğru olup olmadığını gösteren çevrim içi araç değerleme raporu (rapor başı 100 TL).",
  keywords: ["araç ekspertiz", "yerinde araç inceleme", "ikinci el araç ekspertiz İstanbul", "araç değerleme raporu", "2. el araç fiyatı", "oto ekspertiz"],
  authors: [{ name: "YerimeBak" }],
  manifest: "/manifest.json",
  openGraph: {
    type: "website",
    locale: "tr_TR",
    siteName: "YerimeBak",
    title: "YerimeBak — Araç almadan önce doğru bilgiye ulaşın",
    description: "Yerinde araç inceleme ve ekspertiz (İstanbul) ile çevrim içi araç değerleme raporu (Türkiye geneli). Siz gitmeden, biz yerinize bakalım.",
  },
  twitter: {
    card: "summary_large_image",
    title: "YerimeBak — Araç almadan önce doğru bilgiye ulaşın",
    description: "Yerinde araç inceleme ve çevrim içi araç değerleme. Siz gitmeden, biz yerinize bakalım.",
  },
  robots: { index: true, follow: true },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr" className="h-full antialiased">
      <head>
        <link rel="icon" href="/yerimebak-mark.svg" type="image/svg+xml" />
        <link rel="icon" href="/favicon.ico" sizes="any" />
        <link rel="apple-touch-icon" href="/icon-192.png" />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@graph": [
                ISLETME,
                { "@type": "WebSite", "@id": `${SITE_URL}/#site`, url: SITE_URL, name: "YerimeBak", inLanguage: "tr-TR", publisher: { "@id": ISLETME["@id"] } },
              ],
            }),
          }}
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', async () => {
                  try {
                    if (['localhost', '127.0.0.1'].includes(window.location.hostname)) {
                      const registrations = await navigator.serviceWorker.getRegistrations();
                      await Promise.all(registrations.filter(r => {
                        const worker = r.active || r.waiting || r.installing;
                        return worker && new URL(worker.scriptURL).pathname === '/sw.js';
                      }).map(r => r.unregister()));
                      if ('caches' in window) {
                        const keys = await caches.keys();
                        await Promise.all(keys.filter(k => k.startsWith('yerimebak-')).map(k => caches.delete(k)));
                      }
                    } else {
                      await navigator.serviceWorker.register('/sw.js');
                    }
                  } catch { /* Optional offline support must not prevent page loading. */ }
                });
              }
            `,
          }}
        />
      </head>
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <a href="#icerik" className="yb-skip-link">İçeriğe geç</a>
        <UstCubuk />
        <main id="icerik" className="flex-1" tabIndex={-1}>{children}</main>
        <AltBilgi />
      </body>
    </html>
  );
}

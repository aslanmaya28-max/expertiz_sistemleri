import type { Metadata, Viewport } from "next";
import "./globals.css";
import "./kurumsal.css";
import "./scroll-deneyimi.css";
import UstCubuk from "@/bilesenler/UstCubuk";
import AltBilgi from "@/bilesenler/AltBilgi";

export const viewport: Viewport = {
  themeColor: "#102c36",
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  metadataBase: new URL("https://www.yerimebak.com.tr"),
  title: {
    default: "YerimeBak — Siz Gitmeden, Biz Yerinize Bakalım",
    template: "%s | YerimeBak",
  },
  description: "Alanında uzman personelle yerinde araç incelemesi. İç ve dış ekspertiz, yapay zekâ değerleme ve kurumsal ekspertiz raporları müşteri panelinizde. İstanbul’da pilot hizmet.",
  keywords: ["araç değerleme", "otomobil analiz", "AI araç fiyat", "galerici araç değerleme", "2. el araç fiyat", "risk analizi"],
  authors: [{ name: "YerimeBak" }],
  manifest: "/manifest.json",
  openGraph: {
    type: "website",
    locale: "tr_TR",
    siteName: "YerimeBak",
    title: "YerimeBak — Siz Gitmeden, Biz Yerinize Bakalım",
    description: "Yerinde araç incelemesi, uzman personel ve dört rapor. Tüm süreç müşteri panelinizde.",
  },
  twitter: {
    card: "summary_large_image",
    title: "YerimeBak — Siz Gitmeden, Biz Yerinize Bakalım",
    description: "Yerinde inceleme. Belgeli süreç. Bilinçli karar.",
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
              "@type": "WebApplication",
              name: "YerimeBak",
              url: "https://www.yerimebak.com.tr",
              description: "Yerinde araç incelemesi, kurumsal ekspertiz ve müşteri panelinde rapor takibi",
              applicationCategory: "BusinessApplication",
              operatingSystem: "Web",
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

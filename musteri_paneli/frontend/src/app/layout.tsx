import type { Metadata, Viewport } from "next";
import "./globals.css";
import UstCubuk from "@/bilesenler/UstCubuk";
import AltBilgi from "@/bilesenler/AltBilgi";

export const viewport: Viewport = {
  themeColor: "#14b8a6",
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  metadataBase: new URL("https://www.yerimebak.com.tr"),
  title: {
    default: "YerimeBak — AI Destekli Araç Değerleme ve Ekspertiz",
    template: "%s | YerimeBak",
  },
  description: "20 yıllık galericilik tecrübesiyle, yapay zeka destekli araç değerleme, risk analizi ve piyasa karşılaştırması. Üye olana 3 ücretsiz analiz.",
  keywords: ["araç değerleme", "otomobil analiz", "AI araç fiyat", "galerici araç değerleme", "2. el araç fiyat", "risk analizi"],
  authors: [{ name: "YerimeBak" }],
  manifest: "/manifest.json",
  openGraph: {
    type: "website",
    locale: "tr_TR",
    siteName: "YerimeBak",
    title: "YerimeBak — AI Destekli Araç Değerleme ve Ekspertiz",
    description: "20 yıllık galericilik tecrübesiyle, yapay zeka destekli araç değerleme ve risk analizi.",
  },
  twitter: {
    card: "summary_large_image",
    title: "YerimeBak — AI Destekli Araç Değerleme ve Ekspertiz",
    description: "Yapay zeka ile araç değerleme, risk analizi ve piyasa karşılaştırması.",
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
              description: "AI destekli araç değerleme ve risk analizi platformu",
              applicationCategory: "BusinessApplication",
              operatingSystem: "Web",
              offers: {
                "@type": "AggregateOffer",
                priceCurrency: "TRY",
                lowPrice: "100",
                highPrice: "750",
              },
            }),
          }}
        />
        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js'));
              }
            `,
          }}
        />
      </head>
      <body className="min-h-full flex flex-col bg-background text-foreground">
        <UstCubuk />
        <main className="flex-1">{children}</main>
        <AltBilgi />
      </body>
    </html>
  );
}

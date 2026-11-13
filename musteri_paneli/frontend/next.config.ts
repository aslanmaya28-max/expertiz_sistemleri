import type { NextConfig } from "next";

const apiBackend = process.env.API_BACKEND_URL || "http://localhost:8000";

// İçerik güvenliği politikası (CSP) istek başına nonce gerektirdiği için
// src/proxy.ts içinde üretilir (src/lib/guvenlikPolitikasi.ts).

const nextConfig: NextConfig = {
  output: "standalone",
  turbopack: {
    root: __dirname,
  },
  // Değerleme isteği 20–60 sn sürer; vekilin varsayılan 30 sn sınırı bağlantıyı erken kesiyordu.
  experimental: {
    proxyTimeout: 180_000,
    // 4 × 8 MB fotoğraf ve multipart başlıkları; API ayrıca sıkı sınır uygular.
    proxyClientMaxBodySize: "33mb",
  },
  images: {
    // Ilan fotograflari zaten kaynak sitelerin CDN'inden gelir. Vercel gorsel
    // optimizasyonu kapali: binlerce ilan gorselinde kota/ucret asimi olmaz,
    // sunucumuz da yabanci gorseller icin vekil olarak kullanilamaz.
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "**" },
    ],
  },
  async headers() {
    return [{
      source: "/:path*",
      headers: [
        { key: "X-Frame-Options", value: "DENY" },
        { key: "X-Content-Type-Options", value: "nosniff" },
        { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
        // Fotoğraf yükleme dosya seçici kullanır; getUserMedia/capture gerekmez.
        { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
      ],
    }, {
      // PayTR bu sayfayı sitenin ödeme iframe'ine döndürür; sayfa üst
      // pencereye JS ile çıkar. DENY bu betiğin çalışmasını engellerdi.
      source: "/odeme/sonuc",
      headers: [
        { key: "X-Frame-Options", value: "SAMEORIGIN" },
      ],
    }];
  },
  // Vitrin kaldirildi (kaziyici yok); eski baglantilar ana sayfaya gider
  async redirects() {
    return [
      { source: "/vitrin", destination: "/", permanent: true },
      { source: "/arac-analiz/:id(\\d+)", destination: "/", permanent: true },
    ];
  },
  async rewrites() {
    return [
      {
        source: "/api/v1/:path*",
        destination: `${apiBackend}/api/v1/:path*`,
      },
    ];
  },
};

export default nextConfig;

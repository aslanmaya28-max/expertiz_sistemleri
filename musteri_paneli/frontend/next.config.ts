import type { NextConfig } from "next";

const apiBackend = process.env.API_BACKEND_URL || "http://localhost:8000";

// Önce rapor modu: statik Next sayfalarının satır içi betikleri ve JSON-LD
// henüz nonce/hash taşımıyor. Uygulamaya almadan önce bunlar uyarlanmalı;
// report-uri/report-to alıcısı yokken ihlaller yalnız tarayıcı konsolunda görülür.
const cspReportOnly = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
  "font-src 'self' https://fonts.gstatic.com",
  "img-src 'self' data: blob: https:",
  "connect-src 'self' https://api.yerimebak.com.tr",
  "frame-src 'self' https://www.paytr.com",
  "form-action 'self' https://www.paytr.com",
  "object-src 'none'",
  "base-uri 'self'",
  "frame-ancestors 'none'",
].join("; ");

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
        { key: "Content-Security-Policy-Report-Only", value: cspReportOnly },
      ],
    }, {
      // PayTR bu sayfayı sitenin ödeme iframe'ine döndürür; sayfa üst
      // pencereye JS ile çıkar. DENY bu betiğin çalışmasını engellerdi.
      source: "/odeme/sonuc",
      headers: [
        { key: "X-Frame-Options", value: "SAMEORIGIN" },
        { key: "Content-Security-Policy-Report-Only", value: cspReportOnly.replace("frame-ancestors 'none'", "frame-ancestors 'self'") },
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

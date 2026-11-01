import type { NextConfig } from "next";

const apiBackend = process.env.API_BACKEND_URL || "http://localhost:8000";

const nextConfig: NextConfig = {
  output: "standalone",
  turbopack: {
    root: __dirname,
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

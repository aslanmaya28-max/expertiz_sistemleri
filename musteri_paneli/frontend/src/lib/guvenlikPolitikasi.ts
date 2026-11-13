// Sitenin zorunlu içerik güvenliği politikası (CSP). proxy.ts her sayfa isteğinde
// yeni bir nonce üretir; Next kendi betiklerine bu nonce'u otomatik ekler.
// 'strict-dynamic' sayesinde nonce taşıyan betiklerin yüklediği parçalar da çalışır;
// sayfaya enjekte edilmiş, nonce'suz satır içi betik çalışmaz (XSS koruması).

export type CspSecenekleri = {
  nonce: string;
  gelistirme?: boolean;
  /** PayTR dönüş sayfası kendi sitemizin iframe'inde açılır. */
  ayniKokenCerceve?: boolean;
};

export function nonceUret(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  let ikili = "";
  for (const b of bytes) ikili += String.fromCharCode(b);
  return btoa(ikili);
}

export function guvenlikPolitikasi({ nonce, gelistirme = false, ayniKokenCerceve = false }: CspSecenekleri): string {
  if (!/^[A-Za-z0-9+/=]{16,}$/.test(nonce)) throw new Error("Geçersiz nonce");
  return [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${gelistirme ? " 'unsafe-eval'" : ""}`,
    // Bileşenler satır içi style kullanıyor; stil enjeksiyonu betik çalıştıramaz.
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    // İlan fotoğrafları kaynak sitelerin CDN'lerinden gelir.
    "img-src 'self' data: blob: https:",
    `connect-src 'self' https://api.yerimebak.com.tr${gelistirme ? " ws: http://localhost:8000 http://127.0.0.1:8000" : ""}`,
    "frame-src 'self' https://www.paytr.com",
    "form-action 'self' https://www.paytr.com",
    "worker-src 'self'",
    "manifest-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    `frame-ancestors ${ayniKokenCerceve ? "'self'" : "'none'"}`,
  ].join("; ");
}

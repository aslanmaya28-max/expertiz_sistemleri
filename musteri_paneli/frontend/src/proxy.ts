import { NextResponse, type NextRequest } from "next/server";
import { guvenlikPolitikasi, nonceUret } from "@/lib/guvenlikPolitikasi";

export function proxy(request: NextRequest) {
  const nonce = nonceUret();
  const politika = guvenlikPolitikasi({
    nonce,
    gelistirme: process.env.NODE_ENV === "development",
    ayniKokenCerceve: request.nextUrl.pathname === "/odeme/sonuc",
  });

  // Next, istek başlığındaki CSP'den nonce'u okuyup kendi betiklerine ekler.
  const istekBasliklari = new Headers(request.headers);
  istekBasliklari.set("x-nonce", nonce);
  istekBasliklari.set("Content-Security-Policy", politika);

  const yanit = NextResponse.next({ request: { headers: istekBasliklari } });
  yanit.headers.set("Content-Security-Policy", politika);
  return yanit;
}

export const config = {
  matcher: [
    {
      // API vekili, Next statik dosyaları ve public altındaki uzantılı dosyalar hariç.
      source: "/((?!api/|_next/static|_next/image|favicon[.]ico|.*[.][a-zA-Z0-9]+$).*)",
      missing: [
        { type: "header", key: "next-router-prefetch" },
        { type: "header", key: "purpose", value: "prefetch" },
      ],
    },
  ],
};

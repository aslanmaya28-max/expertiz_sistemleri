/** Only a local page may be used as the destination after authentication. */
export function siteIciDonus(value: string | null, fallback = "/panel"): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || /[\\\u0000-\u001f]/.test(value)) return fallback;
  try {
    const url = new URL(value, "https://www.yerimebak.com.tr");
    if (url.origin !== "https://www.yerimebak.com.tr" || url.pathname.startsWith("//")) return fallback;
    return `${url.pathname}${url.search}${url.hash}`;
  } catch { return fallback; }
}

export function uyelikAdresi(hedef: string, ekran: "kayit-ol" | "giris" = "kayit-ol"): string {
  return `/${ekran}?donus=${encodeURIComponent(siteIciDonus(hedef, "/ekspertiz-talebi"))}`;
}

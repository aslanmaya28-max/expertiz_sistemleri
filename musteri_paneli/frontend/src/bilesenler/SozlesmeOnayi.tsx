"use client";

import Link from "next/link";

/** Odeme oncesi zorunlu onay: On Bilgilendirme Formu + Mesafeli Satis Sozlesmesi. */
export default function SozlesmeOnayi({ checked, onChange, hizmet = false }: { checked: boolean; onChange: (v: boolean) => void; hizmet?: boolean }) {
  return (
    <label className="flex items-start gap-2 text-sm text-metin-ikincil">
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="mt-1" data-testid="sozlesme-onayi" />
      <span>
        <Link href="/mesafeli-satis" target="_blank" className="text-birincil underline">Ön Bilgilendirme Formu ve Mesafeli Satış Sözleşmesi</Link>&apos;ni
        okudum, onaylıyorum.{" "}
        {hizmet
          ? "Hizmetin ödeme onayıyla derhal ifasına başlanmasını kabul ediyorum; uzman göreve çıktıktan sonra cayma hakkının kullanılamayacağını biliyorum."
          : "Kredilerin ödeme onayıyla hesabıma anında yüklenmesini kabul ediyorum; kullanılan kredilerde cayma hakkının kullanılamayacağını biliyorum."}{" "}
        <Link href="/iptal-iade" target="_blank" className="text-birincil underline">İptal ve iade koşulları</Link>
      </span>
    </label>
  );
}

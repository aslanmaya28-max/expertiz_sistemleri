import type { ExpertizAppointment } from "@/lib/api";
import { bulunamamaDurumu, randevuMetni } from "@/lib/ekspertizRandevu";

export default function TalepRandevusu({ randevu, durumKodu, paymentStatus }: { randevu?: ExpertizAppointment | null; durumKodu?: string; paymentStatus?: string }) {
  const badge = bulunamamaDurumu(durumKodu, paymentStatus);
  return <>
    {badge && <p className="yb-badge mt-3 bg-amber-100 text-amber-900 !whitespace-normal" role="status">{badge}</p>}
    {randevu && <dl className="mt-3 grid gap-2 rounded-lg bg-arkaplan-acik p-3 text-sm sm:grid-cols-2 break-words">
      <div><dt className="text-metin-ikincil">Randevu</dt><dd>{randevuMetni(randevu.tarih_saat)}</dd></div>
      <div><dt className="text-metin-ikincil">Açık adres / buluşma noktası</dt><dd>{randevu.adres || "—"}</dd></div>
      <div><dt className="text-metin-ikincil">Satıcı</dt><dd>{randevu.satici_adi || "Ad belirtilmedi"}</dd></div>
      <div><dt className="text-metin-ikincil">Satıcı telefonu</dt><dd>{randevu.satici_telefon || "—"}</dd></div>
    </dl>}
  </>;
}

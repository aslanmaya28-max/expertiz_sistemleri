import type { Metadata } from "next";
import YasalSayfa, { SirketTablosu } from "@/bilesenler/YasalSayfa";
import { sirketBilgisi } from "@/lib/sirket";

export const metadata: Metadata = { title: "İletişim" };

export default async function IletisimSayfasi() {
  const s = await sirketBilgisi();
  return (
    <YasalSayfa baslik="İletişim">
      <p>Sorularınız, iptal/iade talepleriniz ve önerileriniz için bize ulaşabilirsiniz.</p>
      <SirketTablosu s={s} />
      <h2>Kişisel veriler</h2>
      <p>KVKK kapsamındaki başvurularınız için: <strong>{s.kvkkEposta}</strong></p>
    </YasalSayfa>
  );
}

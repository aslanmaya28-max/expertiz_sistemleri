import Link from "next/link";
import Ikon, { type IkonAdi } from "./Ikon";
import { KREDI_PAKETLERI } from "@/lib/hizmetBilgisi";

type Madde = { baslik: string; metin: string };
type Grup = { ad: string; ikon: IkonAdi; maddeler: Madde[] };

/** Değerleme raporunun içeriği; yalnız gerçekten raporda olanlar (09.11.2026 kodla doğrulandı). */
export const DEGERLEME_KAPSAMI: Grup[] = [
  {
    ad: "Fiyat", ikon: "terazi", maddeler: [
      { baslik: "Piyasaya göre konum", metin: "İlan fiyatı piyasanın altında mı, uyumlu mu, üstünde mi; en önemli riskler ve \"Şimdi ne yapmalı?\" önerisi." },
      { baslik: "Adil fiyat aralığı ve tavsiye alım fiyatı", metin: "Hasarsız değerden değer kaybı düşülerek bulunan hesaplanan değerle birlikte." },
      { baslik: "Hasarın fiyat etkisi", metin: "Boyalı, değişen her parça ve tramer kaydının değer kaybı, kalem kalem." },
      { baslik: "Benzer ilanlar", metin: "Aynı model, kasa, yakıt ve vites türünde; aracınızın yılına ve kilometresine göre düzeltilmiş, bağlantılarıyla." },
    ],
  },
  {
    ad: "Pazarlık", ikon: "etiket", maddeler: [
      { baslik: "Pazarlık planı", metin: "Açılış teklifi, hedef fiyat ve üst sınır (her zaman ilan fiyatının altında), adımlar ve gerekçeler." },
      { baslik: "Satıcıya hazır mesaj", metin: "Aracınıza ve teklifinize göre yazılır; kopyalayın ya da WhatsApp'ta paylaşın." },
      { baslik: "Enflasyona göre kazanç", metin: "6 aylık ve yıllık araç enflasyonuyla aracın 6 ay ve 1 yıl sonraki tahmini değeri ve kazancı." },
    ],
  },
  {
    ad: "Riskler ve kontrol", ikon: "kalkan", maddeler: [
      { baslik: "Modelin bilinen sorunları", metin: "Kullanıcı şikâyetleri, kaynakları ve önem dereceleriyle; aracın yakıt ve motor türüne uygun olanlar." },
      { baslik: "Bakım listesi", metin: "Bu kilometrede kontrol edilecek bakımlar; elektrikli ve hibrit araçlarda batarya ve şarj kontrolleri." },
      { baslik: "Satıcıya sorulacak sorular", metin: "Gerekirse kasa geçiş yılı uyarısı: o yıl iki kasa satıldıysa fiyatlar ayrı gösterilir." },
    ],
  },
  {
    ad: "Teslim", ikon: "belge", maddeler: [
      { baslik: "Ekranda ve PDF olarak", metin: "YerimeBak doğrulama koduyla; müşteri panelinizde saklanır." },
      { baslik: "Yerinde incelemeye tek adım", metin: "Riskli noktaları uzmanımıza doğrulatmak için araç bilgileri hazır doldurulmuş talep." },
    ],
  },
];

const tl = (n: number) => new Intl.NumberFormat("tr-TR").format(n) + " TL";

/** "100 TL'ye neler alırsınız?" kartı. kisa: yalnız madde başlıkları (Fiyatlar sayfası); baslik: kart kendi başlığını yazar. */
export default function DegerlemeKapsami({ kisa = false, baslik = true }: { kisa?: boolean; baslik?: boolean }) {
  const tek = KREDI_PAKETLERI.find((p) => p.kredi === 1)?.fiyat ?? 100;
  const enUcuz = Math.min(...KREDI_PAKETLERI.map((p) => p.fiyat / p.kredi));
  return (
    <div className="yb-kapsam">
      <div className="yb-kapsam-head">
        <div>
          {baslik && <h2 className="yb-kapsam-title">{tl(tek)}&apos;ye neler alırsınız?</h2>}
          <p className="yb-kapsam-lead">Tek bir araç için tam değerleme raporu. 1 kredi = 1 rapor; paketlerde rapor başı {tl(enUcuz)}&apos;ye kadar düşer.</p>
        </div>
        <p className="yb-kapsam-price" aria-label={`Rapor başı ${tl(tek)}`}>{tl(tek)}<small>/ rapor</small></p>
      </div>
      <div className="yb-kapsam-grid">
        {DEGERLEME_KAPSAMI.map((g) => (
          <section key={g.ad} className="yb-kapsam-group" aria-label={g.ad}>
            <h3><Ikon ad={g.ikon} />{g.ad}</h3>
            <ul className="yb-kapsam-list">
              {g.maddeler.map((m) => (
                <li key={m.baslik}><strong>{m.baslik}</strong>{!kisa && <span>{m.metin}</span>}</li>
              ))}
            </ul>
          </section>
        ))}
      </div>
      <p className="yb-kapsam-guarantee"><Ikon ad="kontrol" />Yeterli benzer ilan bulunamazsa rapor üretilmez, krediniz düşülmez.</p>
      <div className="yb-kapsam-actions">
        <Link href="/arac-analiz" className="yb-btn yb-btn-green">Araç değerleme raporu al <Ikon ad="ok" /></Link>
        <Link href="/ornek-rapor" className="yb-btn yb-btn-outline">Örnek raporu incele</Link>
      </div>
    </div>
  );
}

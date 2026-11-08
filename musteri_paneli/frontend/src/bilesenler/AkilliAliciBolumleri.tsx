"use client";

import Link from "next/link";
import { useEffect, useState, type ReactNode } from "react";
import type { SorunKategorisi, SorunOnemi, ValuationResult } from "@/lib/api";
import { ekspertizTalepAdresi, guvenliWebAdresi } from "@/lib/ekspertizOnDoldurma";
import Ikon, { type IkonAdi } from "./Ikon";

/** Sunucudaki vehicle_risk.GENEL_BAKIM_KONTROLU ile aynı: genel kontrol notu her maddede tekrarlanmaz */
const GENEL_BAKIM_KONTROLU = "Tarih, kilometre ve servis faturalarını karşılaştırın.";

function tl(value?: number | null) {
  if (value == null) return "-";
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

/** Müşteriye yalnız kaynağı doğrulanmış maddeler gösterilir (eski kayıtlarda düşük güvenli madde olabilir). */
const GOSTERILEN_GUVEN = new Set(["yuksek", "orta"]);

const SORUN_GRUPLARI: { kategori: SorunKategorisi; baslik: string }[] = [
  { kategori: "motor", baslik: "Motor" },
  { kategori: "sanziman", baslik: "Şanzıman" },
  { kategori: "kaporta", baslik: "Kaporta" },
  { kategori: "alt_takim", baslik: "Alt takım" },
  { kategori: "elektronik", baslik: "Elektronik" },
  { kategori: "diger", baslik: "Diğer" },
];
const ESKI_SORUN_GRUPLARI: { kategori: SorunKategorisi; baslik: string }[] = [
  { kategori: "mekanik_motor", baslik: "Mekanik ve motor" },
  { kategori: "elektronik", baslik: "Elektronik ve sensör" },
  { kategori: "trim_kasa", baslik: "Trim, şasi ve kasa" },
];
const ONEM_SIRASI = { yuksek: 0, orta: 1, dusuk: 2 };
type SorunMaddesi = { baslik: string; kategori?: SorunKategorisi; onem?: SorunOnemi };

/** Kısmi/eski kayıtlar bölünmez; sıralama her zaman yeni dizide yapılır. */
function sorunGruplari<T extends SorunMaddesi>(maddeler: T[], modern = false): { baslik?: string; maddeler: T[] }[] {
  const gruplar = modern || maddeler.some((m) => ["motor", "sanziman", "kaporta", "alt_takim", "diger"].includes(m.kategori || "")) ? SORUN_GRUPLARI : ESKI_SORUN_GRUPLARI;
  if (!maddeler.every((m) => gruplar.some((g) => g.kategori === m.kategori))) {
    return [{ maddeler }];
  }
  return gruplar.map((g) => ({
    baslik: g.baslik,
    maddeler: maddeler.filter((m) => m.kategori === g.kategori)
      .sort((a, b) => (a.onem ? ONEM_SIRASI[a.onem] : 3) - (b.onem ? ONEM_SIRASI[b.onem] : 3)),
  })).filter((g) => g.maddeler.length > 0);
}

function GrupluListe<T extends SorunMaddesi>({ gruplar, madde }: {
  gruplar: { baslik?: string; maddeler: T[] }[];
  madde: (m: T) => ReactNode;
}) {
  return gruplar.map((g) => (
    <div key={g.baslik || "eski-liste"}>
      {g.baslik && <h3 className="mt-4 text-sm font-semibold text-metin-birincil">{g.baslik}</h3>}
      <ul className="mt-3 space-y-4">{g.maddeler.map(madde)}</ul>
    </div>
  ));
}

function OnemEtiketi({ onem, kmUyarisi }: { onem?: SorunOnemi; kmUyarisi?: string }) {
  if (onem === "yuksek") return <span className="yb-risk-badge yb-risk-high">{kmUyarisi ? "Öncelikli kontrol" : "Yüksek masraf"}</span>;
  if (onem === "orta") return <span className="yb-risk-badge yb-risk-medium">Orta</span>;
  if (onem === "dusuk") return <span className="yb-risk-badge yb-risk-small">Küçük / konfor</span>;
  return null;
}

function KopyalaButonu({ metin, etiket = "Kopyala" }: { metin: string; etiket?: string }) {
  const [tamam, setTamam] = useState(false);
  return (
    <button
      type="button"
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(metin);
          setTamam(true);
          window.setTimeout(() => setTamam(false), 2000);
        } catch {
          setTamam(false);
        }
      }}
      className="rounded-lg border border-kenarlik-acik px-3 py-1.5 text-xs font-semibold text-metin-birincil"
    >
      {tamam ? "Kopyalandı" : etiket}
    </button>
  );
}

function Kaynaklar({ urller }: { urller?: string[] }) {
  const guvenli = (urller || []).map((u) => guvenliWebAdresi(u)).filter((u): u is string => Boolean(u));
  if (!guvenli.length) return null;
  return (
    <div className="mt-1 flex flex-wrap gap-x-3 text-xs">
      {guvenli.map((u, i) => (
        <a key={`${u}-${i}`} href={u} target="_blank" rel="noopener noreferrer nofollow" className="text-birincil underline">
          Kaynak {i + 1}
        </a>
      ))}
    </div>
  );
}

/** Pazarlık planı, model riskleri, bakım ve satıcı soruları (eski raporlarda bu alanlar olmayabilir). */
export function AkilliAliciBolumleri({ sonuc, bolum = "hepsi" }: { sonuc: ValuationResult; bolum?: "hepsi" | "plan" | "diger" | "model" | "yardimci" }) {
  const { pazarlikPlani: plan, modelRiskleri, kullaniciSikayetleri, bakim, saticiSorulari } = sonuc;
  const riskler = (modelRiskleri?.riskler || []).filter((r) => GOSTERILEN_GUVEN.has(r.guven));
  const modern = modelRiskleri?.gorunumSurumu === 2;
  const riskGruplari = sorunGruplari(riskler, modern);
  const sikayetGruplari = sorunGruplari(kullaniciSikayetleri || [], modern);
  const kritik = [
    ...riskler.filter((r) => r.onem === "yuksek"),
    ...(kullaniciSikayetleri || []).filter((s) => s.onem === "yuksek")
      .sort((a, b) => b.kaynakSayisi - a.kaynakSayisi),
  ].slice(0, 2);
  const uzmanMaddeleri = new Set<SorunMaddesi>([
    ...riskGruplari.flatMap((g) => g.maddeler),
    ...sikayetGruplari.flatMap((g) => g.maddeler),
  ].filter((m) => m.onem === "yuksek").slice(0, 3));
  const uzmanSatiri = (m: SorunMaddesi) => uzmanMaddeleri.has(m) && (
    <Link href={ekspertizTalepAdresi(sonuc.arac)} className="mt-2 block text-xs text-birincil underline">
      YerimeBak uzmanı bunu yerinde kontrol eder.
    </Link>
  );
  return (
    <>
      {(bolum === "hepsi" || bolum === "plan") && plan && (
        <section className="yb-report-card yb-negotiation" aria-label="Pazarlık planı">
          <h2 className="text-lg font-semibold text-metin-birincil"><Ikon ad="etiket" />Pazarlık planı</h2>
          {plan.uyari && <p className="mt-2 rounded-lg bg-yellow-50 p-3 text-sm text-yellow-900">{plan.uyari}</p>}
          <div className="yb-negotiation-targets mt-4">
            {[["Açılış teklifi", plan.acilisTeklifi], ["Hedef fiyat", plan.hedefFiyat], ["Üst sınırınız", plan.ustSinir]].map(([baslik, deger]) => (
              <div key={String(baslik)} data-target={baslik === "Hedef fiyat" ? "true" : undefined}>
                <div className="text-xs text-metin-ikincil">{baslik}</div>
                <div className="mt-1 text-2xl font-extrabold text-metin-birincil">{tl(deger as number)}</div>
              </div>
            ))}
          </div>
          {plan.potansiyelKazanc > 0 && (
            <p className="mt-3 text-sm text-metin-ikincil">Hedefe ulaşırsanız ilan fiyatına göre yaklaşık <strong>{tl(plan.potansiyelKazanc)}</strong> tasarruf edersiniz.</p>
          )}
          <ol className="mt-4 list-decimal space-y-1 pl-5 text-sm text-metin-birincil">
            {plan.adimlar.map((a) => <li key={a}>{a}</li>)}
          </ol>
          {plan.gerekceler.length > 0 && (
            <>
              <h3 className="mt-4 text-sm font-semibold text-metin-birincil">Gerekçeleriniz</h3>
              <ul className="mt-1 list-disc space-y-1 pl-5 text-sm text-metin-ikincil">{plan.gerekceler.map((g) => <li key={g}>{g}</li>)}</ul>
            </>
          )}
          {plan.kanitIlanlar.length > 0 && (
            <>
              <h3 className="mt-4 text-sm font-semibold text-metin-birincil">Satıcıya gösterebileceğiniz benzer ilanlar</h3>
              <ul className="mt-1 space-y-1 text-sm">
                {plan.kanitIlanlar.map((k, i) => {
                  const url = guvenliWebAdresi(k.url);
                  const metin = `${k.site || "İlan"} • ${k.yil ?? "-"} • ${k.km == null ? "km yok" : new Intl.NumberFormat("tr-TR").format(k.km) + " km"} • ${tl(k.fiyat)}`;
                  return <li key={`${k.url}-${i}`}>{url ? <a href={url} target="_blank" rel="noopener noreferrer nofollow" className="text-birincil underline">{metin}</a> : metin}</li>;
                })}
              </ul>
            </>
          )}
          <div className="mt-4 rounded-lg border border-kenarlik-acik p-4">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h3 className="text-sm font-semibold text-metin-birincil">Satıcıya gönderebileceğiniz mesaj</h3>
              <div className="flex gap-2">
                <KopyalaButonu metin={plan.saticiMesaji} />
                <a
                  href={`https://wa.me/?text=${encodeURIComponent(plan.saticiMesaji)}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="yb-report-share rounded-lg px-3 py-1.5 text-xs font-semibold"
                >
                  WhatsApp&apos;ta paylaş
                </a>
              </div>
            </div>
            <p className="mt-2 whitespace-pre-line text-sm text-metin-ikincil">{plan.saticiMesaji}</p>
          </div>
        </section>
      )}

      {bolum !== "plan" && bolum !== "yardimci" && <>
      {kritik.length > 0 && (
        <section className="yb-report-card yb-critical-risks" aria-label="Bu araçta en çok dikkat etmeniz gerekenler">
          <h2 className="text-lg font-semibold text-metin-birincil">Bu araçta en çok dikkat etmeniz gerekenler</h2>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-metin-birincil">
            {kritik.map((m, i) => <li key={`${m.baslik}-${i}`}>{m.baslik}</li>)}
          </ul>
        </section>
      )}

      {modelRiskleri && (
        <section className="yb-report-card yb-model-risks" aria-label={modern ? "Bu araçta dikkat edilecekler" : "Modelin bilinen sorunları"}>
          <h2 className="text-lg font-semibold text-metin-birincil"><Ikon ad="anahtar" />{modern ? "Bu araçta dikkat edilecekler" : "Modelin bilinen sorunları"}</h2>
          <p className="mt-1 text-xs text-metin-ikincil">Arıza teşhisi değildir; araç sürümü, şasi numarası ve servis kayıtlarıyla doğrulayın.</p>
          {riskler.length === 0 ? (
            <p className="mt-3 text-sm text-metin-ikincil">{modelRiskleri.mesaj || "Bu model/motor için kaynağı doğrulanmış bilinen sorun bulunamadı."}</p>
          ) : (
            <GrupluListe gruplar={riskGruplari} madde={(r) => {
                return (
                  <li key={r.baslik} className="yb-risk-row text-sm"><details>
                    <summary className="yb-risk-summary"><Ikon ad={kategoriIkonu(r.kategori)} />
                      <span className="font-semibold text-metin-birincil">{r.baslik}</span>
                      <OnemEtiketi onem={r.onem} kmUyarisi={r.kilometreUyarisi} />
                      <span className="yb-risk-evidence">{r.kanitSeviyesi || (r.guven === "yuksek" ? "Resmî kayıt" : "Teknik kaynak")}</span>
                      {r.kilometreUyarisi && <span className="font-semibold text-tehlike">{r.kilometreUyarisi}</span>}
                    </summary><div className="yb-risk-detail">
                    {r.aciklama && <p className="mt-1 text-metin-ikincil">{r.aciklama}</p>}
                    <dl className="mt-2 grid gap-1 text-metin-ikincil">
                      {r.etkiledigi && <div><dt className="inline font-medium text-metin-birincil">Kimleri etkiler: </dt><dd className="inline">{r.etkiledigi}</dd></div>}
                      {r.belirtiler?.length > 0 && <div><dt className="inline font-medium text-metin-birincil">Belirtiler: </dt><dd className="inline">{r.belirtiler.join("; ")}</dd></div>}
                      <div><dt className="inline font-medium text-metin-birincil">Nasıl kontrol edilir: </dt><dd className="inline">{r.kontrol}</dd></div>
                      <div><dt className="inline font-medium text-metin-birincil">Tahmini masraf: </dt><dd className="inline">{r.tahminiMaliyet ? `${r.tahminiMaliyet.min.toLocaleString("tr-TR")}–${r.tahminiMaliyet.max.toLocaleString("tr-TR")} TL` : "kaynakta belirtilmemiş"}</dd></div>
                      {r.tipikKm && <div><dt className="inline font-medium text-metin-birincil">Genelde </dt><dd className="inline">{r.tipikKm.min.toLocaleString("tr-TR")}{r.tipikKm.min === r.tipikKm.max ? " km civarı" : `–${r.tipikKm.max.toLocaleString("tr-TR")} km`}</dd></div>}
                    </dl>
                    {r.maliyetKaynagi && <div className="mt-2 text-xs text-metin-ikincil">Masraf kaynağı{r.maliyetKaynagi.onarim ? ` · ${r.maliyetKaynagi.onarim}` : ""}{r.maliyetKaynagi.tarih ? ` · Erişim: ${r.maliyetKaynagi.tarih}` : ""}<Kaynaklar urller={[r.maliyetKaynagi.url]} /></div>}
                    {r.kmKaynagi && <div className="mt-1 text-xs text-metin-ikincil">Kilometre kaynağı{r.kmKaynagi.tarih ? ` · Erişim: ${r.kmKaynagi.tarih}` : ""}<Kaynaklar urller={[r.kmKaynagi.url]} /></div>}
                    <Kaynaklar urller={r.kaynaklar} />
                    {uzmanSatiri(r)}
                    </div></details></li>
                );
              }} />
          )}
        </section>
      )}

      {kullaniciSikayetleri !== undefined && (
        <section className="yb-report-card" aria-label="Kullanıcıların en sık şikâyet ettiği konular">
          <h2 className="text-lg font-semibold text-metin-birincil">Kullanıcıların en sık şikâyet ettiği konular</h2>
          <p className="mt-1 text-xs text-metin-ikincil">Forum ve kullanıcı yorumlarından derlenmiştir; kullanıcı beyanıdır, arıza teşhisi değildir.</p>
          {kullaniciSikayetleri.length === 0 ? (
            <p className="mt-3 text-sm text-metin-ikincil">Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.</p>
          ) : (
            <GrupluListe gruplar={sikayetGruplari} madde={(s) => (
                <li key={s.baslik} className="yb-risk-row text-sm"><details>
                  <summary className="yb-risk-summary"><Ikon ad={kategoriIkonu(s.kategori)} />
                    <span className="font-semibold text-metin-birincil">{s.baslik}</span>
                    <OnemEtiketi onem={s.onem} />
                    <span className="text-xs text-metin-ikincil">Kullanıcı deneyimi</span>
                  </summary><div className="yb-risk-detail">
                  <p className="mt-1 text-metin-ikincil">{s.aciklama}</p>
                  <p className="mt-2 text-xs text-metin-ikincil">{s.kaynakSayisi} farklı kaynakta geçiyor</p>
                  <Kaynaklar urller={s.kaynaklar} />
                  {uzmanSatiri(s)}
                  </div></details></li>
              )} />
          )}
        </section>
      )}

      </>}
      {bolum !== "plan" && bolum !== "model" && <>
      {bakim && bakim.length > 0 && (
        <section className="yb-report-card" aria-label="Bakım">
          <h2 className="text-lg font-semibold text-metin-birincil">Bu kilometrede doğrulanacak bakımlar</h2>
          {/* Açıklama her maddede aynı: bir kez yazılır, maddeler kısa liste olur */}
          <p className="mt-2 text-sm text-metin-ikincil">
            {new Intl.NumberFormat("tr-TR").format(sonuc.arac.km)} km ve {sonuc.arac.yil} model araç için aşağıdaki işlemlerin son
            yapıldığı tarih ve kilometreyi servis faturalarından kontrol edin; üreticinin araç sürümüne özel bakım planını esas alın.
          </p>
          <ul className="mt-3 list-disc space-y-1 pl-5 text-sm text-metin-birincil">
            {bakim.map((b) => (
              <li key={b.baslik}>
                {b.baslik}
                {b.kontrol && b.kontrol !== GENEL_BAKIM_KONTROLU && <span className="text-metin-ikincil"> (kontrol: {b.kontrol})</span>}
              </li>
            ))}
          </ul>
        </section>
      )}

      {saticiSorulari && saticiSorulari.length > 0 && (
        <section className="yb-report-card" aria-label="Satıcıya sorular">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-lg font-semibold text-metin-birincil">Satıcıya sorulacak sorular</h2>
            <KopyalaButonu metin={saticiSorulari.map((s, i) => `${i + 1}. ${s}`).join("\n")} etiket="Soruları kopyala" />
          </div>
          <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-metin-ikincil">
            {saticiSorulari.map((s) => <li key={s}>{s}</li>)}
          </ol>
        </section>
      )}
      </>}
    </>
  );
}

/** Raporun sonunda: yerinde ekspertize geçiş (form araç bilgileriyle dolu açılır). */
export function SonrakiAdim({ sonuc }: { sonuc: ValuationResult }) {
  return (
    <section className="yb-report-final" aria-label="Sonraki adım">
      <p className="yb-report-final-label">Güvenli alım için son adım</p>
      <h2 className="text-lg font-semibold"><Ikon ad="kalkan" />Sonraki adım: aracı yerinde inceletin</h2>
      <p className="mt-2 text-sm text-metin-ikincil">
        Bu rapor ilan bilgilerine ve internetteki ilanlara dayanır. Boya, değişen, tramer ve bakım geçmişini YerimeBak
        uzmanının yerinde incelemesiyle doğrulatın; kurumsal ekspertiz raporu ve uzman bulgularıyla değerleme birlikte gelir.
      </p>
      <Link href={ekspertizTalepAdresi(sonuc.arac)} className="yb-button yb-button-mint mt-4">
        Bu aracı yerinde inceletelim <Ikon ad="ok" />
      </Link>
    </section>
  );
}

function kategoriIkonu(kategori?: SorunKategorisi): IkonAdi {
  if (kategori === "motor" || kategori === "mekanik_motor") return "motor";
  if (kategori === "sanziman") return "vites";
  if (kategori === "kaporta" || kategori === "trim_kasa") return "arac";
  if (kategori === "elektronik") return "grafik";
  return "anahtar";
}

const BEKLEME_ADIMLARI = [
  { metin: "Benzer ilanlar aranıyor", saniye: 0 },
  { metin: "Modelin bilinen sorunları araştırılıyor", saniye: 12 },
  { metin: "Rapor hazırlanıyor", saniye: 35 },
];

/** Analiz sürerken adımlı bekleme ekranı (aramalar aynı anda yürür; adımlar yaklaşık süreye göre ilerler). */
export function AnalizBekleme() {
  const [gecen, setGecen] = useState(0);
  useEffect(() => {
    const t = window.setInterval(() => setGecen((s) => s + 1), 1000);
    return () => window.clearInterval(t);
  }, []);
  const aktif = BEKLEME_ADIMLARI.reduce((i, a, j) => (gecen >= a.saniye ? j : i), 0);
  return (
    <div className="rounded-xl border border-kenarlik-acik bg-white p-5" role="status" aria-live="polite">
      <ol className="space-y-2 text-sm">
        {BEKLEME_ADIMLARI.map((a, i) => (
          <li key={a.metin} className={i < aktif ? "text-green-700" : i === aktif ? "font-semibold text-metin-birincil" : "text-metin-ikincil"}>
            {i < aktif ? "✓" : i === aktif ? "…" : "○"} {a.metin}
          </li>
        ))}
      </ol>
      <p className="mt-3 text-xs text-metin-ikincil">Genellikle 1 dakikadan kısa sürer. Sayfayı kapatmayın.</p>
    </div>
  );
}

/** Kasa geçiş yılı: iki kasanın bu araca göre orta fiyatı ve değerlemenin hangisine göre yapıldığı. */
export function GecisYiliKutusu({ gecis }: { gecis: NonNullable<ValuationResult["piyasa"]["gecisYili"]> }) {
  const ad = (h: { kasa?: string | null }, varsayilan: string) => h.kasa || varsayilan;
  const yillar = (h: { baslangic?: number | null; bitis?: number | null }) =>
    `${h.baslangic ?? "?"}–${h.bitis && h.bitis < new Date().getFullYear() ? h.bitis : ""}`;
  const secilen = gecis.secilen === "eski" ? gecis.eski : gecis.yeni;
  const diger = gecis.secilen === "eski" ? gecis.yeni : gecis.eski;
  const secilenAd = ad(secilen, gecis.secilen === "eski" ? "önceki kasa" : "yeni kasa");
  const digerAd = ad(diger, gecis.secilen === "eski" ? "yeni kasa" : "önceki kasa");
  const fark = gecis.yeni.ortaFiyat && gecis.eski.ortaFiyat ? Math.abs(gecis.yeni.ortaFiyat - gecis.eski.ortaFiyat) : null;
  const neden = {
    musteri: `Değerleme sizin seçtiğiniz ${secilenAd} kasasına göre yapıldı.`,
    ilan_fiyati: `Kasa seçilmediği için değerleme, ilan fiyatının daha yakın olduğu ${secilenAd} kasasına göre yapıldı. Aracınız ${digerAd} ise o kasanın ortalamasını esas alın.`,
    tek_havuz: `${digerAd} kasası için yeterli ilan bulunamadı; değerleme ${secilenAd} kasasına göre yapıldı.`,
    bulunamadi: "İki kasa için de yeterli ilan bulunamadı.",
  }[gecis.neden];
  return (
    <section className="rounded-xl border-2 border-yellow-300 bg-yellow-50 p-6" aria-label="Kasa geçiş yılı">
      <h2 className="text-lg font-semibold text-yellow-900">{gecis.yil} bu model için kasa geçiş yılı</h2>
      <p className="mt-1 text-sm text-yellow-900">O yıl iki farklı kasa satıldı ve fiyatları farklıdır. Fiyatlar bu araca (yıl ve km) göre düzeltilmiştir.</p>
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        {([["eski", gecis.eski, "Önceki kasa"], ["yeni", gecis.yeni, "Yeni kasa"]] as const).map(([kod, h, etiket]) => (
          <div key={kod} className={`rounded-lg bg-white p-4 ${gecis.secilen === kod ? "ring-2 ring-birincil" : "border border-kenarlik-acik"}`}>
            <div className="text-xs text-metin-ikincil">{etiket}{gecis.secilen === kod ? " • değerleme bu kasaya göre" : ""}</div>
            <div className="mt-1 font-semibold text-metin-birincil">{ad(h, etiket)} ({yillar(h)})</div>
            <div className="mt-1 text-2xl font-extrabold text-metin-birincil">{h.ortaFiyat ? tl(h.ortaFiyat) : "Yeterli ilan yok"}</div>
            {h.ortaFiyat ? <div className="text-xs text-metin-ikincil">{h.emsal} ilanın orta fiyatı</div> : null}
          </div>
        ))}
      </div>
      {fark ? <p className="mt-3 text-sm font-medium text-yellow-900">İki kasa arasındaki fark yaklaşık {tl(fark)}. Satıcı önceki kasayı yeni kasa fiyatına satıyorsa fazla ödersiniz.</p> : null}
      <p className="mt-2 text-sm text-yellow-900">{neden}</p>
      <p className="mt-2 text-xs text-yellow-900">Nasıl anlarsınız: ilan fotoğraflarında ön ızgara, far ve stop tasarımına bakın; satıcıdan ruhsattaki ilk tescil tarihini ve aracın kasa kodunu isteyin. Yerinde ekspertizde uzmanımız kasayı da doğrular.</p>
    </section>
  );
}

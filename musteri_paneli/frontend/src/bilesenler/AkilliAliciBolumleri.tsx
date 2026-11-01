"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import type { ValuationResult } from "@/lib/api";
import { ekspertizTalepAdresi, guvenliWebAdresi } from "@/lib/ekspertizOnDoldurma";

function tl(value?: number | null) {
  if (value == null) return "-";
  return new Intl.NumberFormat("tr-TR", { maximumFractionDigits: 0 }).format(value) + " ₺";
}

const GUVEN: Record<string, { etiket: string; renk: string; not?: string }> = {
  yuksek: { etiket: "Güven: yüksek", renk: "bg-green-100 text-green-800" },
  orta: { etiket: "Güven: orta", renk: "bg-yellow-100 text-yellow-800" },
  dusuk: { etiket: "Güven: düşük", renk: "bg-slate-100 text-slate-700", not: "Doğrulanmamış anlatım; servisle teyit edin." },
};

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
export function AkilliAliciBolumleri({ sonuc }: { sonuc: ValuationResult }) {
  const { pazarlikPlani: plan, modelRiskleri, bakim, saticiSorulari } = sonuc;
  return (
    <>
      {plan && (
        <section className="bg-white rounded-xl border-2 border-birincil/40 p-6" aria-label="Pazarlık planı">
          <h2 className="text-lg font-semibold text-metin-birincil">Pazarlık planı</h2>
          {plan.uyari && <p className="mt-2 rounded-lg bg-yellow-50 p-3 text-sm text-yellow-900">{plan.uyari}</p>}
          <div className="mt-4 grid gap-3 sm:grid-cols-3">
            {[["Açılış teklifi", plan.acilisTeklifi], ["Hedef fiyat", plan.hedefFiyat], ["Üst sınırınız", plan.ustSinir]].map(([baslik, deger]) => (
              <div key={String(baslik)} className="rounded-lg bg-arkaplan-acik p-4 text-center">
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
                  className="rounded-lg bg-green-600 px-3 py-1.5 text-xs font-semibold text-white"
                >
                  WhatsApp&apos;ta paylaş
                </a>
              </div>
            </div>
            <p className="mt-2 whitespace-pre-line text-sm text-metin-ikincil">{plan.saticiMesaji}</p>
          </div>
        </section>
      )}

      {modelRiskleri && (
        <section className="bg-white rounded-xl border border-kenarlik-acik p-6" aria-label="Modelin bilinen sorunları">
          <h2 className="text-lg font-semibold text-metin-birincil">Modelin bilinen sorunları</h2>
          <p className="mt-1 text-xs text-metin-ikincil">Arıza teşhisi değildir; araç sürümü, şasi numarası ve servis kayıtlarıyla doğrulayın.</p>
          {modelRiskleri.riskler.length === 0 ? (
            <p className="mt-3 text-sm text-metin-ikincil">{modelRiskleri.mesaj || "Bu model/motor için kaynağı doğrulanmış bilinen sorun bulunamadı."}</p>
          ) : (
            <ul className="mt-3 space-y-4">
              {modelRiskleri.riskler.map((r) => {
                const g = GUVEN[r.guven] || GUVEN.dusuk;
                return (
                  <li key={r.baslik} className="rounded-lg border border-kenarlik-acik p-4 text-sm">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-semibold text-metin-birincil">{r.baslik}</span>
                      <span className={`rounded-full px-2 py-0.5 text-xs font-semibold ${g.renk}`}>{g.etiket}</span>
                    </div>
                    {r.aciklama && <p className="mt-1 text-metin-ikincil">{r.aciklama}</p>}
                    <dl className="mt-2 grid gap-1 text-metin-ikincil">
                      {r.etkiledigi && <div><dt className="inline font-medium text-metin-birincil">Kimleri etkiler: </dt><dd className="inline">{r.etkiledigi}</dd></div>}
                      {r.belirtiler?.length > 0 && <div><dt className="inline font-medium text-metin-birincil">Belirtiler: </dt><dd className="inline">{r.belirtiler.join("; ")}</dd></div>}
                      <div><dt className="inline font-medium text-metin-birincil">Nasıl kontrol edilir: </dt><dd className="inline">{r.kontrol}</dd></div>
                      <div><dt className="inline font-medium text-metin-birincil">Tahmini masraf: </dt><dd className="inline">{r.tahminiMaliyet ? `${tl(r.tahminiMaliyet.min)} – ${tl(r.tahminiMaliyet.max)}` : "kaynakta belirtilmemiş"}</dd></div>
                    </dl>
                    {g.not && <p className="mt-1 text-xs text-metin-ikincil">{g.not}</p>}
                    <Kaynaklar urller={r.kaynaklar} />
                  </li>
                );
              })}
            </ul>
          )}
        </section>
      )}

      {bakim && bakim.length > 0 && (
        <section className="bg-white rounded-xl border border-kenarlik-acik p-6" aria-label="Bakım">
          <h2 className="text-lg font-semibold text-metin-birincil">Bu kilometrede doğrulanacak bakımlar</h2>
          <ul className="mt-3 space-y-2 text-sm">
            {bakim.map((b) => (
              <li key={b.baslik}>
                <span className="font-medium text-metin-birincil">{b.baslik}:</span>{" "}
                <span className="text-metin-ikincil">{b.aciklama}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      {saticiSorulari && saticiSorulari.length > 0 && (
        <section className="bg-white rounded-xl border border-kenarlik-acik p-6" aria-label="Satıcıya sorular">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-lg font-semibold text-metin-birincil">Satıcıya sorulacak sorular</h2>
            <KopyalaButonu metin={saticiSorulari.map((s, i) => `${i + 1}. ${s}`).join("\n")} etiket="Soruları kopyala" />
          </div>
          <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-metin-ikincil">
            {saticiSorulari.map((s) => <li key={s}>{s}</li>)}
          </ol>
        </section>
      )}
    </>
  );
}

/** Raporun sonunda: yerinde ekspertize geçiş (form araç bilgileriyle dolu açılır). */
export function SonrakiAdim({ sonuc }: { sonuc: ValuationResult }) {
  return (
    <section className="rounded-xl bg-birincil/5 border border-birincil/30 p-6" aria-label="Sonraki adım">
      <h2 className="text-lg font-semibold text-metin-birincil">Sonraki adım: aracı yerinde inceletin</h2>
      <p className="mt-2 text-sm text-metin-ikincil">
        Bu rapor ilan bilgilerine ve internetteki ilanlara dayanır. Boya, değişen, tramer ve bakım geçmişini YerimeBak
        uzmanının yerinde incelemesiyle doğrulatın; kurumsal ekspertiz raporu ve uzman bulgularıyla değerleme birlikte gelir.
      </p>
      <Link href={ekspertizTalepAdresi(sonuc.arac)} className="mt-4 inline-block rounded-lg bg-birincil px-5 py-2.5 text-sm font-semibold text-white">
        Bu aracı yerinde inceletelim
      </Link>
    </section>
  );
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

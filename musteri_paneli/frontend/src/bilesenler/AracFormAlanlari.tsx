"use client";

import { useId, useMemo, useState } from "react";
import { binlikNokta, katalogAra, sadeceRakam } from "@/lib/aracFormu";
import type { PartStatus } from "@/lib/api";

/**
 * Aranabilir seçim kutusu: yazdıkça liste süzülür, dokunarak seçilir.
 * Listede olmayan değer de yazıldığı gibi kabul edilir.
 */
export function AramaliSecim({
  value, onChange, secenekler, placeholder, required, className, ariaLabel, bosMesaj,
}: {
  value: string;
  onChange: (deger: string) => void;
  secenekler: string[];
  placeholder?: string;
  required?: boolean;
  className?: string;
  ariaLabel?: string;
  bosMesaj?: string;
}) {
  const [acik, setAcik] = useState(false);
  const [vurgu, setVurgu] = useState(0);
  const listeId = useId();
  const sonuclar = useMemo(() => katalogAra(secenekler, value), [secenekler, value]);
  const tamEslesme = sonuclar.length === 1 && sonuclar[0] === value;
  const listeGorunur = acik && !tamEslesme && (sonuclar.length > 0 || Boolean(value.trim()));

  function sec(deger: string) {
    onChange(deger);
    setAcik(false);
  }

  return (
    <div className="relative">
      <input
        role="combobox"
        aria-expanded={listeGorunur}
        aria-controls={listeId}
        aria-autocomplete="list"
        aria-label={ariaLabel}
        autoComplete="off"
        required={required}
        value={value}
        placeholder={placeholder}
        className={className}
        onChange={(e) => { onChange(e.target.value); setAcik(true); setVurgu(0); }}
        onFocus={() => setAcik(true)}
        onBlur={() => setAcik(false)}
        onKeyDown={(e) => {
          if (!listeGorunur || !sonuclar.length) return;
          if (e.key === "ArrowDown") { e.preventDefault(); setVurgu((v) => Math.min(v + 1, sonuclar.length - 1)); }
          else if (e.key === "ArrowUp") { e.preventDefault(); setVurgu((v) => Math.max(v - 1, 0)); }
          else if (e.key === "Enter") { e.preventDefault(); sec(sonuclar[vurgu]); }
          else if (e.key === "Escape") setAcik(false);
        }}
      />
      {listeGorunur && (
        <ul id={listeId} role="listbox"
          className="absolute z-20 mt-1 max-h-60 w-full overflow-auto rounded-lg border border-kenarlik-acik bg-white py-1 text-sm shadow-lg">
          {sonuclar.map((secenek, i) => (
            <li key={secenek} role="option" aria-selected={i === vurgu}
              // Dokunma/tıklama input'un blur'undan önce işlensin
              onMouseDown={(e) => { e.preventDefault(); sec(secenek); }}
              className={`cursor-pointer px-3 py-2.5 ${i === vurgu ? "bg-birincil/10 text-metin-birincil" : "text-metin-birincil"}`}>
              {secenek}
            </li>
          ))}
          {!sonuclar.length && (
            <li className="px-3 py-2.5 text-xs text-metin-ikincil">{bosMesaj || "Listede yok; yazdığınız gibi kullanılır."}</li>
          )}
        </ul>
      )}
    </div>
  );
}

/**
 * Sayı alanı: telefonda rakam klavyesi açılır, değer binlik noktalı görünür (24.000).
 * Forma ham rakamlar ("24000") verilir.
 */
export function SayiAlani({
  value, onChange, placeholder, required, className, ariaLabel, binlik = true, enFazlaHane = 12,
}: {
  value: string;
  onChange: (rakamlar: string) => void;
  placeholder?: string;
  required?: boolean;
  className?: string;
  ariaLabel?: string;
  binlik?: boolean;
  enFazlaHane?: number;
}) {
  const rakamlar = sadeceRakam(value, enFazlaHane);
  return (
    <input
      type="text"
      inputMode="numeric"
      autoComplete="off"
      aria-label={ariaLabel}
      required={required}
      placeholder={placeholder}
      className={className}
      value={binlik ? binlikNokta(rakamlar) : rakamlar}
      onChange={(e) => onChange(sadeceRakam(e.target.value, enFazlaHane))}
    />
  );
}

const DURUMLAR: { key: PartStatus; etiket: string; dolgu: string; kenar: string; dugme: string }[] = [
  { key: "boyali", etiket: "Boyalı", dolgu: "#fdba74", kenar: "#c2410c", dugme: "bg-orange-100 text-orange-900 border-orange-400" },
  { key: "lokal_boyali", etiket: "Lokal boyalı", dolgu: "#fde68a", kenar: "#a16207", dugme: "bg-yellow-100 text-yellow-900 border-yellow-400" },
  { key: "degisen", etiket: "Değişen", dolgu: "#fca5a5", kenar: "#b91c1c", dugme: "bg-red-100 text-red-900 border-red-400" },
  { key: "orijinal", etiket: "Orijinal (sil)", dolgu: "#ffffff", kenar: "#94a3b8", dugme: "bg-white text-metin-birincil border-kenarlik-acik" },
];
const DURUM = Object.fromEntries(DURUMLAR.map((d) => [d.key, d])) as Record<PartStatus, (typeof DURUMLAR)[number]>;

/** Üstten görünüş, ön taraf yukarıda; sol taraf ekranda solda (sürücü tarafı). */
const PARCA_SEKLI: Record<string, { x: number; y: number; w: number; h: number; rx?: number; kisa: string }> = {
  onTampon: { x: 42, y: 8, w: 116, h: 24, rx: 12, kisa: "Ön tampon" },
  kaput: { x: 48, y: 36, w: 104, h: 78, rx: 8, kisa: "Kaput" },
  tavan: { x: 52, y: 168, w: 96, h: 112, rx: 6, kisa: "Tavan" },
  bagajKapagi: { x: 48, y: 312, w: 104, h: 52, rx: 8, kisa: "Bagaj" },
  arkaTampon: { x: 42, y: 368, w: 116, h: 24, rx: 12, kisa: "Arka tampon" },
  solOnCamurluk: { x: 8, y: 36, w: 36, h: 86, rx: 8, kisa: "Sol ön çamurluk" },
  solOnKapi: { x: 8, y: 126, w: 36, h: 88, rx: 4, kisa: "Sol ön kapı" },
  solArkaKapi: { x: 8, y: 218, w: 36, h: 86, rx: 4, kisa: "Sol arka kapı" },
  solArkaCamurluk: { x: 8, y: 308, w: 36, h: 56, rx: 8, kisa: "Sol arka çamurluk" },
  sagOnCamurluk: { x: 156, y: 36, w: 36, h: 86, rx: 8, kisa: "Sağ ön çamurluk" },
  sagOnKapi: { x: 156, y: 126, w: 36, h: 88, rx: 4, kisa: "Sağ ön kapı" },
  sagArkaKapi: { x: 156, y: 218, w: 36, h: 86, rx: 4, kisa: "Sağ arka kapı" },
  sagArkaCamurluk: { x: 156, y: 308, w: 36, h: 56, rx: 8, kisa: "Sağ arka çamurluk" },
};

/** "Sol ön çamurluk" → "Ön çam." (dar yan parçalar için) */
function yanAd(kisa: string) {
  const ad = kisa.replace(/^(Sol|Sağ) /, "").replace("çamurluk", "çam.");
  return ad.charAt(0).toLocaleUpperCase("tr") + ad.slice(1);
}

/**
 * Dokunmatik araç şeması: önce durumu seçin, sonra parçaya dokunun.
 * Aynı durumdaki parçaya tekrar dokunmak parçayı orijinale döndürür.
 */
export function AracSemasi({
  parcalar, etiketler, onDegistir, rozet,
}: {
  parcalar: Record<string, PartStatus>;
  /** Parça anahtarı → tam ad (API'den); yoksa kısa ad kullanılır */
  etiketler?: Record<string, string>;
  onDegistir: (parca: string, durum: PartStatus) => void;
  /** İlandan okunan parçalar için kaynak rozeti */
  rozet?: (parca: string) => React.ReactNode;
}) {
  const [mod, setMod] = useState<PartStatus>("boyali");
  const ad = (k: string) => etiketler?.[k] || PARCA_SEKLI[k]?.kisa || k;
  const isaretli = Object.entries(parcalar).filter(([, d]) => d && d !== "orijinal");

  function dokun(parca: string) {
    const simdiki = parcalar[parca] || "orijinal";
    onDegistir(parca, simdiki === mod ? "orijinal" : mod);
  }

  return (
    <div>
      <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="İşaretlenecek durum">
        {DURUMLAR.map((d) => (
          <button key={d.key} type="button" role="radio" aria-checked={mod === d.key} onClick={() => setMod(d.key)}
            className={`rounded-full border-2 px-3 py-1.5 text-sm font-semibold ${d.dugme} ${mod === d.key ? "ring-2 ring-birincil ring-offset-1" : "opacity-70"}`}>
            {d.etiket}
          </button>
        ))}
      </div>
      <p className="mt-2 text-xs text-metin-ikincil">
        Durumu seçin, sonra araç üzerinde parçaya dokunun. Aynı parçaya tekrar dokunursanız orijinale döner.
      </p>

      <div className="mt-3 flex flex-col items-center gap-4 sm:flex-row sm:items-start">
        <svg viewBox="0 0 200 400" className="h-[420px] w-auto max-w-full touch-manipulation select-none" role="group" aria-label="Araç şeması (ön taraf yukarıda)">
          {/* Camlar (seçilemez) */}
          <path d="M54 118 L146 118 L140 164 L60 164 Z" fill="#e2e8f0" stroke="#cbd5e1" />
          <path d="M60 284 L140 284 L146 308 L54 308 Z" fill="#e2e8f0" stroke="#cbd5e1" />
          {Object.entries(PARCA_SEKLI).map(([k, s]) => {
            const durum = DURUM[parcalar[k] || "orijinal"];
            return (
              <g key={k} role="button" tabIndex={0} aria-label={`${ad(k)}: ${durum.etiket.replace(" (sil)", "")}`}
                onClick={() => dokun(k)}
                onKeyDown={(e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); dokun(k); } }}
                className="cursor-pointer outline-none focus-visible:opacity-80">
                <title>{ad(k)}</title>
                <rect x={s.x} y={s.y} width={s.w} height={s.h} rx={s.rx} fill={durum.dolgu} stroke={durum.kenar} strokeWidth={2} />
                {s.w > 60 ? (
                  <text x={s.x + s.w / 2} y={s.y + s.h / 2} textAnchor="middle" dominantBaseline="middle" fontSize="10" fill="#334155" pointerEvents="none">
                    {s.kisa}
                  </text>
                ) : (
                  // Dar yan parçalarda dikey kısa ad (ör. "Ön kapı")
                  <text x={s.x + s.w / 2} y={s.y + s.h / 2} textAnchor="middle" dominantBaseline="middle" fontSize="9" fill="#334155" pointerEvents="none"
                    transform={`rotate(-90 ${s.x + s.w / 2} ${s.y + s.h / 2})`}>
                    {yanAd(s.kisa)}
                  </text>
                )}
              </g>
            );
          })}
          <text x="100" y="152" textAnchor="middle" fontSize="8" fill="#94a3b8" pointerEvents="none">▲ ÖN</text>
          <text x="25" y="22" textAnchor="middle" fontSize="9" fontWeight="bold" fill="#64748b" pointerEvents="none">SOL</text>
          <text x="175" y="22" textAnchor="middle" fontSize="9" fontWeight="bold" fill="#64748b" pointerEvents="none">SAĞ</text>
        </svg>

        <div className="w-full text-sm sm:max-w-[240px]">
          <div className="font-semibold text-metin-birincil">İşaretli parçalar</div>
          {isaretli.length === 0 ? (
            <p className="mt-1 text-metin-ikincil">Yok — tüm parçalar orijinal sayılır.</p>
          ) : (
            <ul className="mt-1 space-y-1">
              {isaretli.map(([k, d]) => (
                <li key={k} className="flex items-center justify-between gap-2">
                  <span>
                    <span className="mr-1.5 inline-block h-3 w-3 rounded-sm align-middle" style={{ background: DURUM[d].dolgu, border: `1px solid ${DURUM[d].kenar}` }} />
                    {ad(k)}: {DURUM[d].etiket}{rozet?.(k)}
                  </span>
                  <button type="button" onClick={() => onDegistir(k, "orijinal")} className="text-xs text-birincil underline" aria-label={`${ad(k)} işaretini kaldır`}>
                    kaldır
                  </button>
                </li>
              ))}
            </ul>
          )}
          <p className="mt-2 text-xs text-metin-ikincil">Sol/sağ, sürücü koltuğundan bakıldığı gibidir.</p>
        </div>
      </div>
    </div>
  );
}

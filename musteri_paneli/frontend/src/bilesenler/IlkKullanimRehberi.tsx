"use client";

import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import {
  REHBER_ADIMLARI,
  rehberGorulmusMu,
  rehberiTamamla,
  sonAdimMetni,
  type RehberHedefi,
} from "@/lib/ilkKullanimRehberi";

const depo = () => window.localStorage;

/** Rehber baloncuğunun yerleşeceği boş yuva: bölümün en üstünde, belge akışında (formu örtmez). */
export function RehberYuvasi({ hedef }: { hedef: RehberHedefi }) {
  return <div data-rehber-yuva={hedef} />;
}

/**
 * Araç değerleme ekranında ilk ziyarette kendiliğinden açılan, atlanabilir 5 adımlı rehber (041).
 * Odak tuzağı ve kaydırma kilidi yoktur; "Nasıl kullanılır?" düğmesi (acKomutu artar) yeniden açar.
 */
export default function IlkKullanimRehberi({ hazir, bakiye, acKomutu }: { hazir: boolean; bakiye: number | null; acKomutu: number }) {
  const [adim, setAdim] = useState<number | null>(null);
  const [yuva, setYuva] = useState<HTMLElement | null>(null);
  const kapandi = useRef(false);
  const baslik = useRef<HTMLHeadingElement>(null);

  const kapat = useCallback((neden: "atla" | "bitir") => {
    rehberiTamamla(depo, neden);
    kapandi.current = true;
    setAdim(null);
  }, []);

  // İlk ziyaret: oturum ve form hazırken bir kez açılır.
  useEffect(() => {
    if (!hazir || kapandi.current || rehberGorulmusMu(depo)) return;
    const zamanlayici = window.setTimeout(() => setAdim((a) => a ?? 0), 700);
    return () => window.clearTimeout(zamanlayici);
  }, [hazir]);

  useEffect(() => {
    if (acKomutu > 0) setAdim(0);
  }, [acKomutu]);

  // Rapor gösterilirken ya da oturum kapanınca rehber sessizce kapanır.
  useEffect(() => {
    if (!hazir) setAdim(null);
  }, [hazir]);

  // Yuva boyanmadan önce bulunur (eski bölümde yeni metin görünmesin).
  useLayoutEffect(() => {
    if (adim === null) {
      setYuva(null);
      return;
    }
    const hedef = REHBER_ADIMLARI[adim].hedef;
    const bolum = document.querySelector<HTMLElement>(`[data-rehber="${hedef}"]`);
    const yer = document.querySelector<HTMLElement>(`[data-rehber-yuva="${hedef}"]`);
    if (!bolum || !yer) {
      setAdim(null);
      return;
    }
    setYuva(yer);
    bolum.dataset.rehberAktif = "true";
    return () => {
      delete bolum.dataset.rehberAktif;
    };
  }, [adim]);

  // Kaydırma, önceki baloncuk kalkıp yenisi yerleştikten sonra yapılır; yoksa sayfa kayar ve başlık menünün
  // altında kalırdı (10.11.2026 görsel denetim).
  useEffect(() => {
    if (adim === null || !yuva) return;
    const bolum = yuva.closest<HTMLElement>("[data-rehber]");
    const azHareket = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const kare = window.requestAnimationFrame(() => {
      bolum?.scrollIntoView({ block: "start", behavior: azHareket ? "auto" : "smooth" });
      baslik.current?.focus({ preventScroll: true });
    });
    return () => window.cancelAnimationFrame(kare);
  }, [adim, yuva]);

  useEffect(() => {
    if (adim === null) return;
    const tus = (e: KeyboardEvent) => { if (e.key === "Escape") kapat("atla"); };
    document.addEventListener("keydown", tus);
    return () => document.removeEventListener("keydown", tus);
  }, [adim, kapat]);

  if (adim === null || !yuva) return null;
  const a = REHBER_ADIMLARI[adim];
  const son = adim === REHBER_ADIMLARI.length - 1;
  const metin = son ? sonAdimMetni(bakiye) : a.metin;

  return createPortal(
    <div className="yb-rehber-baloncuk" role="dialog" aria-modal="false" aria-labelledby="yb-rehber-baslik">
      <div className="yb-rehber-ust">
        <span>Adım {adim + 1}/{REHBER_ADIMLARI.length}</span>
        <button type="button" onClick={() => kapat("atla")}>Rehberi kapat</button>
      </div>
      <h3 id="yb-rehber-baslik" ref={baslik} tabIndex={-1}>{a.baslik}</h3>
      <p>{metin}</p>
      <div className="yb-rehber-dugmeler">
        <button type="button" onClick={() => setAdim(adim - 1)} disabled={adim === 0}>Geri</button>
        {son
          ? <button type="button" className="yb-rehber-ileri" onClick={() => kapat("bitir")}>Anladım, başlayalım</button>
          : <button type="button" className="yb-rehber-ileri" onClick={() => setAdim(adim + 1)}>İleri</button>}
      </div>
    </div>,
    yuva,
  );
}

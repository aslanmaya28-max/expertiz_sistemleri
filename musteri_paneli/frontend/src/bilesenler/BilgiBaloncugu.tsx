"use client";

import { useEffect, useId, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { createPortal } from "react-dom";
import { baloncukKonumu } from "@/lib/ilkKullanimRehberi";

/**
 * Alan etiketinin yanındaki küçük "i": dokunmatikte dokununca, masaüstünde üzerine gelince/tıklayınca açılır.
 * Esc ya da dışarı tıklama kapatır. Açıklama ekran kenarından taşmaz (041).
 */
export default function BilgiBaloncugu({ baslik, children }: { baslik: string; children: ReactNode }) {
  const [acik, setAcik] = useState(false);
  const [sabit, setSabit] = useState(false);
  const [konum, setKonum] = useState<{ left: number; top: number; width: number } | null>(null);
  const dugme = useRef<HTMLButtonElement>(null);
  const kutu = useRef<HTMLDivElement>(null);
  const id = useId();

  useLayoutEffect(() => {
    if (!acik) {
      setKonum(null);
      return;
    }
    const hesapla = () => {
      const d = dugme.current;
      if (!d) return;
      const boy = kutu.current?.offsetHeight ?? 120;
      setKonum(baloncukKonumu(d.getBoundingClientRect(), window.innerWidth, window.innerHeight, 300, boy));
    };
    hesapla();
    window.addEventListener("resize", hesapla);
    window.addEventListener("scroll", hesapla, true);
    return () => {
      window.removeEventListener("resize", hesapla);
      window.removeEventListener("scroll", hesapla, true);
    };
  }, [acik]);

  useEffect(() => {
    if (!acik) return;
    const tus = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        setAcik(false);
        setSabit(false);
        dugme.current?.focus();
      }
    };
    const disari = (e: PointerEvent) => {
      const hedef = e.target as Node;
      if (!dugme.current?.contains(hedef) && !kutu.current?.contains(hedef)) {
        setAcik(false);
        setSabit(false);
      }
    };
    document.addEventListener("keydown", tus);
    document.addEventListener("pointerdown", disari);
    return () => {
      document.removeEventListener("keydown", tus);
      document.removeEventListener("pointerdown", disari);
    };
  }, [acik]);

  return (
    <>
      <button
        ref={dugme}
        type="button"
        className="yb-bilgi-dugme"
        aria-label={`Bilgi: ${baslik}`}
        aria-expanded={acik}
        aria-describedby={acik ? id : undefined}
        onClick={(e) => {
          // Etiketin içinde olsa da alanı tetiklemesin, formu göndermesin.
          e.preventDefault();
          e.stopPropagation();
          const yeni = !(acik && sabit);
          setAcik(yeni);
          setSabit(yeni);
        }}
        onPointerEnter={(e) => { if (e.pointerType === "mouse") setAcik(true); }}
        onPointerLeave={(e) => { if (e.pointerType === "mouse" && !sabit) setAcik(false); }}
      >
        i
      </button>
      {acik && typeof document !== "undefined" && createPortal(
        <div
          ref={kutu}
          id={id}
          role="tooltip"
          className="yb-bilgi-kutu"
          style={konum ? { left: konum.left, top: konum.top, width: konum.width } : { left: 0, top: 0, visibility: "hidden" }}
        >
          <strong>{baslik}</strong>
          <span>{children}</span>
        </div>,
        document.body,
      )}
    </>
  );
}

"use client";

import { useEffect, useState, useRef } from "react";

export default function IstatistikSayaci({ hedef, etiket, sure = 2000 }: { hedef: number; etiket: string; sure?: number }) {
  const [sayi, setSayi] = useState(0);
  const ref = useRef<HTMLDivElement>(null);
  const [gorunur, setGorunur] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) setGorunur(true);
    }, { threshold: 0.3 });
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!gorunur) return;
    const baslangic = Date.now();
    const adim = () => {
      const gecen = Date.now() - baslangic;
      const ilerleme = Math.min(gecen / sure, 1);
      const kolaylastirilmis = 1 - Math.pow(1 - ilerleme, 3);
      setSayi(Math.floor(kolaylastirilmis * hedef));
      if (ilerleme < 1) requestAnimationFrame(adim);
    };
    requestAnimationFrame(adim);
  }, [gorunur, hedef, sure]);

  return (
    <div ref={ref} className="text-center">
      <div className="text-3xl md:text-4xl font-bold text-birincil">{sayi.toLocaleString("tr-TR")}</div>
      <div className="text-sm text-metin-ikincil mt-1">{etiket}</div>
    </div>
  );
}

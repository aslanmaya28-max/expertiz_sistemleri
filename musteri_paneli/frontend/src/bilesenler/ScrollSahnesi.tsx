"use client";

import Script from "next/script";
import { useEffect, useRef, useState, type ReactNode } from "react";

type ScrollInstance = { destroy: () => void };
declare global {
  interface Window {
    ScrollCraft?: { mount: (root: HTMLElement) => ScrollInstance; instances: ScrollInstance[] };
  }
}

/** The engine owns only its attributes inside this marketing page. */
export default function ScrollSahnesi({ children }: { children: ReactNode }) {
  const root = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  useEffect(() => {
    if (!ready || !root.current || !window.ScrollCraft) return;
    const element = root.current;
    const preference = matchMedia("(prefers-reduced-motion: reduce)");
    const mobile = matchMedia("(max-width: 760px)");
    const short = matchMedia("(max-height: 799px)");
    let instance: ScrollInstance | null = null;
    const sync = () => {
      instance?.destroy();
      instance = null;
      // The full content remains normal flow on phones and with reduced motion.
      if (preference.matches) {
        element.dataset.motion = "reduced";
        element.querySelectorAll<HTMLElement>("[data-sc-parallax]").forEach((node) => node.style.removeProperty("transform"));
        element.querySelectorAll<HTMLElement>("[data-sc-act]").forEach((node) => node.style.removeProperty("height"));
        return;
      }
      element.dataset.motion = "ready";
      // Every narrative section has its own timeline; React never re-renders
      // on scroll. The upstream engine publishes --sc-p to these sections.
      element.querySelectorAll<HTMLElement>(":scope > section:not(.yb-hero):not([data-report-scene])").forEach((section) => {
        section.dataset.scAct = "flow";
        section.dataset.pageMotion = "true";
      });
      element.dataset.pin = mobile.matches || short.matches ? "disabled" : "enabled";
      const report = element.querySelector<HTMLElement>("[data-report-scene]");
      if (report) {
        report.style.removeProperty("height");
        report.dataset.scAct = mobile.matches || short.matches ? "flow" : "pin";
      }
      instance = window.ScrollCraft!.mount(element);
    };
    sync();
    preference.addEventListener("change", sync);
    mobile.addEventListener("change", sync);
    short.addEventListener("change", sync);
    return () => {
      instance?.destroy();
      preference.removeEventListener("change", sync);
      mobile.removeEventListener("change", sync);
      short.removeEventListener("change", sync);
      delete element.dataset.motion;
      delete element.dataset.pin;
    };
  }, [ready]);
  return <div className="yb-home" ref={root}>
    {children}
    <Script src="/vendor/scrollcraft/scrollcraft.js" strategy="afterInteractive" onReady={() => setReady(true)} />
  </div>;
}

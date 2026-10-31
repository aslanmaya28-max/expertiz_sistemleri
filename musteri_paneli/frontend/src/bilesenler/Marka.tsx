export default function Marka({ acik = false }: { acik?: boolean }) {
  return (
    <span className={`yb-brand${acik ? " yb-brand-light" : ""}`}>
      <svg viewBox="0 0 1017 748" aria-hidden="true" className="yb-brand-symbol">
        <path fill="currentColor" d="M40,42 L521,41 Q537,42 535,61 L410,388 Q404,426 448,442 L466,442 L621,54 Q627,40 641,40 L977,41 L773,511 Q748,568 725,606 Q673,666 633,684 Q583,706 523,708 L195,708 Q103,706 71,601 L54,538 L388,536 Q438,534 452,478 L285,478 Q163,478 131,346 Z" />
      </svg>
      <span className="yb-brand-type">Yerime<span>Bak</span><small>YERİNİZE BAKAN UZMAN GÖZ</small></span>
    </span>
  );
}

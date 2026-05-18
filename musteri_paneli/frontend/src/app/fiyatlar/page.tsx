import FiyatKartlari from "@/bilesenler/FiyatKartlari";

export default function FiyatlarSayfasi() {
  return (
    <div>
      <div className="max-w-7xl mx-auto px-4 py-8 text-center">
        <h1 className="text-3xl font-bold text-metin-birincil">Fiyatlar</h1>
        <p className="text-metin-ikincil mt-2">Esnek kredi paketleri ile istediğiniz kadar analiz yapın</p>
      </div>
      <FiyatKartlari />
    </div>
  );
}

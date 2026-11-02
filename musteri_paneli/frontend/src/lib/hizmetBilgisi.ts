/**
 * YerimeBak'ın hizmetleri hakkında sitede, yapılandırılmış veride (JSON-LD) ve llms.txt'de
 * tutarlı kullanılan tek kaynak. Yalnız gerçekten sunulan hizmetler ve bölgeler yazılır.
 */

export const SITE_URL = "https://www.yerimebak.com.tr";
export const ANA_MESAJ = "Araç almadan önce doğru bilgiye ulaşın.";
export const SLOGAN = "Siz gitmeden, biz yerinize bakalım.";

export const BOLGE_YERINDE = "İstanbul'un tamamı (Avrupa ve Anadolu yakası)";
export const BOLGE_DEGERLEME = "Türkiye geneli (çevrim içi)";

/**
 * Yerinde inceleme hizmet bedeli, KDV hariç. Asıl değer admin panelindeki Fiyatlandırma ekranından gelir
 * (ödeme ekranı oradan okur); bu sabit yalnız tanıtım sayfaları ve yapılandırılmış veri içindir.
 * Admin panelinde değişirse burayı da güncelleyin.
 */
export const HIZMET_BEDELI_TL = 5000;
export const KDV_ORANI = 0.2;

/** Kredi paketleri: herkes için aynı (kullanıcı kararı). 1 değerleme raporu = 1 kredi. */
export const KREDI_PAKETLERI = [
  { kredi: 1, fiyat: 100 },
  { kredi: 5, fiyat: 400 },
  { kredi: 10, fiyat: 750 },
];

export const ISLETME = {
  "@type": "Organization",
  "@id": `${SITE_URL}/#isletme`,
  name: "YerimeBak",
  url: SITE_URL,
  logo: `${SITE_URL}/icon-512.png`,
  slogan: SLOGAN,
  description:
    "İkinci el araç alacaklar için yerinde araç inceleme ve ekspertiz hizmeti (İstanbul) ile ilan bilgilerine ve benzer ilanlara dayanan çevrim içi araç değerleme raporu (Türkiye geneli).",
  areaServed: [{ "@type": "City", name: "İstanbul" }, { "@type": "Country", name: "Türkiye" }],
} as const;

export interface SSS { soru: string; yanit: string }

export function sssJsonLd(sorular: SSS[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: sorular.map((s) => ({
      "@type": "Question",
      name: s.soru,
      acceptedAnswer: { "@type": "Answer", text: s.yanit },
    })),
  };
}

/** Ana sayfa ve hizmet sayfalarında ortak, müşterilerin gerçekten sorduğu sorular. */
export const ORTAK_SORULAR: SSS[] = [
  {
    soru: "Değerleme ile ekspertiz arasındaki fark nedir?",
    yanit:
      "Araç değerleme raporu ilan bilgilerine, sizin girdiğiniz boya/değişen/tramer beyanına ve internetteki benzer ilanlara dayanır; aracın piyasaya göre fiyatını, hasarın fiyat etkisini ve pazarlık aralığını birkaç dakikada verir, ancak araç görülmez. Yerinde inceleme ve ekspertizde ise uzman personelimiz aracı bulunduğu yerde inceler; boya, kaporta, iç ve dış durum yerinde tespit edilir ve fotoğraflarla belgelenir. Beyan edilen bilgi ile yerinde doğrulanan bilgi raporlarımızda ayrı gösterilir.",
  },
  {
    soru: "İlan fiyatının doğru olup olmadığını nasıl anlarım?",
    yanit:
      "Araç değerleme raporu, aynı model ve kasadaki benzer ilanları bulur, her birini sizin aracınızın yılına ve kilometresine göre düzeltir ve bildirilen hasarın fiyat etkisini düşer. Sonuçta adil fiyat aralığını, tavsiye alım fiyatını ve ilanın piyasaya göre konumunu görürsünüz. Benzer ilanların bağlantıları raporda yer alır.",
  },
  {
    soru: "Başka bir şehirdeki aracı inceletebilir miyim?",
    yanit:
      "Yerinde inceleme şu anda yalnız İstanbul'da (Avrupa ve Anadolu yakası) sunulmaktadır. İstanbul dışındaki bir araç için çevrim içi araç değerleme raporunu kullanabilirsiniz; aracı görmeden fiyatın piyasaya uygunluğunu ve pazarlık aralığını öğrenirsiniz.",
  },
  {
    soru: "Araç almadan önce hangi raporlara bakmalıyım?",
    yanit:
      "Fiyat için piyasa karşılaştırması (değerleme), aracın gerçek durumu için yerinde inceleme ve kurumsal ekspertiz raporu birlikte en sağlıklı tabloyu verir. İlanı ilk elemede değerleme raporuyla, ciddi düşündüğünüz aracı ise satın almadan önce yerinde incelemeyle değerlendirmenizi öneririz. Tramer (hasar kaydı) sorgusunu ve servis bakım kayıtlarını da isteyin.",
  },
  {
    soru: "Raporlar aracın sorunsuz olduğunu garanti eder mi?",
    yanit:
      "Hayır. Raporlar inceleme anındaki bulguları ve kontrol kapsamını ortaya koyar; her türlü arızanın tespitini ya da aracın gelecekteki durumunu garanti etmez. Değerleme raporu beyana ve ilan verisine dayanır, uzman incelemesi yerine geçmez. Amacımız satın alma kararınızı daha fazla bilgiyle vermenizdir.",
  },
];

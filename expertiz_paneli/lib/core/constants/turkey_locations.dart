import 'package:flutter/material.dart';
import '../../models/bolge_model.dart';
import '../../models/il_model.dart';

/// Statik Türkiye İl ve İlçe Veri Servisi
class TurkeyLocationService {
  static List<BolgeModel> getAllBolgeler() {
    return [
      BolgeModel(
        id: "1",
        ad: "Marmara",
        renk: Colors.blue,
        iller: [
          _createIl("34", "İstanbul", "34", 1, ["Adalar", "Arnavutköy", "Ataşehir", "Avcılar", "Bağcılar", "Bahçelievler", "Bakırköy", "Başakşehir", "Bayrampaşa", "Beşiktaş", "Beykoz", "Beylikdüzü", "Beyoğlu", "Büyükçekmece", "Çatalca", "Çekmeköy", "Esenler", "Esenyurt", "Eyüpsultan", "Fatih", "Gaziosmanpaşa", "Güngören", "Kadıköy", "Kağıthane", "Kartal", "Küçükçekmece", "Maltepe", "Pendik", "Sancaktepe", "Sarıyer", "Silivri", "Sultanbeyli", "Sultangazi", "Şile", "Şişli", "Tuzla", "Ümraniye", "Üsküdar", "Zeytinburnu"]),
          _createIl("16", "Bursa", "16", 1, ["Büyükorhan", "Gemlik", "Gürsu", "Harmancık", "İnegöl", "İznik", "Karacabey", "Keles", "Kestel", "Mudanya", "Mustafakemalpaşa", "Nilüfer", "Orhaneli", "Orhangazi", "Osmangazi", "Yenişehir", "Yıldırım"]),
          _createIl("41", "Kocaeli", "41", 1, ["Başiskele", "Çayırova", "Darıca", "Derince", "Dilovası", "Gebze", "Gölcük", "İzmit", "Kandıra", "Karamürsel", "Kartepe", "Körfez"]),
          _createIl("10", "Balıkesir", "10", 1, ["Altıeylül", "Ayvalık", "Balya", "Bandırma", "Bigadiç", "Burhaniye", "Dursunbey", "Edremit", "Erdek", "Gömeç", "Gönen", "Havran", "İvrindi", "Karesi", "Kepsut", "Manyas", "Marmara", "Savaştepe", "Sındırgı", "Susurluk"]),
          _createIl("59", "Tekirdağ", "59", 1, ["Çerkezköy", "Çorlu", "Ergene", "Hayrabolu", "Kapaklı", "Malkara", "Marmaraereğlisi", "Muratlı", "Saray", "Süleymanpaşa", "Şarköy"]),
          _createIl("54", "Sakarya", "54", 1, ["Adapazarı", "Akyazı", "Arifiye", "Erenler", "Ferizli", "Geyve", "Hendek", "Karapürçek", "Karasu", "Kaynarca", "Kocaali", "Pamukova", "Sapanca", "Serdivan", "Söğütlü", "Taraklı"]),
          _createIl("17", "Çanakkale", "17", 1, ["Ayvacık", "Bayramiç", "Biga", "Bozcaada", "Çan", "Eceabat", "Ezine", "Gelibolu", "Gökçeada", "Lapseki", "Yenice"]),
          _createIl("22", "Edirne", "22", 1, ["Enez", "Havsa", "İpsala", "Keşan", "Lalapaşa", "Meriç", "Merkez", "Süloğlu", "Uzunköprü"]),
          _createIl("39", "Kırklareli", "39", 1, ["Babaeski", "Demirköy", "Kofçaz", "Lüleburgaz", "Merkez", "Pehlivanköy", "Pınarhisar", "Vize"]),
          _createIl("11", "Bilecik", "11", 1, ["Bozüyük", "Gölpazarı", "İnhisar", "Merkez", "Osmaneli", "Pazaryeri", "Söğüt", "Yenipazar"]),
          _createIl("77", "Yalova", "77", 1, ["Altınova", "Armutlu", "Çiftlikköy", "Çınarcık", "Merkez", "Termal"]),
        ],
      ),
      BolgeModel(
        id: "2",
        ad: "İç Anadolu",
        renk: Colors.red,
        iller: [
          _createIl("06", "Ankara", "06", 2, ["Akyurt", "Altındağ", "Ayaş", "Bala", "Beypazarı", "Çamlıdere", "Çankaya", "Çubuk", "Elmadağ", "Etimesgut", "Evren", "Gölbaşı", "Güdül", "Haymana", "Kahramankazan", "Kalecik", "Keçiören", "Kızılcahamam", "Mamak", "Nallıhan", "Polatlı", "Pursaklar", "Sincan", "Şereflikoçhisar", "Yenimahalle"]),
          _createIl("38", "Kayseri", "38", 2, ["Akkışla", "Bünyan", "Develi", "Felahiye", "Hacılar", "İncesu", "Kocasinan", "Melahatgazi", "Özvatan", "Pınarbaşı", "Sarıoğlan", "Sarız", "Talas", "Tomarza", "Yahyalı", "Yeşilhisar"]),
          _createIl("42", "Konya", "42", 2, ["Ahırlı", "Akören", "Akşehir", "Altınekin", "Beyşehir", "Bozkır", "Cihanbeyli", "Çeltik", "Çumra", "Derbent", "Derebucak", "Doğanhisar", "Emirgazi", "Ereğli", "Güneysınır", "Hadim", "Halkapınar", "Hüyük", "Ilgın", "Kadınhanı", "Karapınar", "Karatay", "Kulu", "Meram", "Sarayönü", "Selçuklu", "Seydişehir", "Taşkent", "Tuzlukçu", "Yalıhüyük", "Yunak"]),
          _createIl("26", "Eskişehir", "26", 2, ["Alpu", "Beylikova", "Çifteler", "Günyüzü", "Han", "İnönü", "Mahmudiye", "Mihalgazi", "Mihalıççık", "Odunpazarı", "Sarıcakaya", "Seyitgazi", "Sivrihisar", "Tepebaşı"]),
          _createIl("58", "Sivas", "58", 2, ["Akıncılar", "Altınyayla", "Divriği", "Doğanşar", "Gemerek", "Gölova", "Gürün", "Hafik", "İmranlı", "Kangal", "Koyulhisar", "Merkez", "Suşehri", "Şarkışla", "Ulaş", "Yıldızeli", "Zara"]),
          _createIl("66", "Yozgat", "66", 2, ["Akdağmadeni", "Aydıncık", "Boğazlıyan", "Çandır", "Çayıralan", "Çekerek", "Kadışehri", "Saraykent", "Sarıkaya", "Sorgun", "Şefaatli", "Yenifakılı", "Yerköy"]),
          _createIl("68", "Aksaray", "68", 2, ["Ağaçören", "Eskil", "Gülağaç", "Güzelyurt", "Merkez", "Ortaköy", "Sarıyahşi", "Sultanhanı"]),
          _createIl("70", "Karaman", "70", 2, ["Ayrancı", "Başyayla", "Ermenek", "Kazımkarabekir", "Merkez", "Sarıveliler"]),
          _createIl("71", "Kırıkkale", "71", 2, ["Bahşılı", "Balışeyh", "Çelebi", "Delice", "Karakeçili", "Keskin", "Merkez", "Sulakyurt", "Yahşihan"]),
          _createIl("40", "Kırşehir", "40", 2, ["Akçakent", "Akpınar", "Boztepe", "Çiçekdağı", "Kaman", "Merkez", "Mucur"]),
          _createIl("51", "Niğde", "51", 2, ["Altunhisar", "Bor", "Çamardı", "Çiftlik", "Merkez", "Ulukışla"]),
          _createIl("50", "Nevşehir", "50", 2, ["Acıgöl", "Avanos", "Derinkuyu", "Gülşehir", "Hacıbektaş", "Kozaklı", "Merkez", "Ürgüp"]),
          _createIl("18", "Çankırı", "18", 2, ["Atkaracalar", "Bayramören", "Çerkeş", "Eldivan", "Ilgaz", "Kızılırmak", "Korgun", "Kurşunlu", "Merkez", "Orta", "Şabanözü", "Yapraklı"]),
        ],
      ),
      BolgeModel(
        id: "3",
        ad: "Ege",
        renk: Colors.orange,
        iller: [
          _createIl("35", "İzmir", "35", 3, ["Aliağa", "Balçova", "Bayındır", "Bayraklı", "Bergama", "Beydağ", "Bornova", "Buca", "Çeşme", "Çiğli", "Dikili", "Foça", "Gaziemir", "Güzelbahçe", "Karabağlar", "Karaburun", "Karşıyaka", "Kemalpaşa", "Kınık", "Kiraz", "Konak", "Menderes", "Menemen", "Narlıdere", "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"]),
          _createIl("09", "Aydın", "09", 3, ["Bozdoğan", "Buharkent", "Çine", "Didim", "Efeler", "Germencik", "İncirliova", "Karacasu", "Karpuzlu", "Koçarlı", "Köşk", "Kuşadası", "Kuyucak", "Nazilli", "Söke", "Sultanhisar", "Yenipazar"]),
          _createIl("48", "Muğla", "48", 3, ["Bodrum", "Dalaman", "Datça", "Fethiye", "Kavaklıdere", "Köyceğiz", "Marmaris", "Menteşe", "Milas", "Ortaca", "Seydikemer", "Ula", "Yatağan"]),
          _createIl("20", "Denizli", "20", 3, ["Acıpayam", "Babadağ", "Baklan", "Bekilli", "Beyağaç", "Bozkurt", "Buldan", "Çal", "Çameli", "Çardak", "Çivril", "Güney", "Honaz", "Kale", "Merkezefendi", "Pamukkale", "Sarayköy", "Serinhisar", "Tavas"]),
          _createIl("45", "Manisa", "45", 3, ["Ahmetli", "Akhisar", "Alaşehir", "Demirci", "Gölmarmara", "Gördes", "Kırkağaç", "Köprübaşı", "Kula", "Salihli", "Sarıgöl", "Saruhanlı", "Selendi", "Soma", "Şehzadeler", "Turgutlu", "Yunusemre"]),
          _createIl("03", "Afyonkarahisar", "03", 3, ["Başmakçı", "Bayat", "Bolvadin", "Çay", "Çobanlar", "Dazkırı", "Dinar", "Emirdağ", "Evciler", "Hocalar", "İhsaniye", "İscehisar", "Kızılören", "Merkez", "Sandıklı", "Sinanpaşa", "Sultandağı", "Şuhut"]),
          _createIl("43", "Kütahya", "43", 3, ["Altıntaş", "Aslanapa", "Çavdarhisar", "Domaniç", "Dumlupınar", "Emet", "Gediz", "Hisarcık", "Merkez", "Pazarlar", "Şaphane", "Simav", "Tavşanlı"]),
          _createIl("64", "Uşak", "64", 3, ["Banaz", "Eşme", "Karahallı", "Merkez", "Sivaslı", "Ulubey"]),
        ],
      ),
      BolgeModel(
        id: "4",
        ad: "Akdeniz",
        renk: Colors.cyan,
        iller: [
          _createIl("07", "Antalya", "07", 4, ["Akseki", "Aksu", "Alanya", "Demre", "Döşemealtı", "Elmalı", "Finike", "Gazipaşa", "Gündoğmuş", "İbradı", "Kaş", "Kemer", "Kepez", "Konyaaltı", "Korkuteli", "Kumluca", "Manavgat", "Muratpaşa", "Serik"]),
          _createIl("01", "Adana", "01", 4, ["Aladağ", "Ceyhan", "Çukurova", "Feke", "İmamoğlu", "Karaisalı", "Karataş", "Kozan", "Pozantı", "Saimbeyli", "Sarıçam", "Seyhan", "Tufanbeyli", "Yumurtalık", "Yüreğir"]),
          _createIl("33", "Mersin", "33", 4, ["Akdeniz", "Anamur", "Aydıncık", "Bozyazı", "Çamlıyayla", "Erdemli", "Gülnar", "Mezitli", "Mut", "Silifke", "Tarsus", "Toroslar", "Yenişehir"]),
          _createIl("31", "Hatay", "31", 4, ["Altınözü", "Antakya", "Arsuz", "Belen", "Defne", "Dörtyol", "Erzin", "Hassa", "İskenderun", "Kırıkhan", "Kumlu", "Payas", "Reyhanlı", "Samandağ", "Yayladağı"]),
          _createIl("46", "Kahramanmaraş", "46", 4, ["Afşin", "Andırın", "Çağlayancerit", "Dulkadiroğlu", "Ekinözü", "Elbistan", "Göksun", "Nurhak", "Onikişubat", "Pazarcık", "Türkoğlu"]),
          _createIl("80", "Osmaniye", "80", 4, ["Bahçe", "Düziçi", "Hasanbeyli", "Kadirli", "Merkez", "Sumbas", "Toprakkale"]),
          _createIl("32", "Isparta", "32", 4, ["Aksu", "Atabey", "Eğirdir", "Gelendost", "Gönen", "Keçiborlu", "Merkez", "Şarkikaraağaç", "Senirkent", "Sütçüler", "Uluborlu", "Yalvaç", "Yenişarbademli"]),
          _createIl("15", "Burdur", "15", 4, ["Ağlasun", "Altınyayla", "Bucak", "Çavdır", "Çeltikçi", "Gölhisar", "Karamanlı", "Kemer", "Merkez", "Tefenni", "Yeşilova"]),
        ],
      ),
      BolgeModel(
        id: "5",
        ad: "Karadeniz",
        renk: Colors.green,
        iller: [
          _createIl("55", "Samsun", "55", 5, ["19 Mayıs", "Alaçam", "Asarcık", "Atakum", "Ayvacık", "Bafra", "Canik", "Çarşamba", "Havza", "İlkadım", "Kavak", "Ladik", "Salıpazarı", "Tekkeköy", "Terme", "Vezirköprü", "Yakakent"]),
          _createIl("61", "Trabzon", "61", 5, ["Akçaabat", "Araklı", "Arsin", "Beşikdüzü", "Çarşıbaşı", "Çaykara", "Dernekpazarı", "Düzköy", "Hayrat", "Köprübaşı", "Maçka", "Of", "Ortahisar", "Sürmene", "Şalpazarı", "Tonya", "Vakfıkebir", "Yomra"]),
          _createIl("52", "Ordu", "52", 5, ["Akkuş", "Altınordu", "Aybastı", "Çamaş", "Çatalpınar", "Çaybaşı", "Fatsa", "Gölköy", "Gülyalı", "Gürgentepe", "İkizce", "Kabadüz", "Kabataş", "Korgan", "Kumru", "Mesudiye", "Perşembe", "Ulubey", "Ünye"]),
          _createIl("67", "Zonguldak", "67", 5, ["Alaplı", "Çaycuma", "Devrek", "Ereğli", "Gökçebey", "Kilimli", "Kozlu", "Merkez"]),
          _createIl("14", "Bolu", "14", 5, ["Dörtdivan", "Gerede", "Göynük", "Kıbrıscık", "Mengen", "Merkez", "Mudurnu", "Seben", "Yeniçağa"]),
          _createIl("81", "Düzce", "81", 5, ["Akçakoca", "Cumayeri", "Çilimli", "Gölyaka", "Gümüşova", "Kaynaşlı", "Merkez", "Yığılca"]),
          _createIl("53", "Rize", "53", 5, ["Ardeşen", "Çamlıhemşin", "Çayeli", "Derepazarı", "Fındıklı", "Güneysu", "Hemşin", "İkizdere", "İyidere", "Kalkandere", "Merkez", "Pazar"]),
          _createIl("05", "Amasya", "05", 5, ["Göynücek", "Gümüşhacıköy", "Hamamözü", "Merkez", "Merzifon", "Suluova", "Taşova"]),
          _createIl("28", "Giresun", "28", 5, ["Alucra", "Bulancak", "Çamoluk", "Çanakçı", "Dereli", "Doğankent", "Espiye", "Eynesil", "Görele", "Güce", "Keşap", "Merkez", "Piraziz", "Şebinkarahisar", "Tirebolu", "Yağlıdere"]),
          _createIl("29", "Gümüşhane", "29", 5, ["Kelkit", "Köse", "Kürtün", "Merkez", "Şiran", "Torul"]),
          _createIl("37", "Kastamonu", "37", 5, ["Abana", "Ağlı", "Araç", "Azdavay", "Bozkurt", "Cide", "Çatalzeytin", "Daday", "Devrekani", "Doğanyurt", "Hanönü", "İhsangazi", "İnebolu", "Küre", "Merkez", "Pınarbaşı", "Şenpazar", "Seydiler", "Taşköprü", "Tosya"]),
          _createIl("74", "Bartın", "74", 5, ["Amasra", "Kurucaşile", "Merkez", "Ulus"]),
          _createIl("78", "Karabük", "78", 5, ["Eflani", "Eskipazar", "Merkez", "Ovacık", "Safranbolu", "Yenice"]),
          _createIl("57", "Sinop", "57", 5, ["Ayancık", "Boyabat", "Dikmen", "Durağan", "Erfelek", "Gerze", "Merkez", "Saraydüzü", "Türkeli"]),
          _createIl("60", "Tokat", "60", 5, ["Almus", "Artova", "Başçiftlik", "Erbaa", "Merkez", "Niksar", "Pazar", "Reşadiye", "Sulusaray", "Turhal", "Yeşilyurt", "Zile"]),
          _createIl("08", "Artvin", "08", 5, ["Ardanuç", "Arhavi", "Borçka", "Hopa", "Kemalpaşa", "Merkez", "Murgul", "Şavşat", "Yusufeli"]),
          _createIl("69", "Bayburt", "69", 5, ["Aydıntepe", "Demirözü", "Merkez"]),
        ],
      ),
      BolgeModel(
        id: "6",
        ad: "Güneydoğu Anadolu",
        renk: Colors.purple,
        iller: [
          _createIl("27", "Gaziantep", "27", 6, ["Araban", "İslahiye", "Karkamış", "Nizip", "Nurdağı", "Oğuzeli", "Şahinbey", "Şehitkamil", "Yavuzeli"]),
          _createIl("21", "Diyarbakır", "21", 6, ["Bağlar", "Bismil", "Çermik", "Çınar", "Çüngüş", "Dicle", "Eğil", "Ergani", "Hani", "Hazro", "Kayapınar", "Kocaköy", "Kulp", "Lice", "Silvan", "Sur", "Yenişehir"]),
          _createIl("63", "Şanlıurfa", "63", 6, ["Akçakale", "Birecik", "Bozova", "Ceylanpınar", "Eyyübiye", "Halfeti", "Haliliye", "Harran", "Hilvan", "Karaköprü", "Siverek", "Suruç", "Viranşehir"]),
          _createIl("47", "Mardin", "47", 6, ["Artuklu", "Dargeçit", "Derik", "Kızıltepe", "Mazıdağı", "Midyat", "Nusaybin", "Ömerli", "Savur", "Yeşilli"]),
          _createIl("72", "Batman", "72", 6, ["Beşiri", "Gercüş", "Hasankeyf", "Kozluk", "Merkez", "Sason"]),
          _createIl("02", "Adıyaman", "02", 6, ["Besni", "Çelikhan", "Gerger", "Gölbaşı", "Kahta", "Merkez", "Samsat", "Sincik", "Tut"]),
          _createIl("56", "Siirt", "56", 6, ["Baykan", "Eruh", "Kurtalan", "Merkez", "Pervari", "Şirvan", "Tillo"]),
          _createIl("73", "Şırnak", "73", 6, ["Beytüşşebap", "Cizre", "Güçlükonak", "İdil", "Merkez", "Silopi", "Uludere"]),
          _createIl("79", "Kilis", "79", 6, ["Elbeyli", "Musabeyli", "Polateli", "Merkez"]),
        ],
      ),
      BolgeModel(
        id: "7",
        ad: "Doğu Anadolu",
        renk: Colors.brown,
        iller: [
          _createIl("25", "Erzurum", "25", 7, ["Aşkale", "Aziziye", "Çat", "Hınıs", "Horasan", "İspir", "Karaçoban", "Karayazı", "Köprüköy", "Narman", "Oltu", "Olur", "Palandöken", "Pasinler", "Pazaryolu", "Şenkaya", "Tekman", "Tortum", "Uzundere", "Yakutiye"]),
          _createIl("44", "Malatya", "44", 7, ["Akçadağ", "Arapgir", "Arguvan", "Battalgazi", "Darende", "Doğanşehir", "Doğanyol", "Hekimhan", "Kale", "Kuluncak", "Pütürge", "Yazıhan", "Yeşilyurt"]),
          _createIl("23", "Elazığ", "23", 7, ["Ağın", "Alacakaya", "Arıcak", "Baskil", "Karakoçan", "Keban", "Kovancılar", "Maden", "Merkez", "Palu", "Sivrice"]),
          _createIl("65", "Van", "65", 7, ["Bahçesaray", "Başkale", "Çaldıran", "Çatak", "Edremit", "Erciş", "Gevaş", "Gürpınar", "İpekyolu", "Muradiye", "Özalp", "Saray", "Tuşba"]),
          _createIl("24", "Erzincan", "24", 7, ["Çayırlı", "İliç", "Kemah", "Kemaliye", "Merkez", "Otlukbeli", "Refahiye", "Tercan", "Üzümlü"]),
          _createIl("13", "Bitlis", "13", 7, ["Adilcevaz", "Ahlat", "Güroymak", "Hizan", "Merkez", "Mutki", "Tatvan"]),
          _createIl("12", "Bingöl", "12", 7, ["Adaklı", "Genç", "Karlıova", "Kiğı", "Merkez", "Solhan", "Yayladere", "Yedisu"]),
          _createIl("04", "Ağrı", "04", 7, ["Diyadin", "Doğubayazıt", "Eleşkirt", "Hamur", "Merkez", "Patnos", "Taşlıçay", "Tutak"]),
          _createIl("36", "Kars", "36", 7, ["Akyaka", "Arpaçay", "Digor", "Kağızman", "Merkez", "Sarıkamış", "Selim", "Susuz"]),
          _createIl("30", "Hakkâri", "30", 7, ["Çukurca", "Derecik", "Merkez", "Şemdinli", "Yüksekova"]),
          _createIl("49", "Muş", "49", 7, ["Bulanık", "Hasköy", "Korkut", "Malazgirt", "Merkez", "Varto"]),
          _createIl("62", "Tunceli", "62", 7, ["Çemişgezek", "Hozat", "Mazgirt", "Merkez", "Nazımiye", "Ovacık", "Pertek", "Pülümür"]),
          _createIl("75", "Ardahan", "75", 7, ["Çıldır", "Damal", "Göle", "Hanak", "Merkez", "Posof"]),
          _createIl("76", "Iğdır", "76", 7, ["Aralık", "Karakoyunlu", "Merkez", "Tuzluca"]),
        ],
      ),
    ];
  }

  static IlModel _createIl(String id, String ad, String plaka, int bolgeId, List<String> ilceler) {
    return IlModel(
      id: id,
      ad: ad,
      plaka: plaka,
      bolgeId: bolgeId,
      ilceler: ilceler,
      renk: Colors.grey[300]!,
      toplamPersonel: 0,
      aktifPersonel: 0,
    );
  }
}

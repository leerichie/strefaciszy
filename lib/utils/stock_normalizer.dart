// // lib/utils/stock_normalizer.dart
// import 'package:excel/excel.dart';
// import 'package:strefa_ciszy/models/stock_item.dart';

// class StockNormalizer {
//   static final Map<RegExp, String> _brandMap = {
//     RegExp(r'\b(bose)\b', caseSensitive: false): 'Bose',
//     RegExp(r'\b(rti)\b', caseSensitive: false): 'RTI',
//     RegExp(r'\b(helu\s*sound|helusound)\b', caseSensitive: false): 'Helusound',
//     RegExp(r'\b(helukabel)\b', caseSensitive: false): 'Helukabel',
//     RegExp(r'\b(abb)\b', caseSensitive: false): 'ABB',
//     RegExp(r'\b(hikvision)\b', caseSensitive: false): 'HIKVISION',
//     RegExp(r'\b(aiv)\b', caseSensitive: false): 'AIV',
//     RegExp(r'\b(ark)\b', caseSensitive: false): 'Grenton',

//     RegExp(r'\b(alpine)\b', caseSensitive: false): 'Alpine',
//     RegExp(r'\b(audio\s*system)\b', caseSensitive: false): 'Audio System',

//     // A/V & Hi-Fi
//     RegExp(r'\b(denon)\b', caseSensitive: false): 'Denon',
//     RegExp(r'\b(marantz)\b', caseSensitive: false): 'Marantz',
//     RegExp(r'\b(yamaha)\b', caseSensitive: false): 'Yamaha',
//     RegExp(r'\b(onkyo)\b', caseSensitive: false): 'Onkyo',
//     RegExp(r'\b(pioneer)\b', caseSensitive: false): 'Pioneer',
//     RegExp(r'\b(nad)\b', caseSensitive: false): 'NAD',
//     RegExp(r'\b(cambridge\s*audio)\b', caseSensitive: false): 'Cambridge Audio',
//     RegExp(r'\b(arcam)\b', caseSensitive: false): 'Arcam',
//     RegExp(r'\b(rotel)\b', caseSensitive: false): 'Rotel',
//     RegExp(r'\b(harman[\s-]*kardon|harman)\b', caseSensitive: false):
//         'Harman Kardon',
//     RegExp(r'\b(sonos)\b', caseSensitive: false): 'Sonos',

//     // Speakers
//     RegExp(r'\b(jbl)\b', caseSensitive: false): 'JBL',
//     RegExp(r'\b(klipsch)\b', caseSensitive: false): 'Klipsch',
//     RegExp(r'\b(kef)\b', caseSensitive: false): 'KEF',
//     RegExp(r'\b(bowers\s*&\s*wilkins|b&w|bowers)\b', caseSensitive: false):
//         'Bowers & Wilkins',
//     RegExp(r'\b(polk(\s*audio)?)\b', caseSensitive: false): 'Polk Audio',
//     RegExp(r'\b(dali)\b', caseSensitive: false): 'DALI',
//     RegExp(r'\b(focal)\b', caseSensitive: false): 'Focal',
//     RegExp(r'\b(monitor\s*audio)\b', caseSensitive: false): 'Monitor Audio',
//     RegExp(r'\b(q\s*acoustics|qacoustics)\b', caseSensitive: false):
//         'Q Acoustics',
//     RegExp(r'\b(elac)\b', caseSensitive: false): 'ELAC',
//     RegExp(r'\b(definitive\s*technology)\b', caseSensitive: false):
//         'Definitive Technology',
//     RegExp(r'\b(magnat)\b', caseSensitive: false): 'Magnat',

//     // Headphones / Mics / Pro-audio
//     RegExp(r'\b(sennheiser)\b', caseSensitive: false): 'Sennheiser',
//     RegExp(r'\b(audio[\s-]*technica|audiotechnica)\b', caseSensitive: false):
//         'Audio-Technica',
//     RegExp(r'\b(akg)\b', caseSensitive: false): 'AKG',
//     RegExp(r'\b(shure)\b', caseSensitive: false): 'Shure',
//     RegExp(r'\b(beyerdynamic)\b', caseSensitive: false): 'beyerdynamic',
//     RegExp(r'\b(behringer)\b', caseSensitive: false): 'Behringer',
//     RegExp(r'\b(focusrite)\b', caseSensitive: false): 'Focusrite',
//     RegExp(r'\b(tascam)\b', caseSensitive: false): 'Tascam',
//     RegExp(r'\b(zoom)\b', caseSensitive: false): 'Zoom',

//     // Streamers / DACs
//     RegExp(r'\b(bluesound)\b', caseSensitive: false): 'Bluesound',
//     RegExp(r'\b(ifi\s*audio|ifi)\b', caseSensitive: false): 'iFi Audio',
//     RegExp(r'\b(ifi)\b', caseSensitive: false): 'iFi Audio',
//     RegExp(r'\b(aune)\b', caseSensitive: false): 'Aune',
//     RegExp(r'\b(cyrus)\b', caseSensitive: false): 'Cyrus',

//     // TVs / Projectors
//     RegExp(r'\b(sony)\b', caseSensitive: false): 'Sony',
//     RegExp(r'\b(samsung)\b', caseSensitive: false): 'Samsung',
//     RegExp(r'\b(lg)\b', caseSensitive: false): 'LG',
//     RegExp(r'\b(philips)\b', caseSensitive: false): 'Philips',
//     RegExp(r'\b(panasonic)\b', caseSensitive: false): 'Panasonic',
//     RegExp(r'\b(epson)\b', caseSensitive: false): 'Epson',
//     RegExp(r'\b(benq)\b', caseSensitive: false): 'BenQ',
//     RegExp(r'\b(optoma)\b', caseSensitive: false): 'Optoma',

//     // Cabling / Connectors
//     RegExp(r'\b(supra)\b', caseSensitive: false): 'SUPRA',
//     RegExp(r'\b(mogami)\b', caseSensitive: false): 'Mogami',
//     RegExp(r'\b(van\s*damme|vandamme)\b', caseSensitive: false): 'Van Damme',
//     RegExp(r'\b(neutrik)\b', caseSensitive: false): 'Neutrik',
//     RegExp(r'\b(prolink)\b', caseSensitive: false): 'Prolink',
//     RegExp(r'\b(ugreen)\b', caseSensitive: false): 'UGREEN',
//     RegExp(r'\b(hama)\b', caseSensitive: false): 'Hama',

//     // Streaming boxes
//     RegExp(r'\b(apple\s*tv)\b', caseSensitive: false): 'Apple TV',
//     RegExp(r'\b(chromecast)\b', caseSensitive: false): 'Chromecast',
//     RegExp(r'\b(nvidia\s*shield)\b', caseSensitive: false): 'NVIDIA Shield',
//   };

//   // cat
//   static final Map<RegExp, String> _categoryMap = {
//     RegExp(r'\b(wzmacniacz|amplifier)\b', caseSensitive: false): 'Wzmacniacz',
//     RegExp(r'\b(kabel|przew[oó]d|przewod)\b', caseSensitive: false): 'Kabel',
//     // Speakers (singular+plural, with/without diacritics)
//     RegExp(
//       r'\b(g[łl]o[sś]nik(?:i|ow|ów)?|glosnik(?:i|ow)?)\b',
//       caseSensitive: false,
//     ): 'Głośnik',

//     RegExp(
//       r'(?<![A-Za-z0-9_])(modu[łl])(?![A-Za-z0-9_])',
//       caseSensitive: false,
//     ): 'Moduł',

//     // A/V
//     RegExp(r'\b(amplituner|av[\s-]*receiver|avr)\b', caseSensitive: false):
//         'Amplituner',
//     RegExp(r'\b(przedwzmacniacz|preamp)\b', caseSensitive: false):
//         'Przedwzmacniacz',
//     RegExp(r'\b(ko[nń]c[oó]wka\s*mocy|power\s*amp)\b', caseSensitive: false):
//         'Końcówka mocy',
//     RegExp(r'\b(dac|konwerter\s*cyfrowo-analogowy)\b', caseSensitive: false):
//         'DAC',
//     RegExp(
//       r'\b(streamer|odtwarzacz\s*sieciowy|player\s*sieciowy)\b',
//       caseSensitive: false,
//     ): 'Streamer',
//     RegExp(r'\b(tuner)\b', caseSensitive: false): 'Tuner',
//     RegExp(r'\b(equalizer|korektor)\b', caseSensitive: false): 'Korektor',
//     RegExp(r'\b(switch|prze[lł]acznik)\b', caseSensitive: false): 'Przełącznik',

//     // Sources
//     RegExp(
//       r'\b(odtwarzacz\s*cd|cd\s*player|cd-?player)\b',
//       caseSensitive: false,
//     ): 'Odtwarzacz CD',
//     RegExp(
//       r'\b(odtwarzacz\s*blu[-\s]?ray|blu[-\s]?ray)\b',
//       caseSensitive: false,
//     ): 'Odtwarzacz Blu-ray',
//     RegExp(r'\b(gramofon|turntable)\b', caseSensitive: false): 'Gramofon',
//     RegExp(
//       r'\b(odtwarzacz\s*multimedialny|media\s*player|tv\s*box)\b',
//       caseSensitive: false,
//     ): 'Odtwarzacz multimedialny',

//     // Speakers & subs
//     RegExp(r'\b(subwoofer|sub)\b', caseSensitive: false): 'Subwoofer',
//     RegExp(r'\b(soundbar)\b', caseSensitive: false): 'Soundbar',
//     RegExp(
//       r'\b(kolumna\s*pod[łl]ogowa|pod[łl]og[oó]wka)\b',
//       caseSensitive: false,
//     ): 'Kolumna podłogowa',
//     RegExp(r'\b(kolumna\s*podstawkowa|monit(or|orki))\b', caseSensitive: false):
//         'Kolumna podstawkowa',
//     RegExp(r'\b(centr(alny|alna)|center)\b', caseSensitive: false):
//         'Głośnik centralny',
//     RegExp(r'\b(satelita|satellite|surround)\b', caseSensitive: false):
//         'Głośnik efektowy',

//     // Headphones & mics
//     RegExp(r'\b(s[łl]uchawki|headphones|headset)\b', caseSensitive: false):
//         'Słuchawki',
//     RegExp(r'\b(mikrofon|microphone|mic)\b', caseSensitive: false): 'Mikrofon',
//     RegExp(
//       r'\b(wzmacniacz\s*s[łl]uchawkowy|headphone\s*amp)\b',
//       caseSensitive: false,
//     ): 'Wzmacniacz słuchawkowy',

//     // Pro-audio
//     RegExp(r'\b(mikser|mixer|konsoleta)\b', caseSensitive: false): 'Mikser',
//     RegExp(r'\b(interfejs\s*audio|audio\s*interface)\b', caseSensitive: false):
//         'Interfejs audio',
//     RegExp(r'\b(rejestrator|recorder)\b', caseSensitive: false): 'Rejestrator',
//     RegExp(
//       r'\b(monitory\s*studyjne|monitor\s*studyjny)\b',
//       caseSensitive: false,
//     ): 'Monitory studyjne',
//     RegExp(r'\b(stat(yw|yw)|stojak)\b', caseSensitive: false): 'Statyw',

//     // Displays & projection
//     RegExp(r'\b(telewizor|tv)\b', caseSensitive: false): 'Telewizor',
//     RegExp(r'\b(projektor|projector)\b', caseSensitive: false): 'Projektor',
//     RegExp(r'\b(ekran\s*projekcyjny|ekran)\b', caseSensitive: false):
//         'Ekran projekcyjny',
//     RegExp(
//       r'\b(uchwyt|uchwyt\s*ścienny|uchwyt\s*tv|uchwyt\s*projektora|wieszak)\b',
//       caseSensitive: false,
//     ): 'Uchwyt',

//     // Cables (granular)
//     RegExp(r'\b(hdmi)\b', caseSensitive: false): 'Kabel HDMI',
//     RegExp(r'\b(optical|toslink|optyczny)\b', caseSensitive: false):
//         'Kabel optyczny',
//     RegExp(
//       r'\b(spdif|coaxial|koncentryczny|coaksjalny)\b',
//       caseSensitive: false,
//     ): 'Kabel coaxial',
//     RegExp(r'\b(rca|cinch)\b', caseSensitive: false): 'Kabel RCA',
//     RegExp(r'\b(xlr)\b', caseSensitive: false): 'Kabel XLR',
//     RegExp(r'\b(jack|trs|trrs)\b', caseSensitive: false): 'Kabel Jack',
//     RegExp(r'\b(g[łl]o[sś]nikowy|speaker\s*cable)\b', caseSensitive: false):
//         'Kabel głośnikowy',
//     RegExp(r'\b(antenowy|antena|sat|coax)\b', caseSensitive: false):
//         'Kabel antenowy',
//     RegExp(r'\b(zasilaj[aą]cy|power\s*cable)\b', caseSensitive: false):
//         'Kabel zasilający',
//     RegExp(
//       r'\b(adapter|przej[sś]ci[oó]wka|adaptery|konwerter)\b',
//       caseSensitive: false,
//     ): 'Adapter',

//     // Power & conditioning
//     RegExp(r'\b(listwa\s*zasilaj[aą]ca|power\s*strip)\b', caseSensitive: false):
//         'Listwa zasilająca',
//     RegExp(r'\b(zasilacz|psu|power\s*supply)\b', caseSensitive: false):
//         'Zasilacz',
//     RegExp(r'\b(ups)\b', caseSensitive: false): 'UPS',

//     // Control & automation
//     RegExp(r'\b(pilot|remote)\b', caseSensitive: false): 'Pilot',
//     RegExp(
//       r'\b(sterowanie|automatyka|control\s*system)\b',
//       caseSensitive: false,
//     ): 'Sterowanie/Automatyka',
//     RegExp(
//       r'\b(access[\s_-]*point|acces[\s_-]*point|accesspoint|accespoint|ap)\b',
//       caseSensitive: false,
//     ): 'Access Point',

//     // Mounting & accessories
//     RegExp(r'\b(akcesoria|accessories)\b', caseSensitive: false): 'Akcesoria',
//     RegExp(
//       r'\b(podk[łl]adki|izolator|izolacja|kolce|standy)\b',
//       caseSensitive: false,
//     ): 'Akcesoria audio',
//     RegExp(r'\b(podstawka|stand|stojak)\b', caseSensitive: false):
//         'Stojak/Stand',
//   };

//   static StockItem normalize(StockItem item) {
//     var name = item.name;
//     var producent = item.producent;
//     var category = item.category;

//     for (final entry in _brandMap.entries) {
//       final regex = entry.key;
//       if (regex.hasMatch(name)) {
//         name = name.replaceAll(regex, ' ').trim();
//         if (producent.trim().isEmpty) producent = entry.value;
//       }
//     }

//     final foundCats = <String>{};
//     for (final entry in _categoryMap.entries) {
//       final regex = entry.key;
//       if (regex.hasMatch(name)) {
//         name = name.replaceAll(regex, ' ').trim();
//         foundCats.add(entry.value);
//       }
//     }
//     if (foundCats.isNotEmpty) {
//       category = foundCats.join(' / '); // overwrite WAPRO
//     } else {
//       category = ''; // optional: blank
//     }

//     name = name
//         .replaceAll(RegExp(r'\s{2,}'), ' ')
//         .replaceAll(RegExp(r'\s+,(\s+)?'), ', ')
//         .replaceAll(RegExp(r',\s*,+'), ',')
//         .trim();

//     return item.copyWith(name: name, producent: producent, category: category);
//   }
// }

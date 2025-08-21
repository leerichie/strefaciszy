// lib/utils/category_filter.dart
class CategoryFilter {
  static final Set<String> _allowList = {
    'Access Point',
    'Adapter',
    'Akcesoria',
    'Akcesoria audio',
    'Amplituner',
    'DAC',
    'Ekran projekcyjny',
    'Głośnik',
    'Głośnik centralny',
    'Głośnik efektowy',
    'Gramofon',
    'Kabel',
    'Kabel antenowy',
    'Kabel coaxial',
    'Kabel HDMI',
    'Kabel Jack',
    'Kabel optyczny',
    'Kabel RCA',
    'Kabel XLR',
    'Kolumna podłogowa',
    'Kolumna podstawkowa',
    'Korektor',
    'Listwa zasilająca',
    'Mikrofon',
    'Mikser',
    'Moduł',
    'Monitory studyjne',
    'Odtwarzacz Blu-ray',
    'Odtwarzacz CD',
    'Odtwarzacz multimedialny',
    'Pilot',
    'Przedwzmacniacz',
    'Projektor',
    'Przełącznik',
    'Rejestrator',
    'Soundbar',
    'Statyw',
    'Sterowanie/Automatyka',
    'Streamer',
    'Subwoofer',
    'Telewizor',
    'Tuner',
    'Uchwyt',
    'UPS',
    'Zasilacz',
  };

  static final List<RegExp> _blackPatterns = [
    RegExp(r'^\d+([x×]\d+)?([x×]\d+)?$', caseSensitive: false),
    RegExp(r'^\d+(\.\d+)?\s*(mm|cm|m|u)$', caseSensitive: false),
    RegExp(r'^\d+\s*(mpx|mp)$', caseSensitive: false),
    RegExp(r'^[A-Z0-9\-_/]{3,}$'),
    RegExp(r'\d'),
  ];

  static bool _looksLikeCodeOrSpec(String s) {
    for (final re in _blackPatterns) {
      if (re.hasMatch(s)) return true;
    }
    return false;
  }

  static bool _isLikelyCategory(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;

    if (_allowList.any((w) => w.toLowerCase() == t.toLowerCase())) return true;

    // Heuristics:
    if (t.length < 3) return false;
    if (_looksLikeCodeOrSpec(t)) return false;

    final letters = RegExp(r'[A-Za-zĄąĆćĘęŁłŃńÓóŚśŹźŻż]');
    if (!letters.hasMatch(t)) return false;

    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 1 && words.every((w) => w.length >= 2)) {
      return true;
    }
    return false;
  }

  static List<String> buildDropdownCategories(Iterable<String?> rawCats) {
    final uniq = <String>{};
    for (final c in rawCats) {
      if (c == null) continue;
      final t = c.trim();
      if (t.isEmpty) continue;
      if (_isLikelyCategory(t)) uniq.add(t);
    }
    final list = uniq.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

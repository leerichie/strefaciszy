// lib/utils/stock_normalizer.dart
import 'package:strefa_ciszy/models/stock_item.dart';

/// Normalizes a StockItem by extracting brand + type words from the name.
/// - If a brand is found in name, it is removed from the name and assigned to
///   `producent` (only if producent was empty).
/// - If type words are found (wzmacniacz, kabel, przewód, głośnik), they are
///   removed from the name and set to `category` (if category was empty).
///
/// NOTE: word-boundary regexes keep us from touching substrings inside other words.
/// Polish diacritics are covered with simple alternations (ł/l, ó/o, ś/s).
class StockNormalizer {
  // BRAND -> canonical name
  static final Map<RegExp, String> _brandMap = {
    RegExp(r'\b(bose)\b', caseSensitive: false): 'Bose',
    RegExp(r'\b(rti)\b', caseSensitive: false): 'RTI',
    RegExp(r'\b(helu\s*sound|helusound)\b', caseSensitive: false): 'Helusound',
  };

  // TYPE WORD -> canonical category
  static final Map<RegExp, String> _categoryMap = {
    RegExp(r'\b(wzmacniacz|amplifier)\b', caseSensitive: false): 'Wzmacniacz',
    RegExp(r'\b(kabel|przew[oó]d|przewod)\b', caseSensitive: false): 'Kabel',
    RegExp(r'\b(g[łl]o[sś]nik|glosnik)\b', caseSensitive: false): 'Głośnik',
  };

  static StockItem normalize(StockItem item) {
    var name = item.name;
    var producent = item.producent;
    var category = item.category;

    // 1) Extract brand
    for (final entry in _brandMap.entries) {
      final regex = entry.key;
      if (regex.hasMatch(name)) {
        // remove brand from name
        name = name.replaceAll(regex, ' ').trim();
        // set producent only if not already present
        if (producent.trim().isEmpty) producent = entry.value;
      }
    }

    // 2) Extract category/type words
    final foundCats = <String>{};
    for (final entry in _categoryMap.entries) {
      final regex = entry.key;
      if (regex.hasMatch(name)) {
        name = name.replaceAll(regex, ' ').trim();
        foundCats.add(entry.value);
      }
    }
    if (foundCats.isNotEmpty && category.trim().isEmpty) {
      category = foundCats.join(' / ');
    }

    // 3) Clean leftover spaces/commas
    name = name
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'\s+,(\s+)?'), ', ')
        .replaceAll(RegExp(r',\s*,+'), ',')
        .trim();

    return item.copyWith(name: name, producent: producent, category: category);
  }
}

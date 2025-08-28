String normalize(String input) {
  final withDia = 'ąćęłńóśźżĄĆĘŁŃÓŚŹŻ';
  final withoutDia = 'acelnoszzACELNOSZZ';
  for (int i = 0; i < withDia.length; i++) {
    input = input.replaceAll(withDia[i], withoutDia[i]);
  }
  return input.toLowerCase();
}

bool matchesSearch(String query, List<String?> fields) {
  final normQuery = normalize(query);
  return fields.any((field) => normalize(field ?? '').contains(normQuery));
}

bool matchesAllTokens(String query, Iterable<String?> fields) {
  final tokens = normalize(
    query,
  ).split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final haystack = normalize(
    fields.where((s) => (s ?? '').trim().isNotEmpty).join(' '),
  );
  for (final t in tokens) {
    if (!haystack.contains(t)) return false;
  }
  return true;
}

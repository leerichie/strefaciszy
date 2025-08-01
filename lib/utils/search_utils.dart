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

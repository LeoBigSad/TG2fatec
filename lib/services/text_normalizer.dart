const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas, sem acentos e com espaços simples.
String normalizeText(String input) {
  final lower = input.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Palavras significativas (sem números e palavras curtas).
Set<String> keywords(String input) => normalizeText(input)
    .split(RegExp(r'[^a-z0-9&]+'))
    .where((w) => w.length > 2 && !RegExp(r'^\d+$').hasMatch(w))
    .toSet();

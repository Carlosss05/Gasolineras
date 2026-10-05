const _accents = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Minúsculas y sin tildes, para búsquedas tolerantes.
String normalize(String s) {
  final buffer = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString();
}

final _wordStart = RegExp(r'(^|[\s/(\-.,])(\p{L})', unicode: true);

/// "CARRETERA SAN VICENTE" -> "Carretera San Vicente".
String prettyName(String s) => s
    .trim()
    .toLowerCase()
    .replaceAllMapped(_wordStart, (m) => '${m[1]}${m[2]!.toUpperCase()}');

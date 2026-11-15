const _accents = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

final _accentUnits = {for (final e in _accents.entries) e.key.codeUnitAt(0): e.value.codeUnitAt(0)};

/// Minúsculas y sin tildes, para búsquedas tolerantes.
///
/// Se llama miles de veces (cada gasolinera y cada pueblo): casi todos los
/// textos no llevan tildes y salen por el camino rápido, sin copiar nada.
String normalize(String s) {
  final lower = s.toLowerCase();
  final length = lower.length;
  var i = 0;
  while (i < length && lower.codeUnitAt(i) < 0x80) {
    i++;
  }
  if (i == length) return lower;

  final units = lower.codeUnits.toList(growable: false);
  for (; i < length; i++) {
    final plain = _accentUnits[units[i]];
    if (plain != null) units[i] = plain;
  }
  return String.fromCharCodes(units);
}

final _wordStart = RegExp(r'(^|[\s/(\-.,])(\p{L})', unicode: true);

/// "CARRETERA SAN VICENTE" -> "Carretera San Vicente".
String prettyName(String s) =>
    s.trim().toLowerCase().replaceAllMapped(_wordStart, (m) => '${m[1]}${m[2]!.toUpperCase()}');

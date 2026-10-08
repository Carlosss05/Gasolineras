class Province {
  const Province({required this.id, required this.name, required this.communityId});

  final String id;
  final String name;
  final String communityId;
}

class Community {
  const Community({required this.id, required this.name});

  final String id;
  final String name;
}

class Municipality {
  const Municipality({
    required this.id,
    required this.name,
    required this.provinceId,
    required this.provinceName,
    required this.communityId,
  });

  final String id;

  /// Puede ser bilingüe, p. ej. "Calpe/Calp".
  final String name;
  final String provinceId;
  final String provinceName;
  final String communityId;
}

enum ScopeKind { myTown, myProvince, province, community, spain }

/// Zona sobre la que se buscan gasolineras.
class SearchScope {
  const SearchScope._(this.kind, this.id, this.name, [this.townId]);

  /// Municipio detectado a partir de la ubicación ([id] es su provincia y
  /// [townId] el código de municipio del Ministerio); cambia al moverse.
  const SearchScope.myTown(String provinceId, String townId, String name)
    : this._(ScopeKind.myTown, provinceId, name, townId);

  /// Provincia detectada a partir de la ubicación; se actualiza al moverse.
  const SearchScope.myProvince(String id, String name) : this._(ScopeKind.myProvince, id, name);
  const SearchScope.province(String id, String name) : this._(ScopeKind.province, id, name);
  const SearchScope.community(String id, String name) : this._(ScopeKind.community, id, name);
  const SearchScope.spain() : this._(ScopeKind.spain, '', 'España');

  final ScopeKind kind;
  final String id;
  final String name;

  /// Solo en [ScopeKind.myTown]: municipio por el que se filtra.
  final String? townId;

  bool get followsLocation => kind == ScopeKind.myTown || kind == ScopeKind.myProvince;

  /// Dos zonas con la misma clave devuelven los mismos datos. Un municipio
  /// reutiliza la descarga de su provincia y se filtra después.
  String get cacheKey => switch (kind) {
    ScopeKind.spain => 'ES',
    ScopeKind.community => 'C$id',
    ScopeKind.myTown || ScopeKind.myProvince || ScopeKind.province => 'P$id',
  };

  Map<String, String> toJson() => {'kind': kind.name, 'id': id, 'name': name, 'townId': ?townId};

  /// Lee una zona guardada en el dispositivo. Devuelve `null` si los datos
  /// están dañados o manipulados (tipo desconocido, códigos no numéricos…).
  static SearchScope? fromJson(Map<String, dynamic> j) {
    try {
      final id = j['id'] as String;
      final name = (j['name'] as String).trim();
      final townId = j['townId'];
      final kind = ScopeKind.values.byName(j['kind'] as String);
      final numeric = RegExp(r'^\d{1,5}$');
      if (name.isEmpty || name.length > 100) return null;
      if (kind != ScopeKind.spain && !numeric.hasMatch(id)) return null;
      return switch (kind) {
        ScopeKind.myTown when townId is String && numeric.hasMatch(townId) => SearchScope.myTown(
          id,
          townId,
          name,
        ),
        // Formato antiguo sin municipio: se queda en la provincia.
        ScopeKind.myTown => SearchScope.myProvince(id, name),
        ScopeKind.myProvince => SearchScope.myProvince(id, name),
        ScopeKind.province => SearchScope.province(id, name),
        ScopeKind.community => SearchScope.community(id, name),
        ScopeKind.spain => const SearchScope.spain(),
      };
    } catch (_) {
      return null;
    }
  }

  String get label => switch (kind) {
    ScopeKind.myTown => 'Mi pueblo · $name',
    ScopeKind.myProvince => 'Mi provincia · $name',
    ScopeKind.spain => 'Toda España',
    _ => name,
  };
}

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

enum ScopeKind { myProvince, province, community, spain }

/// Zona sobre la que se buscan gasolineras.
class SearchScope {
  const SearchScope._(this.kind, this.id, this.name);

  /// Provincia detectada a partir de la ubicación; se actualiza al moverse.
  const SearchScope.myProvince(String id, String name) : this._(ScopeKind.myProvince, id, name);
  const SearchScope.province(String id, String name) : this._(ScopeKind.province, id, name);
  const SearchScope.community(String id, String name) : this._(ScopeKind.community, id, name);
  const SearchScope.spain() : this._(ScopeKind.spain, '', 'España');

  final ScopeKind kind;
  final String id;
  final String name;

  bool get followsLocation => kind == ScopeKind.myProvince;

  /// Dos zonas con la misma clave devuelven los mismos datos.
  String get cacheKey => switch (kind) {
        ScopeKind.spain => 'ES',
        ScopeKind.community => 'C$id',
        ScopeKind.myProvince || ScopeKind.province => 'P$id',
      };

  String get label => switch (kind) {
        ScopeKind.myProvince => 'Mi provincia · $name',
        ScopeKind.spain => 'Toda España',
        _ => name,
      };
}

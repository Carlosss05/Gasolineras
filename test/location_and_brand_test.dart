import 'package:flutter_test/flutter_test.dart';
import 'package:gasolineras/services/location_service.dart';
import 'package:gasolineras/ui/widgets/brand_badge.dart';

void main() {
  group('provincia a partir de la dirección', () {
    test('usa el código postal', () {
      expect(
        provinceFromAddress({'postcode': '03002', 'ISO3166-2-lvl6': 'ES-A', 'country_code': 'es'}),
        '03',
      );
    });

    test('sin código postal usa el código ISO de la provincia', () {
      expect(provinceFromAddress({'ISO3166-2-lvl6': 'ES-V', 'country_code': 'es'}), '46');
    });

    test('comunidades uniprovinciales solo traen el código de comunidad', () {
      expect(provinceFromAddress({'ISO3166-2-lvl4': 'ES-MD', 'country_code': 'es'}), '28');
      expect(provinceFromAddress({'ISO3166-2-lvl4': 'ES-MC', 'country_code': 'es'}), '30');
    });

    test('fuera de España no hay provincia', () {
      expect(provinceFromAddress({'postcode': '75001', 'country_code': 'fr'}), isNull);
    });

    test('rechaza códigos postales no válidos', () {
      expect(provinceFromPostalCode('99001'), isNull);
      expect(provinceFromPostalCode('3002'), isNull);
      expect(provinceFromPostalCode(null), isNull);
    });
  });

  group('insignia de marca', () {
    test('reconoce marcas aunque el rótulo tenga más texto', () {
      expect(brandStyle('Repsol').label, 'R');
      expect(brandStyle('E.S. REPSOL ELDA').label, 'R');
      expect(brandStyle('Bonàrea').label, 'bA');
      expect(brandStyle('BP Oil').label, 'bp');
    });

    test('siglas cortas solo como palabra completa', () {
      // "bp" no debe coincidir dentro de otra palabra.
      expect(brandStyle('Abpetrol').label, 'A');
    });

    test('marcas desconocidas usan su inicial con color estable', () {
      final a = brandStyle('Gasolinera Pepe');
      expect(a.label, 'G');
      expect(brandStyle('Gasolinera Pepe').background, a.background);
    });

    test('sin rótulo se usa el icono genérico', () {
      expect(brandStyle('').label, isNull);
    });
  });
}

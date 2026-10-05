# Gasolineras baratas

App móvil (Android e iOS) hecha con **Flutter** para encontrar las gasolineras más baratas o más cercanas con precios oficiales actualizados.

## Funcionalidades

- **Mi provincia automática**: detecta tu provincia por GPS (por el código postal) y cambia sola si cruzas a otra.
- **Precios al momento**: datos del Ministerio para la Transición Ecológica, que se publican cada ~30 min. La app los recarga cada 10 min y con *pull to refresh*.
- **Distancias en movimiento**: la lista recalcula distancias y reordena cada 100 m que te desplazas.
- **Ordenar** por precio (de más barato a más caro) o por cercanía.
- **Otras zonas**: cualquier provincia, comunidad autónoma o toda España.
- **Combustibles**: Gasolina 95, 95 E10, 98, Diésel, Diésel Premium, GLP y GNC.
- **Buscador** por pueblo, marca o código postal.
- **Favoritas** guardadas en el móvil, con su precio actual aunque estén en otra provincia.
- **Cómo llegar**: abre la ruta en Google Maps.

## Estructura

```
lib/
  data/       FuelPriceRepository (interfaz) + MineturRepository (API pública)
  models/     Station, FuelType, Province/Community/SearchScope
  services/   LocationService (GPS + detección de provincia)
  state/      StationsController, FavoritesController (provider)
  ui/         Pantallas y widgets
```

La interfaz de usuario solo depende de `FuelPriceRepository`. Para escalar, por ejemplo con un backend propio que cachee los precios, guarde histórico o envíe alertas, basta con añadir otra implementación de esa interfaz.

## Ejecutar

```bash
flutter pub get
flutter run          # con un móvil conectado o un emulador abierto
flutter test
```

Fuente de datos: [API REST de precios de carburantes](https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/) (pública y sin clave).

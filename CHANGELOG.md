# Novedades

Cada versión de Android se publica en [Releases](https://github.com/Carlosss05/Gasolineras/releases) y la web en [carlosss05.github.io/Gasolineras](https://carlosss05.github.io/Gasolineras/).

## Próxima versión

**¿Dónde reposto?**
- La tarjeta destacada pasa a ser **Tu mejor opción**: la gasolinera a la que te sale más barato ir contando el precio, la distancia y lo que gasta tu coche en el viaje (antes era solo la más barata).
- Nueva hoja **¿Dónde reposto?** para ajustar los litros que vas a repostar, el consumo y si el viaje es de ida y vuelta o solo de ida. Enseña las cinco que mejor salen con su desglose (combustible + viaje) y las compara con la más cercana y la más barata.
- Funciona sin configurar el coche, con valores típicos.
- El viaje se estima con la distancia en línea recta × 1,3; el orden "Rentables" usa el mismo cálculo y cada gasolinera enseña su coste con el viaje.

**Más rápida**
- Al abrir, la lista aparece al instante con los últimos precios guardados y se actualiza por detrás, en vez de esperar a la red. También funciona sin conexión.
- Volver a una zona ya consultada es inmediato.
- Los datos y la ubicación empiezan a pedirse antes, en paralelo con la carga de la app.
- Buscar pueblos es 7 veces más rápido.

**Interfaz**
- Siluetas de la lista mientras cargan los precios.
- Aviso cuando no hay conexión, con botón para reintentar.
- Tocar el logo de la barra superior vuelve al principio de la lista.
- Pequeña vibración al cambiar de combustible, orden o favorita (Android).

**Seguridad y robustez**
- Tamaño máximo en cada descarga y en cada lista que se procesa.
- Lo guardado en el dispositivo se valida al leerlo; si está dañado se ignora.
- A OpenStreetMap solo se le envía la posición redondeada a unos 100 m.
- Las acciones de GitHub que compilan y firman la app van fijadas a un commit exacto, con avisos automáticos de actualizaciones.
- Si falla el pintado de una parte de la pantalla, solo se sustituye esa parte.

## 1.3.0 — octubre de 2026

**¿Sube o baja?**
- Junto al número de gasolineras, cuánto ha subido o bajado el precio medio de tu zona desde ayer y en 7 días, y cuántas gasolineras han bajado o subido.
- Cada gasolinera muestra bajo su precio su cambio (en verde si baja, en rojo si sube). Toca "Media desde ayer" o "Media en 7 días" para elegir con qué día se compara.
- En la ficha de cada gasolinera, su precio de ayer y el de hace 7 días.
- Usa el histórico oficial del Ministerio, solo de tu zona y del combustible elegido, en segundo plano. No está disponible con "Toda España".

## 1.2.0 — octubre de 2026

**Mi coche**
- Configura combustible, depósito y consumo de tu coche.
- Nuevo orden **Rentables**: cuánto te cuesta llenar el depósito contando el viaje de ida y vuelta.
- **¿Merece la pena ir?** en la tarjeta de la más barata, comparada con la más cercana.
- Diario de repostajes: anota, edita y borra repostajes; elige la gasolinera de una lista y los litros o el importe se calculan solos.
- Resumen del mes: gastado, ahorrado con la app, consumo real y precio medio pagado.
- Calculadora de litros e importe en la ficha de cada gasolinera.

**Diseño**
- Pantalla principal más compacta: la cabecera se recoge al bajar por la lista y deja una barra fina con la zona, el combustible y el orden.
- La zona va dentro del buscador y el orden junto al número de gasolineras.
- El mapa ocupa toda la pantalla, con los combustibles encima.
- Selector de zona rediseñado.
- Verde de la cabecera más oscuro para que el texto se lea mejor.

**iPhone**
- La lista llega al borde de abajo y se ve a través de la barra de Safari, sin franja de color.
- Arreglado el hueco que dejaba el teclado en la app instalada.

**Rendimiento y seguridad**
- Arranque más rápido y lista más fluida con muchas gasolineras.
- Validación de los datos recibidos y guardados, y comprobación automática de dependencias.

**Correcciones**
- Cálculo del consumo, favoritas y guardado del diario.

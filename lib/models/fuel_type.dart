/// Combustibles que la app permite consultar.
///
/// [apiKey] es el nombre del campo en la respuesta de la API del Ministerio y
/// [productId], su código de producto en el histórico de precios
/// (`Listados/ProductosPetroliferos`).
enum FuelType {
  gasolina95('Gasolina 95', 'Precio Gasolina 95 E5', '1'),
  gasolina95E10('Gasolina 95 E10', 'Precio Gasolina 95 E10', '23'),
  gasolina98('Gasolina 98', 'Precio Gasolina 98 E5', '3'),
  diesel('Diésel', 'Precio Gasoleo A', '4'),
  dieselPremium('Diésel Premium', 'Precio Gasoleo Premium', '5'),
  glp('GLP', 'Precio Gases licuados del petróleo', '17'),
  gnc('GNC', 'Precio Gas Natural Comprimido', '18');

  const FuelType(this.label, this.apiKey, this.productId);

  final String label;
  final String apiKey;
  final String productId;
}

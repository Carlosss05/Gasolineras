/// Combustibles que la app permite consultar.
///
/// [apiKey] es el nombre del campo en la respuesta de la API del Ministerio.
enum FuelType {
  gasolina95('Gasolina 95', 'Precio Gasolina 95 E5'),
  gasolina95E10('Gasolina 95 E10', 'Precio Gasolina 95 E10'),
  gasolina98('Gasolina 98', 'Precio Gasolina 98 E5'),
  diesel('Diésel', 'Precio Gasoleo A'),
  dieselPremium('Diésel Premium', 'Precio Gasoleo Premium'),
  glp('GLP', 'Precio Gases licuados del petróleo'),
  gnc('GNC', 'Precio Gas Natural Comprimido');

  const FuelType(this.label, this.apiKey);

  final String label;
  final String apiKey;
}

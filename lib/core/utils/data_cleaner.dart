/// Utilitário para limpar dados antes de enviar para o banco de dados
/// Remove strings vazias e converte para null quando apropriado
class DataCleaner {
  /// Remove strings vazias de um mapa, convertendo-as para null
  /// ou removendo-as completamente se removeEmptyStrings for true
  static Map<String, dynamic> cleanData(
    Map<String, dynamic> data, {
    bool removeEmptyStrings = true,
    List<String>? fieldsToKeepEmpty,
  }) {
    final cleaned = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Se o campo está na lista de exceções, manter mesmo se vazio
      if (fieldsToKeepEmpty != null && fieldsToKeepEmpty.contains(key)) {
        cleaned[key] = value;
        continue;
      }
      
      // Se for string vazia e removeEmptyStrings for true, não incluir
      if (removeEmptyStrings && value is String && value.trim().isEmpty) {
        continue;
      }
      
      // Se for null, não incluir
      if (value == null) {
        continue;
      }
      
      // Incluir o valor
      cleaned[key] = value;
    }
    
    return cleaned;
  }
  
  /// Limpa uma string, retornando null se vazia
  static String? cleanString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}


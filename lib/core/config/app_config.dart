/// Configurações globais do aplicativo
class AppConfig {
  // Construtor privado
  AppConfig._();

  // ==================== CONFIGURAÇÕES DE DOWNLOAD ====================
  
  /// URL de download do APK mais recente
  /// Esta URL deve ser atualizada a cada novo deploy
  static const String APK_DOWNLOAD_URL = 'https://caremind.com.br/download';
  
  /// URL alternativa (se o site tiver um link específico para APK)
  static const String APK_DOWNLOAD_URL_ALT = 'https://play.google.com/store/apps/details?id=com.caremind.app';
  
  /// URL do site oficial do CareMind
  static const String SITE_URL = 'https://caremind.com.br';
  
  // ==================== CONFIGURAÇÕES DA VERSÃO ====================
  
  /// Build number atual do app
  /// DEVE ser incrementado a cada deploy
  static const int CURRENT_BUILD_NUMBER = 1;
  
  /// Nome da versão atual
  static const String CURRENT_VERSION_NAME = '1.1.4';
  
  // ==================== CONFIGURAÇÕES DE VERIFICAÇÃO ====================
  
  /// Intervalo de verificação de versão (em minutos)
  static const int VERSION_CHECK_INTERVAL_MINUTES = 5;
  
  /// Se deve verificar versão automaticamente na inicialização
  static const bool AUTO_CHECK_VERSION = true;
  
  /// Se deve bloquear o app quando desatualizado
  static const bool BLOCK_ON_OUTDATED = true;
  
  // ==================== CONFIGURAÇÕES DE SUPABASE ====================
  
  /// Nome da tabela de versões no Supabase
  static const String SUPABASE_VERSIONS_TABLE = 'app_versions_control';
  
  /// Nome da tabela de log de acesso
  static const String SUPABASE_ACCESS_LOG_TABLE = 'app_version_access_log';
  
  /// Nome da tabela de dispositivos
  static const String SUPABASE_DEVICES_TABLE = 'user_devices';
  
  // ==================== MÉTODOS ÚTEIS ====================
  
  /// Obtém a URL de download correta
  static String getDownloadUrl({bool useAlternative = false}) {
    return useAlternative ? APK_DOWNLOAD_URL_ALT : APK_DOWNLOAD_URL;
  }
  
  /// Verifica se a versão atual está desatualizada
  static bool isOutdated(int latestBuildNumber) {
    return latestBuildNumber > CURRENT_BUILD_NUMBER;
  }
  
  /// Formata a versão atual
  static String getCurrentVersionFormatted() {
    return '$CURRENT_VERSION_NAME+${CURRENT_BUILD_NUMBER}';
  }
}

/// Configurações de ambiente
class EnvironmentConfig {
  static const String development = 'development';
  static const String staging = 'staging';
  static const String production = 'production';
  
  static String current = const bool.fromEnvironment('dart.vm.product') 
      ? production 
      : development;
  
  static bool get isProduction => current == production;
  static bool get isDevelopment => current == development;
  static bool get isStaging => current == staging;
}
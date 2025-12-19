/// Configurações centralizadas da aplicação
///
/// SUBSTITUI: Valores hardcoded espalhados pelo código
///
/// Este arquivo centraliza todas as constantes e configurações da aplicação,
/// facilitando manutenção e evitando magic numbers.
class AppConfig {
  AppConfig._(); // Private constructor para impedir instanciação

  // ==================== SUPORTE ====================

  /// Número do WhatsApp do suporte CareMind (formato internacional)
  static const String supportWhatsAppNumber = '5511953362516';

  /// Email do suporte
  static const String supportEmail = 'suporte@caremind.com.br';

  /// Website
  static const String website = 'https://caremind.com.br';

  // ==================== RATE LIMITING ====================

  /// Número máximo de tentativas para exibição na UI
  ///
  /// IMPORTANTE: O rate limiting real é no backend (Upstash Redis)
  /// Este valor é apenas para feedback visual ao usuário
  static const int maxTentativasDisplay = 3;

  /// Tempo de bloqueio padrão após exceder tentativas (minutos)
  ///
  /// IMPORTANTE: O bloqueio real é controlado pelo backend
  /// Este valor é apenas para exibição na UI
  static const int rateLimitBlockMinutes = 15;

  // ==================== TIMEOUTS ====================

  /// Timeout padrão para requisições HTTP
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Timeout para operações longas (upload, exportação, etc)
  static const Duration longTimeout = Duration(minutes: 2);

  /// Timeout para operações rápidas (validação, ping, etc)
  static const Duration shortTimeout = Duration(seconds: 10);

  // ==================== VALIDAÇÕES ====================

  /// Tamanho mínimo de senha
  static const int minPasswordLength = 6;

  /// Tamanho máximo de senha
  static const int maxPasswordLength = 128;

  /// Tamanho mínimo de nome
  static const int minNameLength = 2;

  /// Tamanho máximo de nome
  static const int maxNameLength = 100;

  /// Regex para validação de email
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Regex para validação de telefone brasileiro
  static final RegExp phoneRegex = RegExp(
    r'^\([0-9]{2}\) [0-9]{4,5}-[0-9]{4}$',
  );

  // ==================== PAGINAÇÃO ====================

  /// Número de itens por página (padrão)
  static const int defaultPageSize = 20;

  /// Número máximo de itens por página
  static const int maxPageSize = 100;

  // ==================== CACHE ====================

  /// Duração do cache de perfil do usuário
  static const Duration profileCacheDuration = Duration(minutes: 30);

  /// Duração do cache de organizações
  static const Duration organizationCacheDuration = Duration(hours: 1);

  /// Duração do cache de medicamentos
  static const Duration medicationCacheDuration = Duration(minutes: 15);

  // ==================== NOTIFICAÇÕES ====================

  /// Antecedência padrão para lembrete de medicamento (minutos)
  static const int defaultMedicationReminderMinutes = 30;

  /// Antecedência padrão para lembrete de compromisso (minutos)
  static const int defaultAppointmentReminderMinutes = 60;

  // ==================== LIMITES ====================

  /// Tamanho máximo de arquivo para upload (MB)
  static const int maxFileUploadSizeMB = 10;

  /// Tamanho máximo de imagem para upload (MB)
  static const int maxImageUploadSizeMB = 5;

  /// Número máximo de medicamentos por idoso
  static const int maxMedicationsPerPatient = 50;

  /// Número máximo de vínculos familiares por idoso
  static const int maxFamilyLinksPerPatient = 10;

  /// Número máximo de membros por organização (plano gratuito)
  static const int maxMembersPerOrgFree = 5;

  /// Número máximo de idosos por organização (plano gratuito)
  static const int maxPatientsPerOrgFree = 20;

  // ==================== DATAS ====================

  /// Idade mínima para cadastro (anos)
  static const int minAge = 0;

  /// Idade máxima para cadastro (anos)
  static const int maxAge = 150;

  /// Formato de data padrão para exibição
  static const String defaultDateFormat = 'dd/MM/yyyy';

  /// Formato de data e hora padrão para exibição
  static const String defaultDateTimeFormat = 'dd/MM/yyyy HH:mm';

  /// Formato de hora padrão para exibição
  static const String defaultTimeFormat = 'HH:mm';

  // ==================== ANIMAÇÕES ====================

  /// Duração padrão de animações
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  /// Duração de animações rápidas
  static const Duration fastAnimationDuration = Duration(milliseconds: 150);

  /// Duração de animações lentas
  static const Duration slowAnimationDuration = Duration(milliseconds: 500);

  // ==================== ACESSIBILIDADE ====================

  /// Tamanho mínimo de fonte
  static const double minFontSize = 12.0;

  /// Tamanho máximo de fonte
  static const double maxFontSize = 32.0;

  /// Tamanho padrão de fonte
  static const double defaultFontSize = 16.0;

  /// Tamanho mínimo de botões (altura)
  static const double minButtonHeight = 44.0;

  /// Tamanho mínimo de área tocável
  static const double minTouchTargetSize = 48.0;

  // ==================== DEEP LINKS ====================

  /// Prefixo de deep links
  static const String deepLinkPrefix = 'caremind://';

  /// URL base para universal links
  static const String universalLinkBase = 'https://caremind.com.br';

  // ==================== DESENVOLVIMENTO ====================

  /// Habilitar logs de debug
  static const bool enableDebugLogs = true;

  /// Habilitar performance overlay
  static const bool enablePerformanceOverlay = false;

  /// Simular latência de rede (ms) - apenas em desenvolvimento
  static const int simulateNetworkLatencyMs = 0;
}

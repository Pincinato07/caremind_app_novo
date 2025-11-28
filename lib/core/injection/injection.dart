import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/rotina_service.dart';
import '../../services/compromisso_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../services/relatorios_service.dart';
import '../../services/account_manager_service.dart';
import '../../services/lgpd_service.dart';
import '../../services/notification_service.dart';
import '../../services/ocr_service.dart';
import '../../services/fcm_token_service.dart';
import '../../services/settings_service.dart';
import '../../services/notificacoes_app_service.dart';
import '../../services/alexa_auth_service.dart';
import '../../services/profile_service.dart';
import '../../services/medication_crud_service.dart';
import '../../services/appointment_crud_service.dart';
import '../services/auth_service.dart';
import '../../core/state/familiar_state.dart';

final getIt = GetIt.instance;

/// Configura a injeção de dependências da aplicação
Future<void> configureDependencies() async {
  // Inicializar notificações
  await NotificationService.initialize();

  // Registra o SupabaseClient como singleton
  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  // Registra os services como singletons
  getIt.registerLazySingleton<SupabaseService>(
    () => SupabaseService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<MedicamentoService>(
    () => MedicamentoService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<RotinaService>(
    () => RotinaService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<CompromissoService>(
    () => CompromissoService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<HistoricoEventosService>(
    () => HistoricoEventosService(),
  );

  getIt.registerLazySingleton<RelatoriosService>(
    () => RelatoriosService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<AccountManagerService>(
    () => AccountManagerService(),
  );

  getIt.registerLazySingleton<AuthService>(
    () => AuthService(getIt<SupabaseService>(), getIt<AccountManagerService>()),
  );

  getIt.registerLazySingleton<OcrService>(
    () => OcrService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<FCMTokenService>(
    () => FCMTokenService(getIt<SupabaseClient>()),
  );

  // Registra NotificacoesAppService para notificações do app
  getIt.registerLazySingleton<NotificacoesAppService>(
    () => NotificacoesAppService(getIt<SupabaseClient>()),
  );

  // Registra LgpdService como factory (pode precisar ser recriado)
  getIt.registerFactory<LgpdService>(
    () => LgpdService(
      getIt<SupabaseService>(),
      getIt<MedicamentoService>(),
      getIt<CompromissoService>(),
    ),
  );

  // Registra FamiliarState como singleton (estado global para perfil familiar)
  getIt.registerLazySingleton<FamiliarState>(
    () => FamiliarState(),
  );

  // Registra SettingsService como singleton e inicializa
  final settingsService = SettingsService();
  await settingsService.initialize();
  getIt.registerLazySingleton<SettingsService>(
    () => settingsService,
  );

  // Registra AlexaAuthService para vinculação com Alexa
  getIt.registerLazySingleton<AlexaAuthService>(
    () => AlexaAuthService(getIt<SupabaseService>()),
  );

  // Registra ProfileService para gerenciamento de perfil
  getIt.registerLazySingleton<ProfileService>(
    () => ProfileService(getIt<SupabaseService>()),
  );

  // Registra MedicationCRUDService para gerenciamento completo de medicamentos
  getIt.registerLazySingleton<MedicationCRUDService>(
    () => MedicationCRUDService(getIt<SupabaseService>()),
  );

  // Registra AppointmentCRUDService para gerenciamento completo de compromissos
  getIt.registerLazySingleton<AppointmentCRUDService>(
    () => AppointmentCRUDService(getIt<SupabaseService>()),
  );
}


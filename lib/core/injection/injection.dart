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
import '../../services/vinculo_familiar_service.dart';
import '../../services/daily_cache_service.dart';
import '../../services/subscription_service.dart';
import '../../services/convite_idoso_service.dart';
import '../../services/organizacao_service.dart';
import '../../services/membro_organizacao_service.dart';
import '../../services/idoso_organizacao_service.dart';
import '../../services/exportacao_service.dart';
import '../services/auth_service.dart';
import '../../core/state/familiar_state.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  await NotificationService.initialize();

  getIt.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );

  getIt.registerLazySingleton<SupabaseService>(
    () => SupabaseService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<SubscriptionService>(
    () => SubscriptionService(getIt<SupabaseClient>()),
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

  getIt.registerLazySingleton<NotificacoesAppService>(
    () => NotificacoesAppService(getIt<SupabaseClient>()),
  );

  getIt.registerFactory<LgpdService>(
    () => LgpdService(
      getIt<SupabaseService>(),
      getIt<MedicamentoService>(),
      getIt<CompromissoService>(),
    ),
  );

  getIt.registerLazySingleton<FamiliarState>(
    () => FamiliarState(),
  );

  final settingsService = SettingsService();
  await settingsService.initialize();
  getIt.registerLazySingleton<SettingsService>(
    () => settingsService,
  );

  getIt.registerLazySingleton<AlexaAuthService>(
    () => AlexaAuthService(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<ProfileService>(
    () => ProfileService(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<MedicationCRUDService>(
    () => MedicationCRUDService(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<AppointmentCRUDService>(
    () => AppointmentCRUDService(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<VinculoFamiliarService>(
    () => VinculoFamiliarService(getIt<SupabaseClient>()),
  );

  final dailyCacheService = DailyCacheService();
  await dailyCacheService.initialize();
  getIt.registerLazySingleton<DailyCacheService>(
    () => dailyCacheService,
  );

  getIt.registerLazySingleton<ConviteIdosoService>(
    () => ConviteIdosoService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<OrganizacaoService>(
    () => OrganizacaoService(getIt<SupabaseService>()),
  );

  getIt.registerLazySingleton<MembroOrganizacaoService>(
    () => MembroOrganizacaoService(),
  );

  getIt.registerLazySingleton<IdosoOrganizacaoService>(
    () => IdosoOrganizacaoService(),
  );

  getIt.registerLazySingleton<ExportacaoService>(
    () => ExportacaoService(getIt<SupabaseService>()),
  );
}
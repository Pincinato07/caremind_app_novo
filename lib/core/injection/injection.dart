import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/rotina_service.dart';
import '../../services/compromisso_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../services/lgpd_service.dart';
import '../../services/notification_service.dart';
import '../../services/ocr_service.dart';

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
    () => HistoricoEventosService(getIt<SupabaseClient>()),
  );

  getIt.registerLazySingleton<OcrService>(
    () => OcrService(getIt<SupabaseClient>()),
  );

  // Registra LgpdService como factory (pode precisar ser recriado)
  getIt.registerFactory<LgpdService>(
    () => LgpdService(
      getIt<SupabaseService>(),
      getIt<MedicamentoService>(),
      getIt<CompromissoService>(),
    ),
  );
}


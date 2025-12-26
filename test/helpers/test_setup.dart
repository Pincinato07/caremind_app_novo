import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/core/injection/injection.dart';
import '../../lib/services/supabase_service.dart';
import '../../lib/services/settings_service.dart';
import '../../lib/services/organizacao_service.dart';
import 'test_helpers.mocks.dart';

bool _isSetupComplete = false;

/// Setup completo para testes
/// 
/// Inicializa Supabase com valores mockados e configura GetIt
/// Pode ser chamado múltiplas vezes de forma segura
Future<void> setupTests() async {
  // Evitar setup duplicado (mas permitir se necessário)
  if (_isSetupComplete) {
    // Verificar se Supabase ainda está acessível
    try {
      final _ = Supabase.instance.client;
      return; // Tudo OK, não precisa reinicializar
    } catch (e) {
      // Se não estiver acessível, resetar flag e continuar
      _isSetupComplete = false;
    }
  }

  // Inicializar binding do Flutter
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mockar SharedPreferences ANTES de qualquer uso
  // Isso é crítico para evitar MissingPluginException
  SharedPreferences.setMockInitialValues({});

  // Inicializar Supabase com valores de teste
  // Usar valores mockados que não precisam de conexão real
  bool supabaseInitialized = false;
  
  // Tentar verificar se já está inicializado
  try {
    final _ = Supabase.instance.client;
    supabaseInitialized = true;
  } catch (e) {
    // Não está inicializado, vamos inicializar
    supabaseInitialized = false;
  }

  // Se não estiver inicializado, inicializar
  if (!supabaseInitialized) {
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key-for-testing-only',
      );
      supabaseInitialized = true;
    } catch (e) {
      // Se falhar, tentar novamente
      try {
        await Supabase.initialize(
          url: 'https://test.supabase.co',
          anonKey: 'test-anon-key-for-testing-only',
        );
        supabaseInitialized = true;
      } catch (e2) {
        // Se ainda falhar, continuar mesmo assim
        // Alguns testes podem não precisar de Supabase real
      }
    }
  }

  // Verificar novamente se está acessível
  try {
    final _ = Supabase.instance.client;
  } catch (e) {
    // Se ainda não estiver acessível, tentar uma última vez
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key-for-testing-only',
      );
    } catch (e2) {
      // Ignorar - alguns testes podem funcionar sem Supabase
    }
  }

  // Configurar GetIt com dependências mínimas para testes
  try {
    // Limpar registros anteriores se necessário
    if (GetIt.instance.isRegistered<SupabaseClient>()) {
      try {
        GetIt.instance.unregister<SupabaseClient>();
      } catch (e) {
        // Ignorar se não conseguir desregistrar
      }
    }

    // Registrar SupabaseClient
    GetIt.instance.registerLazySingleton<SupabaseClient>(
      () => Supabase.instance.client,
    );

    // Registrar SupabaseService
    if (GetIt.instance.isRegistered<SupabaseService>()) {
      try {
        GetIt.instance.unregister<SupabaseService>();
      } catch (e) {
        // Ignorar
      }
    }

    GetIt.instance.registerLazySingleton<SupabaseService>(
      () => SupabaseService(GetIt.instance<SupabaseClient>()),
    );

    // Registrar OrganizacaoService como mock
    if (GetIt.instance.isRegistered<OrganizacaoService>()) {
      try {
        GetIt.instance.unregister<OrganizacaoService>();
      } catch (e) {
        // Ignorar
      }
    }

    // Registrar OrganizacaoService
    // Usar o SupabaseService já registrado no GetIt
    try {
      GetIt.instance.registerLazySingleton<OrganizacaoService>(
        () => OrganizacaoService(GetIt.instance<SupabaseService>()),
      );
    } catch (e) {
      // Se falhar, tentar usar o mock diretamente com cast
      try {
        GetIt.instance.registerLazySingleton<OrganizacaoService>(
          () => MockOrganizacaoService() as dynamic,
        );
      } catch (e2) {
        debugPrint('Erro ao registrar OrganizacaoService: $e2');
      }
    }

    // SettingsService será inicializado individualmente em cada teste
    // Não inicializar aqui para evitar problemas com SharedPreferences
  } catch (e) {
    // Se já estiver registrado, continuar
    // Isso pode acontecer se os testes rodarem em sequência
  }

  _isSetupComplete = true;
}

/// Garantir que Supabase está inicializado (helper para testes)
Future<void> ensureSupabaseInitialized() async {
  try {
    final _ = Supabase.instance.client;
    // Se chegou aqui, está OK
  } catch (e) {
    // Se não estiver, inicializar
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key-for-testing-only',
    );
  }
}

/// Resetar setup (útil para testes isolados)
void resetSetup() {
  _isSetupComplete = false;
}

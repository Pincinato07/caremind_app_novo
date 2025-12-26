import 'dart:async';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'test_helpers.mocks.dart';

/// Helper para criar e configurar mocks do SupabaseClient
class SupabaseMockHelper {
  /// Cria um mock client com configurações básicas
  static MockSupabaseClient createMockClient() {
    final mockClient = MockSupabaseClient();
    final mockFunctions = MockFunctionsClient();
    
    // Configurar o getter functions para retornar um mock real
    reset(mockClient);
    when(mockClient.functions).thenReturn(mockFunctions);
    
    // Os getters auth e storage retornam automaticamente via SmartFake
    // Não precisamos configurá-los manualmente

    return mockClient;
  }

  /// Configura mock para função invoke que retorna sucesso
  /// Por padrão, inclui dados que indicam que pelo menos um canal funcionou
  /// para evitar que o código tente fazer fallback SMS
  static void setupSuccessfulFunctionInvoke(
    MockSupabaseClient mockClient,
    String functionName,
    Map<String, dynamic> responseData,
  ) {
    // Garantir que a resposta inclui dados que indicam sucesso completo
    // Isso evita que o código tente fazer fallback SMS
    final completeResponse = {
      'success': true,
      'resultados_twilio': [
        {'sms': 'enviado', 'telefone': '+5511999999999'}
      ],
      'resultados_push': [
        {'push': 'enviado', 'device_id': 'test-device'}
      ],
      'warning': false,
      ...responseData, // Sobrescrever com dados fornecidos se houver
    };
    
    // Mockar o invoke no MockFunctionsClient
    final functionsClient = mockClient.functions as MockFunctionsClient;
    when(functionsClient.invoke(
      functionName,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      files: anyNamed('files'),
      queryParameters: anyNamed('queryParameters'),
      method: anyNamed('method'),
      region: anyNamed('region'),
    )).thenAnswer((_) async => FunctionResponse(
      status: 200,
      data: completeResponse,
    ));
  }

  /// Configura mock para função invoke que retorna erro
  static void setupFailedFunctionInvoke(
    MockSupabaseClient mockClient,
    String functionName,
    int statusCode,
    Map<String, dynamic> errorData,
  ) {
    final functionsClient = mockClient.functions as MockFunctionsClient;
    when(functionsClient.invoke(
      functionName,
      headers: anyNamed('headers'),
      body: anyNamed('body'),
      files: anyNamed('files'),
      queryParameters: anyNamed('queryParameters'),
      method: anyNamed('method'),
      region: anyNamed('region'),
    )).thenAnswer((_) async => FunctionResponse(
      status: statusCode,
      data: errorData,
    ));
  }

  /// Configura mock para queries do Supabase que retornam uma lista vazia
  /// Por enquanto, não mockamos as queries encadeadas porque é complexo
  /// Os testes devem lidar com listas vazias ou null retornados pelos SmartFakes
  static void setupQueryReturnsList(
    MockSupabaseClient mockClient,
    String table,
    List<Map<String, dynamic>> data,
  ) {
    // Por enquanto, não fazemos nada
    // Os SmartFakes do Mockito retornarão valores padrão
    // Se necessário, podemos implementar mock mais complexo no futuro
  }

  /// Configura mock para queries do Supabase que retornam null (maybeSingle)
  /// Por enquanto, não mockamos as queries encadeadas
  static void setupQueryReturnsMaybeSingle(
    MockSupabaseClient mockClient,
    String table,
    Map<String, dynamic>? data,
  ) {
    // Por enquanto, não fazemos nada
    // Os SmartFakes do Mockito retornarão null por padrão para maybeSingle
  }

  /// Configura mock para queries do Supabase que retornam um único item (single)
  static void setupQueryReturnsSingle(
    MockSupabaseClient mockClient,
    String table,
    Map<String, dynamic> data,
  ) {
    // Por enquanto, não fazemos nada
  }
}

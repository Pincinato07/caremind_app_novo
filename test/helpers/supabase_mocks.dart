// Este arquivo gera mocks para Supabase usando mockito
// Os mocks já estão gerados em test_helpers.mocks.dart
// Este arquivo existe apenas para documentação

/// Helper para criar um MockSupabaseClient configurado com queries mockadas
class MockSupabaseClientHelper {
  /// Cria um mock client com configurações básicas
  static MockSupabaseClient createMockClient() {
    final mockClient = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    final mockFunctions = MockSupabaseFunctionsClient();
    final mockStorage = MockSupabaseStorageClient();

    // Configurar retornos básicos
    when(mockClient.auth).thenReturn(mockAuth);
    when(mockClient.functions).thenReturn(mockFunctions);
    when(mockClient.storage).thenReturn(mockStorage);

    return mockClient;
  }

  /// Configura mock para função invoke que retorna sucesso
  static void setupSuccessfulFunctionInvoke(
    MockSupabaseClient mockClient,
    String functionName,
    Map<String, dynamic> responseData,
  ) {
    when(mockClient.functions.invoke(
      functionName,
      body: anyNamed('body'),
    )).thenAnswer((_) async => FunctionResponse(
      status: 200,
      data: responseData,
    ));
  }

  /// Configura mock para função invoke que retorna erro
  static void setupFailedFunctionInvoke(
    MockSupabaseClient mockClient,
    String functionName,
    int statusCode,
    Map<String, dynamic> errorData,
  ) {
    when(mockClient.functions.invoke(
      functionName,
      body: anyNamed('body'),
    )).thenAnswer((_) async => FunctionResponse(
      status: statusCode,
      data: errorData,
    ));
  }
}


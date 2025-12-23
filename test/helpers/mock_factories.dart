import 'package:supabase_flutter/supabase_flutter.dart';

/// Factory para criar dados de teste mockados
class MockFactories {
  /// Cria um mock de resposta de Edge Function com sucesso
  static FunctionResponse createSuccessFunctionResponse({
    Map<String, dynamic>? data,
    int status = 200,
  }) {
    return FunctionResponse(
      status: status,
      data: data ?? {
        'success': true,
        'resultados_twilio': [
          {'sms': 'enviado', 'telefone': '+5511999999999'}
        ],
        'resultados_push': [
          {'push': 'enviado', 'familiar_id': 'familiar-123'}
        ],
      },
    );
  }

  /// Cria um mock de resposta de Edge Function com falha
  static FunctionResponse createFailureFunctionResponse({
    String? error,
    int status = 500,
  }) {
    return FunctionResponse(
      status: status,
      data: {
        'success': false,
        'error': error ?? 'Erro ao acionar emergência',
      },
    );
  }

  /// Cria um mock de perfil de usuário
  static Map<String, dynamic> createMockPerfil({
    String? id,
    String? userId,
    String? nome,
    String? tipo,
  }) {
    return {
      'id': id ?? 'perfil-123',
      'user_id': userId ?? 'user-123',
      'nome': nome ?? 'Usuário Teste',
      'tipo': tipo ?? 'idoso',
      'telefone': '+5511999999999',
      'notificacoes_compromissos': true,
    };
  }

  /// Cria um mock de medicamento
  static Map<String, dynamic> createMockMedicamento({
    int? id,
    String? perfilId,
    String? nome,
  }) {
    return {
      'id': id ?? 1,
      'perfil_id': perfilId ?? 'perfil-123',
      'nome': nome ?? 'Medicamento Teste',
      'dosagem': '1 comprimido',
      'frequencia': {
        'tipo': 'diario',
        'horarios': ['08:00', '20:00'],
      },
      'quantidade': 30,
      'via': 'oral',
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Cria um mock de vínculo familiar
  static Map<String, dynamic> createMockVinculo({
    String? idIdoso,
    String? idFamiliar,
  }) {
    return {
      'id_idoso': idIdoso ?? 'idoso-123',
      'id_familiar': idFamiliar ?? 'familiar-123',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}


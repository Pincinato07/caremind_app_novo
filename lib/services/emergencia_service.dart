import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/app_exception.dart';

/// Tipos de emergência suportados
enum TipoEmergencia {
  panico,
  queda,
  medicamento,
  outro,
}

/// Serviço para acionar alertas de emergência
/// Dispara SMS, ligações e notificações push para todos os familiares
class EmergenciaService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Aciona alerta de emergência
  /// 
  /// [tipoEmergencia] - Tipo da emergência (panico, queda, medicamento, outro)
  /// [mensagem] - Mensagem opcional personalizada
  /// [localizacao] - Coordenadas GPS opcionais
  /// 
  /// Retorna informações sobre o resultado do disparo
  Future<Map<String, dynamic>> acionarEmergencia({
    required String idosoId,
    TipoEmergencia tipoEmergencia = TipoEmergencia.panico,
    String? mensagem,
    Map<String, double>? localizacao,
  }) async {
    try {
      // Chamar Edge Function de emergência
      final response = await _supabase.functions.invoke(
        'disparar-emergencia',
        body: {
          'idoso_id': idosoId,
          'tipo_emergencia': tipoEmergencia.name,
          'mensagem': mensagem,
          'localizacao': localizacao,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw UnknownException(
          message: errorData?['error'] as String? ?? 'Erro ao acionar emergência',
        );
      }

      final data = response.data as Map<String, dynamic>?;
      
      if (data?['success'] == false) {
        throw UnknownException(
          message: data?['error'] as String? ?? 'Falha ao acionar emergência',
        );
      }

      return data ?? {};
    } catch (e) {
      if (e is AppException) {
        rethrow;
      }
      throw UnknownException(message: 'Erro ao acionar emergência: ${e.toString()}');
    }
  }

  /// Aciona emergência de pânico (atalho rápido)
  Future<Map<String, dynamic>> acionarPanico({
    required String idosoId,
    Map<String, double>? localizacao,
  }) async {
    return acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.panico,
      mensagem: 'Botão de pânico acionado - precisa de ajuda imediata!',
      localizacao: localizacao,
    );
  }

  /// Aciona emergência por queda detectada
  Future<Map<String, dynamic>> acionarQueda({
    required String idosoId,
    Map<String, double>? localizacao,
  }) async {
    return acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.queda,
      mensagem: 'Queda detectada - verificação imediata necessária!',
      localizacao: localizacao,
    );
  }
}


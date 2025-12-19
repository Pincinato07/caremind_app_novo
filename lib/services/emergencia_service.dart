import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../core/errors/app_exception.dart';
import 'location_service.dart';

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
  final LocationService _locationService = LocationService();

  /// Aciona alerta de emergência
  /// 
  /// [tipoEmergencia] - Tipo da emergência (panico, queda, medicamento, outro)
  /// [mensagem] - Mensagem opcional personalizada
  /// [localizacao] - Coordenadas GPS opcionais
  /// 
  /// Retorna informações sobre o resultado do disparo
  /// Lança AppException em caso de erro
  Future<Map<String, dynamic>> acionarEmergencia({
    required String idosoId,
    TipoEmergencia tipoEmergencia = TipoEmergencia.panico,
    String? mensagem,
    Map<String, double>? localizacao,
  }) async {
    // Validar entrada
    if (idosoId.isEmpty) {
      throw UnknownException(message: 'ID do idoso não pode ser vazio');
    }

    try {
      // Chamar Edge Function de emergência com timeout
      final response = await _supabase.functions.invoke(
        'disparar-emergencia',
        body: {
          'idoso_id': idosoId,
          'tipo_emergencia': tipoEmergencia.name,
          'mensagem': mensagem,
          'localizacao': localizacao,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw UnknownException(
            message: 'Tempo esgotado ao acionar emergência. Verifique sua conexão com a internet.',
          );
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ?? 
                            errorData?['message'] as String? ??
                            'Erro ao acionar emergência';
        
        throw UnknownException(message: errorMessage);
      }

      final data = response.data as Map<String, dynamic>?;
      
      if (data == null) {
        throw UnknownException(message: 'Resposta inválida do servidor');
      }
      
      if (data['success'] == false) {
        final errorMessage = data['error'] as String? ?? 
                            data['message'] as String? ??
                            'Falha ao acionar emergência';
        throw UnknownException(message: errorMessage);
      }

      return data;
    } on TimeoutException catch (e) {
      throw UnknownException(message: e.message);
    } on AppException {
      rethrow;
    } catch (e) {
      // Verificar se é erro de conexão
      if (e.toString().contains('SocketException') || 
          e.toString().contains('NetworkException') ||
          e.toString().contains('Failed host lookup')) {
        throw UnknownException(
          message: 'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
        );
      }
      
      throw UnknownException(
        message: 'Erro ao acionar emergência: ${e.toString()}',
      );
    }
  }

  /// Aciona emergência de pânico (atalho rápido)
  /// Captura GPS automaticamente se não for fornecido
  /// Continua mesmo se GPS falhar (alerta enviado sem localização)
  Future<Map<String, dynamic>> acionarPanico({
    required String idosoId,
    Map<String, double>? localizacao,
    bool capturarGPS = true,
  }) async {
    // Se localização não foi fornecida e capturarGPS é true, tentar capturar
    Map<String, double>? localizacaoFinal = localizacao;
    if (localizacaoFinal == null && capturarGPS) {
      try {
        localizacaoFinal = await _locationService.getCurrentLocation()
            .timeout(const Duration(seconds: 8));
      } on LocationException {
        // Log do erro mas continuar sem localização
        // O alerta será enviado mesmo sem GPS
        localizacaoFinal = null;
      } on TimeoutException {
        // Timeout - continuar sem localização
        localizacaoFinal = null;
      } catch (_) {
        // Qualquer outro erro - continuar sem localização
        localizacaoFinal = null;
      }
    }

    // Sempre tentar enviar o alerta, mesmo sem localização
    return acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.panico,
      mensagem: 'Botão de pânico acionado - precisa de ajuda imediata!',
      localizacao: localizacaoFinal,
    );
  }

  /// Aciona emergência por queda detectada
  /// Captura GPS automaticamente se não for fornecido
  /// Continua mesmo se GPS falhar (alerta enviado sem localização)
  Future<Map<String, dynamic>> acionarQueda({
    required String idosoId,
    Map<String, double>? localizacao,
    bool capturarGPS = true,
  }) async {
    // Se localização não foi fornecida e capturarGPS é true, tentar capturar
    Map<String, double>? localizacaoFinal = localizacao;
    if (localizacaoFinal == null && capturarGPS) {
      try {
        localizacaoFinal = await _locationService.getCurrentLocation()
            .timeout(const Duration(seconds: 8));
      } on LocationException {
        // Log do erro mas continuar sem localização
        localizacaoFinal = null;
      } on TimeoutException {
        // Timeout - continuar sem localização
        localizacaoFinal = null;
      } catch (_) {
        // Qualquer outro erro - continuar sem localização
        localizacaoFinal = null;
      }
    }

    // Sempre tentar enviar o alerta, mesmo sem localização
    return acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.queda,
      mensagem: 'Queda detectada - verificação imediata necessária!',
      localizacao: localizacaoFinal,
    );
  }
}


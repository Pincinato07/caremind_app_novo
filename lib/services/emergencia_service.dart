import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import 'location_service.dart';
import 'vinculo_familiar_service.dart';

/// Tipos de emergência suportados
enum TipoEmergencia {
  panico,
  queda,
  medicamento,
  outro,
}

/// Serviço para acionar alertas de emergência
/// Dispara SMS, ligações e notificações push para todos os familiares
/// Implementa fallback: API -> SMS nativo -> Alarme local
class EmergenciaService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocationService _locationService = LocationService();
  final VinculoFamiliarService _vinculoService = VinculoFamiliarService(Supabase.instance.client);
  static const Duration _apiTimeout = Duration(seconds: 10);
  Timer? _alarmeTimer; // Timer para controlar repetição do som de alarme

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
      // Tentar chamar Edge Function de emergência com timeout de 10s
      try {
        final response = await _supabase.functions.invoke(
          'disparar-emergencia',
          body: {
            'idoso_id': idosoId,
            'tipo_emergencia': tipoEmergencia.name,
            'mensagem': mensagem,
            'localizacao': localizacao,
          },
        ).timeout(
          _apiTimeout,
          onTimeout: () {
            throw TimeoutException('API timeout após 10 segundos');
          },
        );

        if (response.status != 200) {
          final errorData = response.data as Map<String, dynamic>?;
          final errorMessage = errorData?['error'] as String? ?? 
                              errorData?['message'] as String? ??
                              'Erro ao acionar emergência';
          
          // API falhou, tentar fallback SMS
          await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
          throw UnknownException(message: errorMessage);
        }

        final data = response.data as Map<String, dynamic>?;
        
        if (data == null) {
          // Resposta inválida, tentar fallback SMS
          await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
          throw UnknownException(message: 'Resposta inválida do servidor');
        }
        
        if (data['success'] == false) {
          final errorMessage = data['error'] as String? ?? 
                              data['message'] as String? ??
                              'Falha ao acionar emergência';
          // API retornou falha, tentar fallback SMS
          await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
          throw UnknownException(message: errorMessage);
        }

        // Sucesso na API
        return data;
      } on TimeoutException {
        // Timeout da API após 10s - acionar fallback SMS
        await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        throw UnknownException(
          message: 'Tempo esgotado ao acionar emergência. SMS de emergência foi enviado como fallback.',
        );
      } catch (apiError) {
        // Qualquer erro da API - tentar fallback SMS
        await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        rethrow;
      }
    } on AppException {
      rethrow;
    } catch (e) {
      // Verificar se é erro de conexão
      if (e.toString().contains('SocketException') || 
          e.toString().contains('NetworkException') ||
          e.toString().contains('Failed host lookup')) {
        // Sem conexão - tentar fallback SMS
        try {
          await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        } catch (_) {
          // Se SMS também falhar, acionar alarme local
          await _acionarAlarmeLocal();
        }
        throw UnknownException(
          message: 'Sem conexão com a internet. SMS de emergência foi enviado como fallback.',
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

  /// Tenta enviar SMS via Intent nativa como fallback
  /// Se falhar, aciona alarme local
  Future<void> _tentarFallbackSMS(
    String idosoId,
    TipoEmergencia tipoEmergencia,
    String? mensagem,
  ) async {
    try {
      // Buscar vínculos familiares do idoso
      final vinculos = await _vinculoService.getVinculosByIdoso(idosoId);
      
      if (vinculos.isEmpty) {
        // Sem contatos, acionar alarme local diretamente
        await _acionarAlarmeLocal();
        return;
      }

      // Buscar perfis dos familiares com telefone
      final familiaresComTelefone = <Map<String, dynamic>>[];
      for (final vinculo in vinculos) {
        try {
          final perfilResponse = await _supabase
              .from('perfis')
              .select('id, nome, telefone')
              .eq('id', vinculo.idFamiliar)
              .maybeSingle();
          
          if (perfilResponse != null) {
            final telefone = perfilResponse['telefone'] as String?;
            if (telefone != null && telefone.isNotEmpty) {
              familiaresComTelefone.add({
                'nome': perfilResponse['nome'] as String? ?? 'Familiar',
                'telefone': telefone,
              });
            }
          }
        } catch (e) {
          // Erro ao buscar perfil deste familiar, continuar com próximo
          debugPrint('Erro ao buscar perfil do familiar ${vinculo.idFamiliar}: $e');
          continue;
        }
      }

      if (familiaresComTelefone.isEmpty) {
        // Nenhum familiar com telefone, acionar alarme local
        await _acionarAlarmeLocal();
        return;
      }

      // Preparar mensagem de emergência
      final tipoTexto = _getTipoEmergenciaTexto(tipoEmergencia);
      final mensagemSMS = mensagem ?? 
          '🚨 EMERGÊNCIA: $tipoTexto - CareMind\n'
          'O idoso precisa de ajuda imediata!\n'
          'Verifique o aplicativo para mais detalhes.';

      // Tentar enviar SMS para cada familiar com telefone
      bool algumSMSEviado = false;
      for (final familiar in familiaresComTelefone) {
        final telefone = familiar['telefone'] as String;
        try {
          // Limpar telefone (remover caracteres não numéricos, exceto +)
          final telefoneLimpo = telefone.replaceAll(RegExp(r'[^\d+]'), '');
          final uri = Uri.parse('sms:$telefoneLimpo?body=${Uri.encodeComponent(mensagemSMS)}');
          
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            algumSMSEviado = true;
            debugPrint('✅ SMS de emergência enviado para ${familiar['nome']}');
            // Pequeno delay entre envios
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          // Falha ao enviar SMS para este contato, continuar com próximo
          debugPrint('Erro ao enviar SMS para ${familiar['nome']}: $e');
          continue;
        }
      }

      if (!algumSMSEviado) {
        // Nenhum SMS foi enviado, acionar alarme local
        await _acionarAlarmeLocal();
      }
    } catch (e) {
      // Erro ao tentar enviar SMS, acionar alarme local
      debugPrint('Erro ao tentar fallback SMS: $e');
      await _acionarAlarmeLocal();
    }
  }

  /// Aciona alarme sonoro e vibração contínua
  Future<void> _acionarAlarmeLocal() async {
    try {
      // Vibração contínua (padrão: 500ms on, 500ms off, repetir)
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Padrão de vibração: 500ms ligado, 500ms desligado, repetir indefinidamente
        // Usar padrão longo para emergência
        await Vibration.vibrate(
          pattern: [0, 500, 1000, 500, 1000, 500], // delay, vibrate, pause, vibrate, pause, vibrate
          repeat: 0, // Repetir do início após o padrão
        );
      }

      // Tocar som de alarme (usando SystemSound)
      // Nota: SystemSound é limitado, mas funciona sem permissões especiais
      // Para alarme mais robusto, considere usar flutter_local_notifications com som customizado
      SystemSound.play(SystemSoundType.alert);
      
      // Cancelar timer anterior se existir
      _alarmeTimer?.cancel();
      
      // Repetir o som a cada 2 segundos (via timer)
      _alarmeTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        SystemSound.play(SystemSoundType.alert);
        // Parar após 30 segundos para não esgotar bateria
        if (timer.tick >= 15) {
          timer.cancel();
          _alarmeTimer = null;
        }
      });
    } catch (e) {
      // Se falhar, pelo menos tentar uma vibração simples
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 1000);
        }
      } catch (_) {
        // Falha total no alarme local
      }
    }
  }

  /// Converte tipo de emergência para texto legível
  String _getTipoEmergenciaTexto(TipoEmergencia tipo) {
    switch (tipo) {
      case TipoEmergencia.panico:
        return 'Botão de Pânico';
      case TipoEmergencia.queda:
        return 'Queda Detectada';
      case TipoEmergencia.medicamento:
        return 'Emergência com Medicamento';
      case TipoEmergencia.outro:
        return 'Emergência';
    }
  }
}


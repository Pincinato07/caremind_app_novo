import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import 'location_service.dart' hide TimeoutException;
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
  final SupabaseClient _supabase;
  final LocationService _locationService;
  final VinculoFamiliarService _vinculoService;
  static const Duration _apiTimeout = Duration(seconds: 10);
  static const Duration _gpsTimeout = Duration(seconds: 3); // Reduzido de 8s para 3s (VULN-003)
  Timer? _alarmeTimer; // Timer para controlar repetição do som de alarme

  /// Construtor com injeção de dependência opcional
  /// Se [supabaseClient] for null, usa Supabase.instance.client
  /// Se [locationService] for null, cria uma nova instância
  EmergenciaService({
    SupabaseClient? supabaseClient,
    LocationService? locationService,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _locationService = locationService ?? LocationService(),
        _vinculoService = VinculoFamiliarService(
          supabaseClient ?? Supabase.instance.client,
        );

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
            throw TimeoutException(message: 'API timeout após 10 segundos');
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
          final fallbackResult = await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
          // Verificar se fallback funcionou (VULN-001)
          if (!fallbackResult['sucesso']) {
            throw UnknownException(
              message: '$errorMessage. Nenhum familiar foi notificado. Tente ligar diretamente para emergência (192).',
            );
          }
          throw UnknownException(
            message: '$errorMessage. SMS de emergência foi enviado como fallback para ${fallbackResult['familiares_notificados']} familiar(es).',
          );
        }

        // Verificar se realmente houve sucesso (VULN-001, VULN-004)
        final resultadosTwilio = data['resultados_twilio'] as List? ?? [];
        final resultadosPush = data['resultados_push'] as List? ?? [];
        final warning = data['warning'] as bool? ?? false;
        
        // Contar quantos canais funcionaram
        final smsEnviados = resultadosTwilio.where((r) => r['sms'] == 'enviado').length;
        final pushEnviados = resultadosPush.where((r) => r['push'] == 'enviado').length;
        final canaisFuncionando = (smsEnviados > 0 ? 1 : 0) + (pushEnviados > 0 ? 1 : 0);
        
        // Se nenhum canal funcionou, tentar fallback
        if (canaisFuncionando == 0 && !warning) {
          debugPrint('⚠️ Nenhum canal funcionou na API, tentando fallback SMS');
          final fallbackResult = await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
          if (!fallbackResult['sucesso']) {
            throw UnknownException(
              message: 'Nenhum familiar foi notificado. Tente ligar diretamente para emergência (192).',
            );
          }
          // Adicionar informações do fallback ao resultado
          data['fallback_usado'] = true;
          data['familiares_notificados'] = fallbackResult['familiares_notificados'];
        }
        
        // Adicionar informações detalhadas sobre canais
        data['canais_funcionando'] = canaisFuncionando;
        data['sms_enviados'] = smsEnviados;
        data['push_enviados'] = pushEnviados;
        data['warning'] = warning;
        
        // Sucesso na API
        return data;
      } on TimeoutException {
        // Timeout da API após 10s - acionar fallback SMS (VULN-001)
        final fallbackResult = await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        if (!fallbackResult['sucesso']) {
          throw UnknownException(
            message: 'Tempo esgotado ao acionar emergência. Nenhum familiar foi notificado. Tente ligar diretamente para emergência (192).',
          );
        }
        throw UnknownException(
          message:
              'Tempo esgotado ao acionar emergência. SMS de emergência foi enviado como fallback para ${fallbackResult['familiares_notificados']} familiar(es).',
        );
      } catch (apiError) {
        // Qualquer erro da API - tentar fallback SMS (VULN-001)
        final fallbackResult = await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        if (!fallbackResult['sucesso']) {
          throw UnknownException(
            message: 'Erro ao acionar emergência. Nenhum familiar foi notificado. Tente ligar diretamente para emergência (192).',
          );
        }
        // Re-throw com informação do fallback
        throw UnknownException(
          message: 'Erro ao acionar emergência. SMS de emergência foi enviado como fallback para ${fallbackResult['familiares_notificados']} familiar(es).',
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      // Verificar se é erro de conexão
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException') ||
          e.toString().contains('Failed host lookup')) {
        // Sem conexão - tentar fallback SMS (VULN-001)
        final fallbackResult = await _tentarFallbackSMS(idosoId, tipoEmergencia, mensagem);
        if (!fallbackResult['sucesso']) {
          await _acionarAlarmeLocal();
          throw UnknownException(
            message:
                'Sem conexão com a internet. Nenhum familiar foi notificado. Tente ligar diretamente para emergência (192).',
          );
        }
        throw UnknownException(
          message:
              'Sem conexão com a internet. SMS de emergência foi enviado como fallback para ${fallbackResult['familiares_notificados']} familiar(es).',
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
    // Se localização não foi fornecida e capturarGPS é true, tentar capturar (VULN-003: timeout reduzido)
    Map<String, double>? localizacaoFinal = localizacao;
    bool localizacaoCapturada = localizacao != null;
    if (localizacaoFinal == null && capturarGPS) {
      try {
        localizacaoFinal = await _locationService
            .getCurrentLocation(timeout: _gpsTimeout)
            .timeout(_gpsTimeout);
        localizacaoCapturada = true;
        debugPrint('✅ Localização GPS capturada com sucesso');
      } on LocationException catch (e) {
        // Log do erro mas continuar sem localização
        debugPrint('⚠️ Erro ao capturar GPS: ${e.userFriendlyMessage}');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      } on TimeoutException {
        // Timeout - continuar sem localização
        debugPrint('⚠️ Timeout ao capturar GPS (${_gpsTimeout.inSeconds}s)');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      } catch (e) {
        // Qualquer outro erro - continuar sem localização
        debugPrint('⚠️ Erro inesperado ao capturar GPS: $e');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      }
    }

    // Sempre tentar enviar o alerta, mesmo sem localização
    final resultado = await acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.panico,
      mensagem: 'Botão de pânico acionado - precisa de ajuda imediata!',
      localizacao: localizacaoFinal,
    );
    
    // Adicionar informação sobre localização (VULN-007)
    resultado['localizacao_capturada'] = localizacaoCapturada;
    if (!localizacaoCapturada && localizacaoFinal == null) {
      resultado['localizacao_disponivel'] = false;
    } else {
      resultado['localizacao_disponivel'] = true;
    }
    
    return resultado;
  }

  /// Aciona emergência por queda detectada
  /// Captura GPS automaticamente se não for fornecido
  /// Continua mesmo se GPS falhar (alerta enviado sem localização)
  Future<Map<String, dynamic>> acionarQueda({
    required String idosoId,
    Map<String, double>? localizacao,
    bool capturarGPS = true,
  }) async {
    // Se localização não foi fornecida e capturarGPS é true, tentar capturar (VULN-003: timeout reduzido)
    Map<String, double>? localizacaoFinal = localizacao;
    bool localizacaoCapturada = localizacao != null;
    if (localizacaoFinal == null && capturarGPS) {
      try {
        localizacaoFinal = await _locationService
            .getCurrentLocation(timeout: _gpsTimeout)
            .timeout(_gpsTimeout);
        localizacaoCapturada = true;
        debugPrint('✅ Localização GPS capturada com sucesso');
      } on LocationException catch (e) {
        debugPrint('⚠️ Erro ao capturar GPS: ${e.userFriendlyMessage}');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      } on TimeoutException {
        debugPrint('⚠️ Timeout ao capturar GPS (${_gpsTimeout.inSeconds}s)');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      } catch (e) {
        debugPrint('⚠️ Erro inesperado ao capturar GPS: $e');
        localizacaoFinal = null;
        localizacaoCapturada = false;
      }
    }

    // Sempre tentar enviar o alerta, mesmo sem localização
    final resultado = await acionarEmergencia(
      idosoId: idosoId,
      tipoEmergencia: TipoEmergencia.queda,
      mensagem: 'Queda detectada - verificação imediata necessária!',
      localizacao: localizacaoFinal,
    );
    
    // Adicionar informação sobre localização (VULN-007)
    resultado['localizacao_capturada'] = localizacaoCapturada;
    resultado['localizacao_disponivel'] = localizacaoFinal != null;
    
    return resultado;
  }

  /// Tenta enviar SMS via Intent nativa como fallback
  /// Se falhar, aciona alarme local
  /// Retorna informações sobre o resultado (VULN-001, VULN-002)
  Future<Map<String, dynamic>> _tentarFallbackSMS(
    String idosoId,
    TipoEmergencia tipoEmergencia,
    String? mensagem,
  ) async {
    try {
      // 1. Verificar se o idoso pertence a uma organização (SOS Institucional)
      String? organizacaoId;
      try {
        final idosoOrgResponse = await _supabase
            .from('idosos_organizacao')
            .select('organizacao_id')
            .eq('perfil_id', idosoId)
            .maybeSingle();
            
        if (idosoOrgResponse != null) {
          organizacaoId = idosoOrgResponse['organizacao_id'] as String?;
        }
      } catch (e) {
        debugPrint('Erro ao buscar organização do idoso: $e');
      }

      final contatosNotificar = <Map<String, dynamic>>[];

      // 2. Se houver organização, buscar enfermeiros e admins
      if (organizacaoId != null) {
        try {
          final membrosResponse = await _supabase
              .from('membros_organizacao')
              .select('role, perfil:perfis(nome, telefone)')
              .eq('organizacao_id', organizacaoId)
              .eq('ativo', true)
              .inFilter('role', ['enfermeiro', 'admin', 'cuidador']);

          for (final m in membrosResponse as List) {
            final perfil = m['perfil'] as Map<String, dynamic>?;
            final role = m['role'] as String;
            if (perfil != null) {
              final telefone = perfil['telefone'] as String?;
              if (telefone != null && telefone.isNotEmpty) {
                contatosNotificar.add({
                  'nome': '${perfil['nome']} ($role)',
                  'telefone': telefone,
                  'prioritario': true,
                });
              }
            }
          }
          debugPrint('🏥 Encontrados ${contatosNotificar.length} membros da organização para SOS');
        } catch (e) {
          debugPrint('Erro ao buscar membros da organização: $e');
        }
      }

      // 3. Buscar vínculos familiares
      final vinculos = await _vinculoService.getVinculosByIdoso(idosoId);
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
              // Evitar duplicidade se o familiar também for membro da org
              if (!contatosNotificar.any((c) => c['telefone'] == telefone)) {
                contatosNotificar.add({
                  'nome': perfilResponse['nome'] as String? ?? 'Familiar',
                  'telefone': telefone,
                  'prioritario': false,
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Erro ao buscar perfil do familiar: $e');
        }
      }

      if (contatosNotificar.isEmpty) {
        // Sem contatos, acionar alarme local diretamente (VULN-002)
        await _acionarAlarmeLocal();
        return {
          'sucesso': false,
          'contatos_notificados': 0,
          'erro': 'Nenhum contato (org ou família) encontrado',
        };
      }

      // Preparar mensagem de emergência
      final tipoTexto = _getTipoEmergenciaTexto(tipoEmergencia);
      final mensagemSMS = mensagem ??
          '🚨 EMERGÊNCIA: $tipoTexto - CareMind\n'
              'O idoso precisa de ajuda imediata!\n'
              'Local: ${organizacaoId != null ? 'Unidade Institucional' : 'Residência'}\n'
              'Verifique o aplicativo agora.';

      // Tentar enviar SMS (prioritários primeiro)
      int smsEnviadosSucesso = 0;
      // Ordenar: prioritários (org) primeiro
      contatosNotificar.sort((a, b) => (b['prioritario'] as bool ? 1 : 0).compareTo(a['prioritario'] as bool ? 1 : 0));

      for (final contato in contatosNotificar) {
        final telefone = contato['telefone'] as String;
        try {
          final telefoneLimpo = telefone.replaceAll(RegExp(r'[^\d+]'), '');
          final uri = Uri.parse(
              'sms:$telefoneLimpo?body=${Uri.encodeComponent(mensagemSMS)}');

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
            smsEnviadosSucesso++;
            debugPrint('✅ SMS enviado para ${contato['nome']}');
            await Future.delayed(const Duration(milliseconds: 500));
          }
        } catch (e) {
          debugPrint('Erro ao enviar SMS para ${contato['nome']}: $e');
        }
      }

      if (smsEnviadosSucesso == 0) {
        await _acionarAlarmeLocal();
        return {
          'sucesso': false,
          'contatos_notificados': 0,
          'erro': 'Falha ao enviar SMS para todos os contatos',
        };
      }
      
      return {
        'sucesso': true,
        'familiares_notificados': smsEnviadosSucesso,
        'contatos_totais': contatosNotificar.length,
        'institucional': organizacaoId != null,
      };
    } catch (e) {
      debugPrint('Erro ao tentar fallback SMS: $e');
      await _acionarAlarmeLocal();
      return {
        'sucesso': false,
        'contatos_notificados': 0,
        'erro': 'Erro crítico no SOS: ${e.toString()}',
      };
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
          pattern: [
            0,
            500,
            1000,
            500,
            1000,
            500
          ], // delay, vibrate, pause, vibrate, pause, vibrate
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

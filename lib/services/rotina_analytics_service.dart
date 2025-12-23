import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/injection/injection.dart';
import 'supabase_service.dart';

/// Serviço de Analytics para Rotinas
///
/// Rastreia eventos relacionados a rotinas:
/// - Criação de rotinas
/// - Atualização de rotinas
/// - Conclusão de rotinas
/// - Uso de notificações
/// - Tipos de frequência mais usados
class RotinaAnalyticsService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Rastrear criação de rotina
  static Future<void> trackRotinaCriada({
    required int rotinaId,
    required String tipoFrequencia,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_criada',
        data: {
          'rotina_id': rotinaId,
          'tipo_frequencia': tipoFrequencia,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Rotina criada - ID: $rotinaId, Tipo: $tipoFrequencia');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear criação de rotina: $e');
    }
  }

  /// Rastrear atualização de rotina
  static Future<void> trackRotinaAtualizada({
    required int rotinaId,
    String? tipoFrequenciaAnterior,
    String? tipoFrequenciaNovo,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_atualizada',
        data: {
          'rotina_id': rotinaId,
          'tipo_frequencia_anterior': tipoFrequenciaAnterior,
          'tipo_frequencia_novo': tipoFrequenciaNovo,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Rotina atualizada - ID: $rotinaId');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear atualização de rotina: $e');
    }
  }

  /// Rastrear conclusão de rotina
  static Future<void> trackRotinaConcluida({
    required int rotinaId,
    required bool concluida,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: concluida ? 'rotina_concluida' : 'rotina_desmarcada',
        data: {
          'rotina_id': rotinaId,
          'concluida': concluida,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Rotina ${concluida ? "concluída" : "desmarcada"} - ID: $rotinaId');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear conclusão de rotina: $e');
    }
  }

  /// Rastrear exclusão de rotina
  static Future<void> trackRotinaExcluida({
    required int rotinaId,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_excluida',
        data: {
          'rotina_id': rotinaId,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Rotina excluída - ID: $rotinaId');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear exclusão de rotina: $e');
    }
  }

  /// Rastrear notificação de rotina enviada
  static Future<void> trackNotificacaoEnviada({
    required int rotinaId,
    required String tipoFrequencia,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_notificacao_enviada',
        data: {
          'rotina_id': rotinaId,
          'tipo_frequencia': tipoFrequencia,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Notificação de rotina enviada - ID: $rotinaId');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear notificação de rotina: $e');
    }
  }

  /// Rastrear notificação de rotina clicada
  static Future<void> trackNotificacaoClicada({
    required int rotinaId,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_notificacao_clicada',
        data: {
          'rotina_id': rotinaId,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Notificação de rotina clicada - ID: $rotinaId');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear clique em notificação: $e');
    }
  }

  /// Rastrear migração de dados legados
  static Future<void> trackMigracaoLegada({
    required int rotinasMigradas,
    String? perfilId,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return;

      await _trackEvent(
        eventType: 'rotina_migracao_legada',
        data: {
          'rotinas_migradas': rotinasMigradas,
          'perfil_id': perfilId ?? user.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('📊 Analytics: Migração legada - $rotinasMigradas rotina(s)');
    } catch (e) {
      debugPrint('⚠️ Erro ao rastrear migração legada: $e');
    }
  }

  /// Registrar evento de analytics
  static Future<void> _trackEvent({
    required String eventType,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Tentar inserir na tabela de analytics (se existir)
      // Se não existir, apenas logar
      try {
        await _client.from('analytics_eventos').insert({
          'tipo_evento': eventType,
          'dados': data,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Tabela pode não existir, apenas logar
        debugPrint('ℹ️ Tabela analytics_eventos não disponível, apenas logando evento');
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao registrar evento de analytics: $e');
      // Não relançar - analytics não deve quebrar o fluxo
    }
  }

  /// Obter estatísticas de rotinas do usuário
  static Future<Map<String, dynamic>> obterEstatisticasRotinas({
    String? perfilId,
    int dias = 30,
  }) async {
    try {
      final user = getIt<SupabaseService>().currentUser;
      if (user == null) return {};

      final targetPerfilId = perfilId ?? user.id;

      // Buscar rotinas do perfil
      final rotinasResponse = await _client
          .from('rotinas')
          .select()
          .eq('perfil_id', targetPerfilId);

      final rotinas = List<Map<String, dynamic>>.from(rotinasResponse);

      // Contar por tipo de frequência
      final frequenciasCount = <String, int>{};
      int totalConcluidas = 0;
      int totalPendentes = 0;

      for (final rotina in rotinas) {
        final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
        if (frequencia != null) {
          final tipo = frequencia['tipo'] as String? ?? 'desconhecido';
          frequenciasCount[tipo] = (frequenciasCount[tipo] ?? 0) + 1;
        }

        final concluido = rotina['concluido'] as bool? ?? false;
        if (concluido) {
          totalConcluidas++;
        } else {
          totalPendentes++;
        }
      }

      // Buscar eventos de conclusão dos últimos N dias
      final hoje = DateTime.now();
      final inicioPeriodo = hoje.subtract(Duration(days: dias));
      
      final eventosResponse = await _client
          .from('historico_eventos')
          .select()
          .eq('perfil_id', targetPerfilId)
          .eq('tipo_evento', 'rotina')
          .gte('data_prevista', inicioPeriodo.toIso8601String())
          .lte('data_prevista', hoje.toIso8601String());

      final eventos = List<Map<String, dynamic>>.from(eventosResponse);
      final eventosConcluidos = eventos.where((e) => e['status'] == 'confirmado').length;
      final totalEventos = eventos.length;
      final taxaConclusao = totalEventos > 0 ? (eventosConcluidos / totalEventos) * 100 : 0.0;

      return {
        'total_rotinas': rotinas.length,
        'total_concluidas': totalConcluidas,
        'total_pendentes': totalPendentes,
        'frequencias_count': frequenciasCount,
        'eventos_periodo': totalEventos,
        'eventos_concluidos': eventosConcluidos,
        'taxa_conclusao': taxaConclusao,
        'periodo_dias': dias,
      };
    } catch (e) {
      debugPrint('❌ Erro ao obter estatísticas de rotinas: $e');
      return {};
    }
  }
}


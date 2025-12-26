import 'package:flutter/material.dart';
import 'supabase_service.dart';
import '../../core/injection/injection.dart';

/// Serviço para gerenciar check-ins de bem-estar
/// Usa a tabela metricas_saude com tipo = 'humor'
/// Permite que Familiar e Organização visualizem dados dos idosos
class WellbeingService {
  static WellbeingService? _instance;

  factory WellbeingService() {
    _instance ??= WellbeingService._internal();
    return _instance!;
  }

  WellbeingService._internal();

  /// Registra um check-in de bem-estar
  /// Usa a função segura do banco que já verifica permissões
  Future<String?> registrarCheckin({
    required String perfilId,
    required String humor, // 'radiante', 'ok', 'mal'
    String? observacoes,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final result = await supabase.client.rpc(
        'registrar_checkin_bem_estar',
        params: {
          'p_perfil_id': perfilId,
          'p_humor': humor,
          'p_observacoes': observacoes,
        },
      );

      debugPrint('✅ Check-in de bem-estar registrado: $result');
      return result as String?;
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao registrar check-in - $e');
      return null;
    }
  }

  /// Verifica se o usuário logado pode ver o bem-estar de um perfil
  Future<bool> podeVerWellbeing(String perfilId) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final response = await supabase.client.rpc(
        'pode_ver_wellbeing_checkin',
        params: {'p_perfil_id': perfilId},
      );
      
      return response == true;
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao verificar permissão - $e');
      return false;
    }
  }

  /// Obtém histórico de bem-estar de um perfil
  /// Retorna lista de dias com contagem por humor
  Future<List<Map<String, dynamic>>> obterHistorico({
    required String perfilId,
    int dias = 30,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final response = await supabase.client.rpc(
        'obter_historico_bem_estar',
        params: {
          'p_perfil_id': perfilId,
          'p_dias': dias,
        },
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao obter histórico - $e');
      return [];
    }
  }

  /// Obtém último humor de um perfil
  Future<String?> obterUltimoHumor(String perfilId) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final response = await supabase.client.rpc(
        'obter_ultimo_humor',
        params: {'p_perfil_id': perfilId},
      );

      return response as String?;
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao obter último humor - $e');
      return null;
    }
  }

  /// Conta check-ins por humor nos últimos dias
  Future<Map<String, int>> contarPorHumor({
    required String perfilId,
    int dias = 7,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final response = await supabase.client.rpc(
        'contar_checkins_por_humor',
        params: {
          'p_perfil_id': perfilId,
          'p_dias': dias,
        },
      );

      // Converte JSONB para Map
      final json = response as Map<String, dynamic>;
      return {
        'radiante': json['radiante'] as int? ?? 0,
        'ok': json['ok'] as int? ?? 0,
        'mal': json['mal'] as int? ?? 0,
        'total': json['total'] as int? ?? 0,
      };
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao contar por humor - $e');
      return {};
    }
  }

  /// Verifica se há alerta proativo (3 dias de mal-estar)
  Future<bool> verificarAlerta({
    required String perfilId,
    int dias = 3,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      // Usa a função que já dispara alertas se necessário
      final response = await supabase.client.rpc(
        'verificar_e_disparar_alerta_bem_estar',
        params: {'p_perfil_id': perfilId},
      );

      return response == true;
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao verificar alerta - $e');
      return false;
    }
  }

  /// Obtém últimos check-ins detalhados
  Future<List<Map<String, dynamic>>> obterCheckInsRecentes({
    required String perfilId,
    int limit = 10,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      // Verifica permissão primeiro
      final podeVer = await podeVerWellbeing(perfilId);
      if (!podeVer) {
        debugPrint('⚠️ Sem permissão para ver check-ins');
        return [];
      }

      final data = await supabase.client
          .from('metricas_saude')
          .select('id, valor, observacoes, data_hora')
          .eq('perfil_id', perfilId)
          .eq('tipo', 'humor')
          .order('data_hora', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao obter check-ins recentes - $e');
      return [];
    }
  }

  /// Exporta histórico para CSV
  Future<String?> exportarCSV({
    required String perfilId,
    int dias = 30,
  }) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      final response = await supabase.client.rpc(
        'exportar_bem_estar_csv',
        params: {
          'p_perfil_id': perfilId,
          'p_dias': dias,
        },
      );

      return response as String?;
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao exportar CSV - $e');
      return null;
    }
  }

  /// Obtém dados agregados para dashboard
  Future<Map<String, dynamic>> obterDashboardData({
    required String perfilId,
    int dias = 7,
  }) async {
    try {
      final historico = await obterHistorico(perfilId: perfilId, dias: dias);
      final contagem = await contarPorHumor(perfilId: perfilId, dias: dias);
      final ultimo = await obterUltimoHumor(perfilId);

      return {
        'historico': historico,
        'contagem': contagem,
        'ultimo_humor': ultimo,
        'tem_alerta': (contagem['mal'] ?? 0) >= 3,
      };
    } catch (e) {
      debugPrint('❌ WellbeingService: Erro ao obter dashboard - $e');
      return {};
    }
  }
}

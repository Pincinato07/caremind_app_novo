import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version.dart';

/// Serviço de administração de versões
/// DEVE ser usado apenas em Server Actions ou com SUPABASE_SECRET_KEY
class AdminVersionService {
  final SupabaseClient _supabase;

  AdminVersionService(this._supabase);

  /// Cadastra uma nova versão
  /// Requer autenticação com role 'admin'
  Future<AppVersion?> createVersion({
    required String versionName,
    required int buildNumber,
    required String downloadUrl,
    bool isMandatory = false,
    String? changelog,
    String platform = 'all',
    String? minOsVersion,
  }) async {
    try {
      final response = await _supabase
          .from('app_versions_control')
          .insert({
            'version_name': versionName,
            'build_number': buildNumber,
            'download_url': downloadUrl,
            'is_mandatory': isMandatory,
            'changelog': changelog,
            'platform': platform,
            'min_os_version': minOsVersion,
          })
          .select()
          .single();

      return AppVersion.fromJson(response);
    } catch (e) {
      print('❌ Erro ao criar versão: $e');
      return null;
    }
  }

  /// Atualiza uma versão existente
  Future<AppVersion?> updateVersion({
    required String versionId,
    String? versionName,
    int? buildNumber,
    String? downloadUrl,
    bool? isMandatory,
    String? changelog,
    String? platform,
    String? minOsVersion,
    bool? active,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (versionName != null) updates['version_name'] = versionName;
      if (buildNumber != null) updates['build_number'] = buildNumber;
      if (downloadUrl != null) updates['download_url'] = downloadUrl;
      if (isMandatory != null) updates['is_mandatory'] = isMandatory;
      if (changelog != null) updates['changelog'] = changelog;
      if (platform != null) updates['platform'] = platform;
      if (minOsVersion != null) updates['min_os_version'] = minOsVersion;
      if (active != null) updates['active'] = active;

      final response = await _supabase
          .from('app_versions_control')
          .update(updates)
          .eq('id', versionId)
          .select()
          .single();

      return AppVersion.fromJson(response);
    } catch (e) {
      print('❌ Erro ao atualizar versão: $e');
      return null;
    }
  }

  /// Deleta uma versão
  Future<bool> deleteVersion(String versionId) async {
    try {
      await _supabase
          .from('app_versions_control')
          .delete()
          .eq('id', versionId);
      
      return true;
    } catch (e) {
      print('❌ Erro ao deletar versão: $e');
      return false;
    }
  }

  /// Obtém todas as versões com paginação
  Future<List<AppVersion>> getVersions({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('app_versions_control')
          .select()
          .order('build_number', ascending: false)
          .range(offset, offset + limit - 1);

      if (response == null || response.isEmpty) return [];

      return response.map((v) => AppVersion.fromJson(v)).toList();
    } catch (e) {
      print('❌ Erro ao buscar versões: $e');
      return [];
    }
  }

  /// Obtém uma versão específica por ID
  Future<AppVersion?> getVersionById(String versionId) async {
    try {
      final response = await _supabase
          .from('app_versions_control')
          .select()
          .eq('id', versionId)
          .single();

      if (response == null) return null;
      return AppVersion.fromJson(response);
    } catch (e) {
      print('❌ Erro ao buscar versão por ID: $e');
      return null;
    }
  }

  /// Obtém a versão mais recente
  Future<AppVersion?> getLatestVersion() async {
    try {
      final response = await _supabase
          .from('app_versions_control')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .single();

      if (response == null) return null;
      return AppVersion.fromJson(response);
    } catch (e) {
      print('❌ Erro ao buscar versão mais recente: $e');
      return null;
    }
  }

  /// Define uma versão como obrigatória
  Future<bool> setMandatory(String versionId, bool mandatory) async {
    try {
      await _supabase
          .from('app_versions_control')
          .update({'is_mandatory': mandatory})
          .eq('id', versionId);
      
      return true;
    } catch (e) {
      print('❌ Erro ao definir obrigatória: $e');
      return false;
    }
  }

  /// Obtém estatísticas de uso das versões
  Future<Map<String, dynamic>> getVersionStats() async {
    try {
      // Usa a view de analytics
      final response = await _supabase
          .from('analytics_version_usage')
          .select();

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('❌ Erro ao buscar estatísticas: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Obtém dispositivos usando uma versão específica
  Future<List<Map<String, dynamic>>> getDevicesUsingVersion(int buildNumber) async {
    try {
      final response = await _supabase
          .from('app_version_access_log')
          .select()
          .eq('build_number', buildNumber)
          .order('accessed_at', ascending: false)
          .limit(100);

      return response ?? [];
    } catch (e) {
      print('❌ Erro ao buscar dispositivos: $e');
      return [];
    }
  }

  /// Limpa logs de acesso antigos
  Future<int> cleanupOldLogs({int daysToKeep = 90}) async {
    try {
      final response = await _supabase.rpc(
        'cleanup_old_version_logs',
        params: {'days_to_keep': daysToKeep},
      );
      return response ?? 0;
    } catch (e) {
      print('❌ Erro ao limpar logs: $e');
      return 0;
    }
  }
}

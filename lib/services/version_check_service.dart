import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version.dart';

/// Serviço responsável por verificar e gerenciar versões do aplicativo
class VersionCheckService {
  static const String _lastSeenVersionKey = 'caremind_last_seen_version';
  static const String _remindLaterKey = 'caremind_remind_later_version';
  
  // Versão atual do build do app
  // DEVE ser incrementada a cada deploy
  static const int CURRENT_APP_BUILD = 1;

  final SupabaseClient _supabase;

  VersionCheckService(this._supabase);

  /// Busca a versão mais recente do Supabase
  Future<AppVersion?> getLatestVersion() async {
    try {
      final response = await _supabase
          .from('app_versions')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .single();

      if (response == null) return null;

      return AppVersion.fromJson(response);
    } catch (e) {
      print('❌ Erro ao buscar versão do app: $e');
      return null;
    }
  }

  /// Verifica se há uma nova versão disponível
  Future<bool> hasNewVersion() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final lastSeenVersion = prefs.getInt(_lastSeenVersionKey);

      return lastSeenVersion != latestVersion.buildNumber;
    } catch (e) {
      print('❌ Erro ao verificar nova versão: $e');
      return false;
    }
  }

  /// Verifica se o app está bloqueado (versão obrigatória desatualizada)
  Future<bool> isBlocked() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return false;

      // Se a versão mais recente é obrigatória E maior que a atual
      return latestVersion.isMandatory == true && 
             latestVersion.buildNumber > CURRENT_APP_BUILD;
    } catch (e) {
      print('❌ Erro ao verificar bloqueio: $e');
      return false;
    }
  }

  /// Obtém o motivo do bloqueio (se houver)
  Future<String?> getBlockReason() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return null;

      if (latestVersion.isMandatory == true && 
          latestVersion.buildNumber > CURRENT_APP_BUILD) {
        if (latestVersion.changelog != null && latestVersion.changelog!.isNotEmpty) {
          return 'Atualização obrigatória:\n\n${latestVersion.changelog}';
        }
        return 'Uma atualização obrigatória está disponível. Por favor, atualize o aplicativo para continuar.';
      }

      return null;
    } catch (e) {
      print('❌ Erro ao obter motivo do bloqueio: $e');
      return null;
    }
  }

  /// Marca a versão atual como vista
  Future<void> markVersionAsSeen() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSeenVersionKey, latestVersion.buildNumber);
    } catch (e) {
      print('❌ Erro ao marcar versão como vista: $e');
    }
  }

  /// Verifica se o usuário escolheu "lembrar depois" para esta versão
  Future<bool> shouldRemindLater() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final remindLaterVersion = prefs.getInt(_remindLaterKey);

      return remindLaterVersion == latestVersion.buildNumber;
    } catch (e) {
      print('❌ Erro ao verificar lembrar depois: $e');
      return false;
    }
  }

  /// Salva a preferência de "lembrar depois"
  Future<void> setRemindLater() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_remindLaterKey, latestVersion.buildNumber);
    } catch (e) {
      print('❌ Erro ao salvar lembrar depois: $e');
    }
  }

  /// Limpa a preferência de "lembrar depois"
  Future<void> clearRemindLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_remindLaterKey);
    } catch (e) {
      print('❌ Erro ao limpar lembrar depois: $e');
    }
  }

  /// Obtém informações do pacote atual
  Future<PackageInfo> getCurrentPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// Obtém a versão atual formatada
  Future<String> getCurrentVersionFormatted() async {
    final packageInfo = await getCurrentPackageInfo();
    return '${packageInfo.version}+${packageInfo.buildNumber} (Build $CURRENT_APP_BUILD)';
  }
}

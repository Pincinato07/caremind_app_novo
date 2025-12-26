import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import '../models/app_version.dart';
import '../core/config/app_config.dart';

/// Serviço de sincronização avançada do sistema de versões
/// Gerencia a comunicação completa com a tabela app_versions_control
class VersionSyncService {
  static const String _lastSeenVersionKey = 'caremind_last_seen_version';
  static const String _remindLaterKey = 'caremind_remind_later_version';
  static const String _lastSyncKey = 'caremind_last_sync_timestamp';
  
  // Usa a configuração centralizada
  static const int CURRENT_APP_BUILD = AppConfig.CURRENT_BUILD_NUMBER;

  final SupabaseClient _supabase;

  VersionSyncService(this._supabase);

  /// Obtém a plataforma atual (android/ios)
  String get _currentPlatform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'all';
  }

  /// Busca a versão mais recente do Supabase com filtros de plataforma
  Future<AppVersion?> getLatestVersion() async {
    try {
      // Busca versões compatíveis com a plataforma atual
      // Prioridade: versões específicas > versões 'all'
      final response = await _supabase
          .from('app_versions_control')
          .select()
          .or('platform.eq.$_currentPlatform,platform.eq.all')
          .eq('active', true) // Supondo que haja um campo active
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

  /// Busca todas as versões disponíveis (útil para debug/admin)
  Future<List<AppVersion>> getAllVersions() async {
    try {
      final response = await _supabase
          .from('app_versions_control')
          .select()
          .order('build_number', ascending: false);

      if (response == null || response.isEmpty) return [];

      return response
          .map((version) => AppVersion.fromJson(version))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar todas as versões: $e');
      return [];
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

      // Verifica se a versão é obrigatória e maior que a atual
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

  /// Define que o usuário escolheu "lembrar depois"
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

  /// Verifica se deve lembrar depois
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

  /// Limpa a preferência de "lembrar depois"
  Future<void> clearRemindLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_remindLaterKey);
    } catch (e) {
      print('❌ Erro ao limpar lembrar depois: $e');
    }
  }

  /// Registra o acesso do usuário à versão (analytics)
  Future<void> registerVersionAccess() async {
    try {
      final latestVersion = await getLatestVersion();
      if (latestVersion == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      
      String deviceId = '';
      String osVersion = '';
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
          osVersion = 'Android ${androidInfo.version.release}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? '';
          osVersion = 'iOS ${iosInfo.systemVersion}';
        }
      } catch (e) {
        deviceId = 'unknown';
        osVersion = 'unknown';
      }

      // Insere registro de acesso (tabela opcional)
      await _supabase.from('app_version_access_log').insert({
        'version_id': latestVersion.id,
        'device_id': deviceId,
        'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
        'build_number': CURRENT_APP_BUILD,
        'os_version': osVersion,
        'platform': _currentPlatform,
        'accessed_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Não bloqueia o app se falhar
      print('⚠️ Não foi registrar acesso à versão: $e');
    }
  }

  /// Sincroniza informações do dispositivo com o Supabase
  Future<void> syncDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      
      String deviceId = '';
      String deviceModel = '';
      String osVersion = '';
      
      try {
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
          deviceModel = androidInfo.model;
          osVersion = androidInfo.version.release;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? '';
          deviceModel = iosInfo.utsname.machine;
          osVersion = iosInfo.systemVersion;
        }
      } catch (e) {
        deviceId = 'unknown';
        deviceModel = 'unknown';
        osVersion = 'unknown';
      }

      // Verifica se usuário está logado
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Insere ou atualiza informações do dispositivo
      await _supabase.from('user_devices').upsert({
        'user_id': user.id,
        'device_id': deviceId,
        'device_model': deviceModel,
        'os_version': osVersion,
        'platform': _currentPlatform,
        'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',
        'build_number': CURRENT_APP_BUILD,
        'last_sync': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,device_id');
    } catch (e) {
      print('⚠️ Não foi sincronizarDeviceInfo: $e');
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

  /// Verifica se há sincronização recente
  Future<bool> hasRecentSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey);
      
      if (lastSync == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - lastSync;
      
      // Considera recente se sincronizado nos últimos 5 minutos
      return diff < 5 * 60 * 1000;
    } catch (e) {
      return false;
    }
  }

  /// Registra a última sincronização
  Future<void> updateLastSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Erro ao atualizar timestamp de sincronização: $e');
    }
  }
}

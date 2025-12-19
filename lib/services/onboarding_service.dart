import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço para gerenciar estado de onboarding contextual
class OnboardingService {
  static const String _keyFirstAccess = 'onboarding_first_access';
  static const String _keyFirstMedicamento = 'onboarding_first_medicamento';
  static const String _keyFirstIdoso = 'onboarding_first_idoso';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyLastOnboardingShown = 'onboarding_last_shown';

  /// Verifica se é o primeiro acesso do usuário
  static Future<bool> isFirstAccess(String userId) async {
    try {
      if (userId.isEmpty) return true; // Se não tem userId, considera primeiro acesso
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstAccess}_$userId';
      final value = prefs.getBool(key);
      return value != true; // Retorna true se não foi marcado ainda
    } catch (e) {
      // Em caso de erro, assume primeiro acesso para não bloquear usuário
      debugPrint('⚠️ Erro ao verificar primeiro acesso: $e');
      return true;
    }
  }

  /// Marca que o usuário já acessou pela primeira vez
  static Future<void> markFirstAccess(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de marcar primeiro acesso com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstAccess}_$userId';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar primeiro acesso: $e');
      // Não lança exceção para não bloquear fluxo
    }
  }

  /// Verifica se o usuário já cadastrou o primeiro medicamento
  static Future<bool> hasFirstMedicamento(String userId) async {
    try {
      if (userId.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstMedicamento}_$userId';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar primeiro medicamento: $e');
      return false; // Em caso de erro, assume que não tem
    }
  }

  /// Marca que o usuário cadastrou o primeiro medicamento
  static Future<void> markFirstMedicamento(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de marcar primeiro medicamento com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstMedicamento}_$userId';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar primeiro medicamento: $e');
      // Não lança exceção para não bloquear fluxo
    }
  }

  /// Verifica se o usuário já cadastrou o primeiro idoso (para familiar)
  static Future<bool> hasFirstIdoso(String userId) async {
    try {
      if (userId.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstIdoso}_$userId';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar primeiro idoso: $e');
      return false;
    }
  }

  /// Marca que o usuário cadastrou o primeiro idoso
  static Future<void> markFirstIdoso(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de marcar primeiro idoso com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyFirstIdoso}_$userId';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar primeiro idoso: $e');
    }
  }

  /// Verifica se o onboarding foi completado
  static Future<bool> isOnboardingCompleted(String userId) async {
    try {
      if (userId.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyOnboardingCompleted}_$userId';
      return prefs.getBool(key) ?? false;
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar onboarding completado: $e');
      return false;
    }
  }

  /// Marca o onboarding como completado
  static Future<void> markOnboardingCompleted(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de marcar onboarding completado com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyOnboardingCompleted}_$userId';
      await prefs.setBool(key, true);
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar onboarding completado: $e');
    }
  }

  /// Verifica se deve mostrar onboarding (evita spam)
  static Future<bool> shouldShowOnboarding(String userId, {Duration cooldown = const Duration(hours: 24)}) async {
    try {
      if (userId.isEmpty) return true; // Se não tem userId, pode mostrar
      final prefs = await SharedPreferences.getInstance();
      final lastShownKey = '${_keyLastOnboardingShown}_$userId';
      final lastShown = prefs.getInt(lastShownKey);
      
      if (lastShown == null) return true;
      
      final lastShownDate = DateTime.fromMillisecondsSinceEpoch(lastShown);
      final now = DateTime.now();
      final difference = now.difference(lastShownDate);
      
      return difference >= cooldown;
    } catch (e) {
      debugPrint('⚠️ Erro ao verificar se deve mostrar onboarding: $e');
      return true; // Em caso de erro, permite mostrar
    }
  }

  /// Marca que o onboarding foi mostrado agora
  static Future<void> markOnboardingShown(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de marcar onboarding mostrado com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyLastOnboardingShown}_$userId';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar onboarding mostrado: $e');
    }
  }

  /// Reseta todo o onboarding (útil para testes)
  static Future<void> resetOnboarding(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('⚠️ Tentativa de resetar onboarding com userId vazio');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyFirstAccess}_$userId');
      await prefs.remove('${_keyFirstMedicamento}_$userId');
      await prefs.remove('${_keyFirstIdoso}_$userId');
      await prefs.remove('${_keyOnboardingCompleted}_$userId');
      await prefs.remove('${_keyLastOnboardingShown}_$userId');
    } catch (e) {
      debugPrint('⚠️ Erro ao resetar onboarding: $e');
      // Não lança exceção
    }
  }
}


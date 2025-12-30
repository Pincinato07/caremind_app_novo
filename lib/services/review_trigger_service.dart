import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Serviço responsável por gerenciar o trigger de avaliação
/// Após 10 medicamentos tomados consecutivos, mostra o popup de avaliação
class ReviewTriggerService {
  static const String _keyStreakCount = 'review_streak_count';
  static const String _keyHasShownReview = 'review_has_shown';
  static const int STREAK_THRESHOLD = 10; // 10 remédios consecutivos

  /// Verifica se deve mostrar o popup de avaliação
  /// Deve ser chamado APÓS marcar um medicamento como tomado
  static Future<bool> shouldShowReviewPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Verifica se já mostrou a avaliação
      final hasShown = prefs.getBool(_keyHasShownReview) ?? false;
      if (hasShown) return false;

      // Verifica o streak atual
      final currentStreak = prefs.getInt(_keyStreakCount) ?? 0;
      
      return currentStreak >= STREAK_THRESHOLD;
    } catch (e) {
      print('Erro ao verificar review trigger: $e');
      return false;
    }
  }

  /// Incrementa o contador de streak (chamar APÓS marcar medicamento como tomado)
  static Future<void> incrementStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt(_keyStreakCount) ?? 0;
      final newStreak = currentStreak + 1;
      
      await prefs.setInt(_keyStreakCount, newStreak);
      print('✅ ReviewTrigger: Streak incrementado para $newStreak');
      
      // Se atingiu o threshold, marca como "já mostrado" para não repetir
      if (newStreak >= STREAK_THRESHOLD) {
        await prefs.setBool(_keyHasShownReview, true);
        print('✅ ReviewTrigger: Threshold atingido, marcado como já mostrado');
      }
    } catch (e) {
      print('Erro ao incrementar streak: $e');
    }
  }

  /// Reseta o streak (chamar quando usuário recusar ou já tiver avaliado)
  static Future<void> resetStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStreakCount, 0);
      print('✅ ReviewTrigger: Streak resetado');
    } catch (e) {
      print('Erro ao resetar streak: $e');
    }
  }

  /// Marca que o usuário já viu/ignorou a avaliação
  static Future<void> markAsShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasShownReview, true);
      print('✅ ReviewTrigger: Marcado como já mostrado');
    } catch (e) {
      print('Erro ao marcar como mostrado: $e');
    }
  }

  /// Abre o Google Search para comentários do CareMind
  /// (enquanto o app não está na Play Store)
  static Future<void> openStoreForReview() async {
    try {
      // URL para Google Search com comentários do CareMind
      const String googleSearchUrl = 
          'https://www.google.com/search?sca_esv=d21323678e646c0b&si=AMgyJEtREmoPL4P1I5IDCfuA8gybfVI2d5Uj7QMwYCZHKDZ-Ez2ToEqK3KUkCnCwMJHI60WDrf2j44pTXCVXIJy6DcSXaQJPLeuUHWYew22diff7Aix-K2IFWyhBqwDO1XKMqBmhubVb&q=Caremind+Coment%C3%A1rios&sa=X&ved=2ahUKEwif9_2VnNyRAxXZrJUCHWHrHc8Q0bkNegQILxAD&biw=1536&bih=702&dpr=1.25';

      // Tenta abrir a URL
      if (await canLaunchUrl(Uri.parse(googleSearchUrl))) {
        await launchUrl(
          Uri.parse(googleSearchUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: abrir URL genérica do Google
        await launchUrl(Uri.parse('https://www.google.com/search?q=Caremind+Coment%C3%A1rios'));
      }
    } catch (e) {
      print('Erro ao abrir Google Search para review: $e');
      rethrow;
    }
  }

  /// Obtém o streak atual (para debug ou exibição)
  static Future<int> getCurrentStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyStreakCount) ?? 0;
    } catch (e) {
      print('Erro ao obter streak: $e');
      return 0;
    }
  }

  /// Verifica se o usuário já foi questionado sobre avaliação
  static Future<bool> hasAlreadyBeenPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHasShownReview) ?? false;
    } catch (e) {
      print('Erro ao verificar se já foi promptado: $e');
      return false;
    }
  }
}


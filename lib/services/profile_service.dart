import 'package:flutter/foundation.dart';
import '../models/perfil.dart';
import '../core/errors/app_exception.dart';
import 'accessibility_service.dart';
import 'supabase_service.dart';

/// Serviço completo para gerenciamento de perfil do usuário individual
/// Oferece operações CRUD completas com TTS integrado
class ProfileService extends ChangeNotifier {
  final SupabaseService _supabaseService;
  Perfil? _currentProfile;
  bool _isLoading = false;
  String? _lastError;

  ProfileService(this._supabaseService);

  // Getters
  Perfil? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasProfile => _currentProfile != null;

  /// Carrega o perfil do usuário atual
  Future<Perfil?> loadProfile() async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      final profile = await _supabaseService.getProfile(user.id);
      _currentProfile = profile;

      // Anuncia carregamento do perfil com TTS
      if (profile != null) {
        await AccessibilityService.speak('Perfil carregado: ${profile.nome}.');
      } else {
        await AccessibilityService.speak('Nenhum perfil encontrado.');
      }

      notifyListeners();
      return profile;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao carregar perfil: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cria um novo perfil para o usuário
  Future<bool> createProfile({
    required String nome,
    required String tipo,
    String? telefone,
    String? fotoUrl,
    Map<String, dynamic>? preferencias,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw const AuthenticationException(message: 'Usuário não autenticado');
      }

      // Anuncia início da criação
      await AccessibilityService.speak('Criando perfil para $nome...');

      final profileData = {
        'id': user.id,
        'nome': nome,
        'tipo': tipo,
        'telefone': telefone,
        'foto_url': fotoUrl,
        'preferencias': preferencias ?? {},
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabaseService.client
          .from('perfis')
          .insert(profileData)
          .select()
          .single();

      _currentProfile = Perfil.fromMap(response);

      // Anuncia sucesso
      await AccessibilityService.speak(
          'Perfil criado com sucesso! Bem-vindo, $nome!');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak('Erro ao criar perfil: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza o perfil do usuário
  Future<void> updateProfile({
    String? nome,
    String? telefone,
    String? fotoUrl,
    Map<String, dynamic>? preferencias,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      if (_currentProfile == null) {
        throw const ValidationException(message: 'Nenhum perfil carregado');
      }

      // Anuncia início da atualização
      await AccessibilityService.speak('Atualizando perfil...');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nome != null) updateData['nome'] = nome;
      if (telefone != null) updateData['telefone'] = telefone;
      if (fotoUrl != null) updateData['foto_url'] = fotoUrl;
      if (preferencias != null) updateData['preferencias'] = preferencias;

      final response = await _supabaseService.client
          .from('perfis')
          .update(updateData)
          .eq('id', _currentProfile!.id)
          .select()
          .single();

      _currentProfile = Perfil.fromMap(response);

      // Anuncia sucesso
      await AccessibilityService.speak('Perfil atualizado com sucesso!');

      notifyListeners();
      return;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao atualizar perfil: ${e.toString()}');
      return;
    } finally {
      _setLoading(false);
    }
  }

  /// Atualiza preferências do usuário
  Future<void> updatePreferencias(Map<String, dynamic> preferencias) async {
    if (_currentProfile == null) return;

    await updateProfile(preferencias: preferencias);
  }

  /// Atualiza foto do perfil
  Future<void> updateFoto(String fotoUrl) async {
    if (_currentProfile == null) return;

    await AccessibilityService.speak('Atualizando foto do perfil...');
    await updateProfile(fotoUrl: fotoUrl);
  }

  /// Exclui o perfil do usuário
  Future<bool> deleteProfile() async {
    _setLoading(true);
    _clearError();

    try {
      if (_currentProfile == null) {
        throw const ValidationException(message: 'Nenhum perfil carregado');
      }

      // Anuncia início da exclusão
      await AccessibilityService.speak('Excluindo perfil...');

      await _supabaseService.client
          .from('perfis')
          .delete()
          .eq('id', _currentProfile!.id);

      _currentProfile = null;

      // Anuncia sucesso
      await AccessibilityService.speak('Perfil excluído com sucesso.');

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      await AccessibilityService.speak(
          'Erro ao excluir perfil: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Limpa o perfil em memória (para logout)
  void clearProfile() {
    _currentProfile = null;
    _clearError();
    notifyListeners();
  }

  /// Valida dados do perfil
  String? validateProfile({
    String? nome,
    String? telefone,
  }) {
    if (nome != null && nome.trim().isEmpty) {
      return 'Nome do perfil é obrigatório';
    }

    if (telefone != null && telefone.trim().isNotEmpty) {
      // Validação básica de telefone (apenas números e DDD)
      final phoneRegex = RegExp(r'^\d{10,11}$');
      if (!phoneRegex.hasMatch(telefone.replaceAll(RegExp(r'[^\d]'), ''))) {
        return 'Telefone inválido. Use apenas números com DDD.';
      }
    }

    return null;
  }

  /// Obtém preferências específicas do usuário
  Map<String, dynamic> get preferencias {
    return {}; // Perfil não tem campo preferencias - retornando mapa vazio
  }

  /// Obtém uma preferência específica
  T? getPreferencia<T>(String key, [T? defaultValue]) {
    final prefs = preferencias;
    return prefs[key] as T? ?? defaultValue;
  }

  /// Define uma preferência específica
  Future<bool> setPreferencia(String key, dynamic value) async {
    final prefs = Map<String, dynamic>.from(preferencias);
    prefs[key] = value;
    await updatePreferencias(prefs);
    return true;
  }

  /// Verifica se o usuário tem uma preferência específica
  bool hasPreferencia(String key) {
    return preferencias.containsKey(key);
  }

  // Métodos privados
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _lastError = error;
    debugPrint('ProfileService Error: $error');
    notifyListeners();
  }

  void _clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Anuncia informações do perfil com TTS
  Future<void> announceProfileInfo() async {
    if (_currentProfile == null) {
      await AccessibilityService.speak('Nenhum perfil carregado.');
      return;
    }

    final profile = _currentProfile!;
    final message = '''
      Informações do perfil:
      Nome: ${profile.nome}
      ${profile.telefone != null ? 'Telefone: ${profile.telefone}' : ''}
      Perfil criado em: ${_formatDate(profile.createdAt)}
    ''';

    await AccessibilityService.speak(message.trim());
  }

  /// Formata data para leitura em voz
  String _formatDate(DateTime date) {
    final day = date.day;
    final month = date.month;
    final year = date.year;

    final monthNames = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro'
    ];

    return '$day de ${monthNames[month - 1]} de $year';
  }
}

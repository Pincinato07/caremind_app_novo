import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/perfil.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  // Getter público para acessar o cliente
  static SupabaseClient get client => _client;

  // Authentication methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String nome,
    required String tipo,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'nome_completo': nome,
        'tipo_conta': tipo,
      },
    );

    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Geração de código de vinculação
  static Future<String> gerarCodigoVinculacao() async {
    try {
      final response = await _client.rpc('gerar_codigo_vinculacao');
      return response as String;
    } catch (e) {
      throw Exception('Erro ao gerar código de vinculação: $e');
    }
  }

  // Vincular por código
  static Future<Map<String, dynamic>> vincularPorCodigo(String codigo) async {
    try {
      final response = await _client.rpc(
        'vincular_por_codigo',
        params: {'codigo_input': codigo},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Erro ao vincular conta: $e');
    }
  }

  // Criar e vincular idoso diretamente
  static Future<Map<String, dynamic>> criarEVincularIdoso({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      final response = await _client.rpc('criar_e_vincular_idoso', params: {
        'nome_idoso': nome,
        'email_idoso': email,
        'senha_idoso': senha,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Erro ao criar e vincular idoso: $e');
    }
  }

  // Profile methods
  static Future<void> createProfile({
    required String userId,
    required String nome,
    required String tipo,
  }) async {
    await _client.from('perfis').insert({
      'id': userId,
      'nome': nome,
      'tipo': tipo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Perfil?> getProfile(String userId) async {
    final response = await _client
        .from('perfis')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response != null) {
      return Perfil.fromMap(response);
    }
    return null;
  }

  static Future<void> updateProfile({
    required String userId,
    String? nome,
    String? tipo,
    String? codigoVinculacao,
    String? fotoUsuario,
    DateTime? codigoVinculacaoExpiraEm,
  }) async {
    final Map<String, dynamic> updates = {};
    
    if (nome != null) updates['nome'] = nome;
    if (tipo != null) updates['tipo'] = tipo;
    if (codigoVinculacao != null) updates['codigo_vinculacao'] = codigoVinculacao;
    if (fotoUsuario != null) updates['foto_usuario'] = fotoUsuario;
    if (codigoVinculacaoExpiraEm != null) {
      updates['codigo_vinculacao_expira_em'] = codigoVinculacaoExpiraEm.toIso8601String();
    }

    if (updates.isNotEmpty) {
      await _client.from('perfis').update(updates).eq('id', userId);
    }
  }
}

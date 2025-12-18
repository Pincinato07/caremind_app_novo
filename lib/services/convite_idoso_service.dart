import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/error_handler.dart';

/// Resultado do processamento de um convite
class ConviteResultado {
  final bool sucesso;
  final String? idIdoso;
  final String? nomeIdoso;
  final String? emailIdoso;
  final String? mensagem;
  final String? erro;

  ConviteResultado({
    required this.sucesso,
    this.idIdoso,
    this.nomeIdoso,
    this.emailIdoso,
    this.mensagem,
    this.erro,
  });

  factory ConviteResultado.sucesso({
    required String idIdoso,
    required String nomeIdoso,
    String? emailIdoso,
    String? mensagem,
  }) {
    return ConviteResultado(
      sucesso: true,
      idIdoso: idIdoso,
      nomeIdoso: nomeIdoso,
      emailIdoso: emailIdoso,
      mensagem: mensagem ?? 'Convite processado com sucesso!',
    );
  }

  factory ConviteResultado.erro(String erro) {
    return ConviteResultado(
      sucesso: false,
      erro: erro,
    );
  }
}

/// Serviço para processar convites de login para idosos
class ConviteIdosoService {
  final SupabaseClient _client;

  ConviteIdosoService(this._client);

  /// Valida um convite pelo token ou código
  Future<ConviteResultado> validarConvite(String tokenOuCodigo) async {
    try {
      // Determinar se é token (UUID) ou código (alfanumérico)
      final isToken = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(tokenOuCodigo);

      // Buscar convite
      var query = _client
          .from('convites_idosos')
          .select('''
            id,
            id_idoso,
            codigo_convite,
            token,
            expira_em,
            usado,
            perfis!convites_idosos_id_idoso_fkey (
              nome,
              user_id
            )
          ''');

      if (isToken) {
        query = query.eq('token', tokenOuCodigo);
      } else {
        query = query.eq('codigo_convite', tokenOuCodigo.toUpperCase());
      }

      final response = await query.maybeSingle();

      if (response == null) {
        return ConviteResultado.erro('Convite não encontrado.');
      }

      // Verificar se já foi usado
      if (response['usado'] == true) {
        return ConviteResultado.erro('Este convite já foi utilizado.');
      }

      // Verificar se está expirado
      final expiraEm = DateTime.parse(response['expira_em']);
      final agora = DateTime.now();
      if (agora.isAfter(expiraEm)) {
        return ConviteResultado.erro('Este convite expirou.');
      }

      // Extrair dados do perfil
      final perfil = response['perfis'];
      final nomeIdoso = perfil?['nome'] ?? 'Idoso';
      final user_id = perfil?['user_id'];

      if (user_id == null) {
        return ConviteResultado.erro('Perfil do idoso não encontrado.');
      }

      // Buscar email do usuário
      final authUserResponse = await _client.auth.admin.getUserById(user_id);
      final emailIdoso = authUserResponse.user?.email;

      return ConviteResultado.sucesso(
        idIdoso: response['id_idoso'],
        nomeIdoso: nomeIdoso,
        emailIdoso: emailIdoso,
        mensagem: 'Convite válido! Você pode fazer login agora.',
      );
    } catch (error) {
      debugPrint('Erro ao validar convite: $error');
      return ConviteResultado.erro(
        ErrorHandler.toAppException(error).message,
      );
    }
  }

  /// Marca um convite como usado após o login bem-sucedido
  Future<void> marcarConviteComoUsado(String tokenOuCodigo, String userId) async {
    try {
      final isToken = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(tokenOuCodigo);

      if (isToken) {
        await _client
            .from('convites_idosos')
            .update({
              'usado': true,
              'usado_em': DateTime.now().toIso8601String(),
              'usado_por': userId,
            })
            .eq('token', tokenOuCodigo);
      } else {
        await _client
            .from('convites_idosos')
            .update({
              'usado': true,
              'usado_em': DateTime.now().toIso8601String(),
              'usado_por': userId,
            })
            .eq('codigo_convite', tokenOuCodigo.toUpperCase());
      }
    } catch (error) {
      debugPrint('Erro ao marcar convite como usado: $error');
      // Não lançar erro - é apenas uma atualização de status
    }
  }

  /// Processa um convite completo: valida e retorna dados para login
  Future<ConviteResultado> processarConvite(String tokenOuCodigo) async {
    final resultado = await validarConvite(tokenOuCodigo);
    return resultado;
  }
}


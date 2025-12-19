import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'supabase_service.dart';

/// Serviço para exportação de dados (LGPD)
class ExportacaoService {
  final SupabaseService _supabaseService;

  ExportacaoService(this._supabaseService);

  /// Exportar dados da organização em formato JSON
  Future<String> exportarJSON(String organizacaoId) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        throw Exception('Token de acesso não encontrado');
      }

      // Obter URL do Supabase do .env
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      if (supabaseUrl == null || supabaseUrl.isEmpty) {
        throw Exception('SUPABASE_URL não configurado');
      }
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/exportar-dados-organizacao'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'organizacao_id': organizacaoId,
          'formato': 'json',
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? 'Erro ao exportar dados');
      }

      // Retornar JSON formatado
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      throw Exception('Erro ao exportar JSON: $e');
    }
  }

  /// Exportar dados da organização em formato CSV
  Future<String> exportarCSV(String organizacaoId) async {
    try {
      final user = _supabaseService.currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        throw Exception('Token de acesso não encontrado');
      }

      // Obter URL do Supabase do .env
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      if (supabaseUrl == null || supabaseUrl.isEmpty) {
        throw Exception('SUPABASE_URL não configurado');
      }
      final response = await http.post(
        Uri.parse('$supabaseUrl/functions/v1/exportar-dados-organizacao'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'organizacao_id': organizacaoId,
          'formato': 'csv',
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        throw Exception(error?['error'] ?? 'Erro ao exportar dados');
      }

      // Retornar CSV como string
      return utf8.decode(response.bodyBytes);
    } catch (e) {
      throw Exception('Erro ao exportar CSV: $e');
    }
  }

  /// Salvar arquivo (usar com file_picker ou path_provider)
  Future<void> salvarArquivo(String conteudo, String nomeArquivo) async {
    // Implementação depende de file_picker ou path_provider
    // Por enquanto, apenas retorna o conteúdo para o usuário salvar manualmente
    throw UnimplementedError(
        'Use file_picker ou path_provider para salvar o arquivo');
  }
}

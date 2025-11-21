import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';

/// Serviço para gerenciar o fluxo completo de OCR
/// Upload → Registro → Polling → Processamento
class OcrService {
  final SupabaseClient _client;

  OcrService(this._client);

  /// Faz upload da imagem e registra no banco para processamento OCR
  ///
  /// [imageFile] - Arquivo de imagem selecionado
  /// [userId] - ID do usuário/idoso para associar os medicamentos
  ///
  /// Retorna o ID do registro em ocr_gerenciamento para polling
  Future<String> uploadImageAndRegister({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // 1. Fazer upload da imagem para Supabase Storage
      debugPrint('📤 Fazendo upload da imagem...');
      
      final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      
      // Ler bytes do arquivo
      final imageBytes = await imageFile.readAsBytes();
      
      // Fazer upload para Supabase Storage usando uploadBinary
      await _client.storage
          .from('receitas-medicas')
          .uploadBinary(fileName, imageBytes);

      debugPrint('✅ Upload concluído: $fileName');

      // 2. Obter URL pública da imagem
      final publicUrl = _client.storage
          .from('receitas-medicas')
          .getPublicUrl(fileName);

      debugPrint('🔗 URL pública gerada: $publicUrl');

      // 3. Registrar no banco (ocr_gerenciamento) com status PENDENTE
      debugPrint('📝 Registrando processamento OCR...');
      
      final insertResponse = await _client
          .from('ocr_gerenciamento')
          .insert({
            'user_id': userId,
            'image_url': publicUrl,
            'status': 'PENDENTE',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      final ocrId = insertResponse['id'] as String;
      debugPrint('✅ Registro criado com ID: $ocrId');

      return ocrId;
    } catch (error) {
      debugPrint('❌ Erro no upload/registro: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  /// Verifica o status de processamento OCR
  ///
  /// [ocrId] - ID do registro em ocr_gerenciamento
  ///
  /// Retorna o status atual e mensagem de erro (se houver)
  Future<Map<String, dynamic>> checkStatus(String ocrId) async {
    try {
      final response = await _client
          .from('ocr_gerenciamento')
          .select('status, error_message, medicamentos_count, result_json')
          .eq('id', ocrId)
          .single();

      return {
        'status': response['status'] as String? ?? 'PENDENTE',
        'error_message': response['error_message'] as String?,
        'medicamentos_count': response['medicamentos_count'] as int? ?? 0,
        'result_json': response['result_json'],
      };
    } catch (error) {
      debugPrint('❌ Erro ao verificar status: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  /// Faz polling do status até processamento concluir ou erro
  ///
  /// [ocrId] - ID do registro em ocr_gerenciamento
  /// [onStatusUpdate] - Callback chamado quando o status muda
  /// [timeout] - Timeout em segundos (padrão: 10 minutos)
  /// [interval] - Intervalo entre verificações em segundos (padrão: 5 segundos)
  ///
  /// Retorna o status final e informações do processamento
  Future<Map<String, dynamic>> pollStatus({
    required String ocrId,
    Function(String status)? onStatusUpdate,
    int timeout = 600, // 10 minutos
    int interval = 5, // 5 segundos
  }) async {
    final startTime = DateTime.now();
    
    while (true) {
      // Verificar timeout
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      if (elapsed >= timeout) {
        throw UnknownException(message: 'Tempo esgotado aguardando processamento da receita.');
      }

      // Verificar status
      final statusData = await checkStatus(ocrId);
      final status = statusData['status'] as String;

      // Notificar atualização de status
      onStatusUpdate?.call(status);

      // Status de sucesso
      if (status == 'PROCESSADO' || status == 'PROCESSADO_PARCIALMENTE') {
        debugPrint('✅ Processamento concluído: $status');
        return {
          'status': status,
          'success': true,
          'medicamentos_count': statusData['medicamentos_count'] as int? ?? 0,
          'error_message': statusData['error_message'],
        };
      }

      // Status de erro
      if (status == 'ERRO_PROCESSAMENTO' || status == 'ERRO_DATABASE') {
        final errorMsg = statusData['error_message'] as String? ?? 
            'Não foi possível encontrar medicamento na receita.';
        debugPrint('❌ Erro no processamento: $errorMsg');
        return {
          'status': status,
          'success': false,
          'error_message': errorMsg,
        };
      }

      // Status ainda pendente - aguardar e verificar novamente
      if (status == 'PENDENTE' || status == 'CONCLUIDO') {
        await Future.delayed(Duration(seconds: interval));
        continue;
      }

      // Status desconhecido - aguardar e verificar novamente
      await Future.delayed(Duration(seconds: interval));
    }
  }
}


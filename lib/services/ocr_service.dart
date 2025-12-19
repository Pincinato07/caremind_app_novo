import 'dart:io';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../core/errors/error_handler.dart';
import '../models/ocr_medicamento.dart';
import '../models/medicamento.dart';

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
      // 0. Validar se o perfil existe antes de criar o job
      debugPrint('🔍 Validando perfil para userId: $userId');
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (perfilResponse == null) {
        debugPrint('❌ Perfil não encontrado para userId: $userId');
        throw ValidationException(
          message:
              'Perfil não encontrado. Verifique se o usuário possui um perfil cadastrado.',
          code: 'PERFIL_NAO_ENCONTRADO',
        );
      }

      debugPrint('✅ Perfil validado: ${perfilResponse['id']}');

      // 1. Fazer upload da imagem para Supabase Storage
      debugPrint('📤 Fazendo upload da imagem...');

      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';

      // Ler bytes do arquivo
      final imageBytes = await imageFile.readAsBytes();

      // Fazer upload para Supabase Storage usando uploadBinary
      await _client.storage
          .from('receitas-medicas')
          .uploadBinary(fileName, imageBytes);

      debugPrint('✅ Upload concluído: $fileName');

      // 2. Obter URL pública da imagem
      final publicUrl =
          _client.storage.from('receitas-medicas').getPublicUrl(fileName);

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

      final ocrId = insertResponse['id'].toString();
      debugPrint('✅ Registro criado com ID: $ocrId');

      return ocrId;
    } catch (error) {
      debugPrint('❌ Erro no upload/registro: ${error.toString()}');
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
          .select('status, result_json')
          .eq('id', ocrId)
          .single();

      return {
        'status': response['status'] as String? ?? 'PENDENTE',
        'result_json': response['result_json'],
      };
    } catch (error) {
      debugPrint('❌ Erro ao verificar status: ${error.toString()}');
      throw ErrorHandler.toAppException(error);
    }
  }

  /// Faz polling do status até processamento concluir ou erro
  ///
  /// [ocrId] - ID do registro em ocr_gerenciamento
  /// [onStatusUpdate] - Callback chamado quando o status muda
  /// [onProgress] - Callback para atualizar progresso (0.0 a 1.0)
  /// [timeout] - Timeout em segundos (padrão: 5 minutos)
  /// [interval] - Intervalo entre verificações em segundos (padrão: 3 segundos)
  ///
  /// Retorna o status final e informações do processamento
  Future<Map<String, dynamic>> pollStatus({
    required String ocrId,
    Function(String status)? onStatusUpdate,
    Function(double progress)? onProgress,
    int timeout = 300, // 5 minutos
    int interval = 3, // 3 segundos
  }) async {
    final startTime = DateTime.now();
    int pollCount = 0;
    final maxPolls = timeout ~/ interval;

    while (true) {
      pollCount++;

      // Atualizar progresso baseado no tempo decorrido
      final progress = (pollCount / maxPolls).clamp(0.0, 0.95);
      onProgress?.call(progress);

      // Verificar timeout
      final elapsed = DateTime.now().difference(startTime).inSeconds;
      if (elapsed >= timeout) {
        throw UnknownException(
            message: 'Tempo esgotado aguardando processamento da receita.');
      }

      // Verificar status
      final statusData = await checkStatus(ocrId);
      final status = statusData['status'] as String;

      // Notificar atualização de status
      onStatusUpdate?.call(status);

      // Status de sucesso - aguardando validação do usuário
      if (status == 'AGUARDANDO-VALIDACAO') {
        debugPrint('✅ Processamento concluído, aguardando validação');
        onProgress?.call(1.0);
        return {
          'status': status,
          'success': true,
          'result_json': statusData['result_json'],
        };
      }

      // Status de erro
      if (status == 'ERRO_PROCESSAMENTO' ||
          status == 'ERRO_DATABASE' ||
          status == 'ERRO') {
        debugPrint('❌ Erro no processamento OCR');
        return {
          'status': status,
          'success': false,
          'error_message':
              'Não foi possível processar a receita. Tente novamente.',
        };
      }

      // Status ainda pendente - aguardar e verificar novamente
      if (status == 'PENDENTE' || status == 'PROCESSANDO') {
        await Future.delayed(Duration(seconds: interval));
        continue;
      }

      // Status desconhecido - aguardar e verificar novamente
      await Future.delayed(Duration(seconds: interval));
    }
  }

  /// Extrai lista de medicamentos do result_json
  List<OcrMedicamento> parseMedicamentosFromResult(dynamic resultJson) {
    if (resultJson == null) return [];

    try {
      List<dynamic> medicamentosList;

      if (resultJson is List) {
        medicamentosList = resultJson;
      } else if (resultJson is Map) {
        // Pode vir como { medicamentos: [...] } ou { medications: [...] }
        medicamentosList = resultJson['medicamentos'] as List? ??
            resultJson['medications'] as List? ??
            resultJson['items'] as List? ??
            [];
      } else {
        return [];
      }

      return medicamentosList
          .map((item) => OcrMedicamento.fromJson(item as Map<String, dynamic>))
          .where((med) => med.nome.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('❌ Erro ao parsear medicamentos: $e');
      return [];
    }
  }

  /// Salva os medicamentos validados na tabela medicamentos
  Future<List<Medicamento>> salvarMedicamentosValidados({
    required List<OcrMedicamento> medicamentos,
    required String perfilId,
    required String userId,
  }) async {
    final List<Medicamento> salvos = [];

    for (final ocrMed in medicamentos) {
      try {
        final data = {
          'nome': ocrMed.nome,
          'dosagem': ocrMed.dosagem,
          'frequencia': ocrMed.toFrequenciaJson(),
          'quantidade': ocrMed.quantidade,
          'via': ocrMed.via ?? 'oral',
          'perfil_id': perfilId,
          'created_at': DateTime.now().toIso8601String(),
        };

        final response =
            await _client.from('medicamentos').insert(data).select().single();

        salvos.add(Medicamento.fromMap(response));
        debugPrint('✅ Medicamento salvo: ${ocrMed.nome}');
      } catch (e) {
        debugPrint('❌ Erro ao salvar medicamento ${ocrMed.nome}: $e');
      }
    }

    return salvos;
  }

  /// Atualiza o status do OCR para VALIDADO após salvar
  Future<void> marcarComoValidado(String ocrId) async {
    try {
      await _client
          .from('ocr_gerenciamento')
          .update({'status': 'VALIDADO'}).eq('id', ocrId);
    } catch (e) {
      debugPrint('❌ Erro ao marcar OCR como validado: $e');
    }
  }
}

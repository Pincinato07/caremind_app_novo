import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'offline_cache_service.dart';
import 'ocr_service.dart';
import 'supabase_service.dart';
import 'package:get_it/get_it.dart';

/// Serviço para gerenciar imagens OCR offline
///
/// **Funcionalidades:**
/// - Salva imagens localmente quando offline
/// - Processa automaticamente quando volta online
/// - Gerencia fila de imagens pendentes
class OcrOfflineService {
  static const String _pendingImagesDir = 'pending_ocr_images';
  static final Uuid _uuid = const Uuid();

  /// Salvar imagem localmente para processar depois (quando offline)
  ///
  /// [imageFile] - Arquivo de imagem capturado
  /// [userId] - ID do usuário/idoso
  ///
  /// Retorna o ID da ação pendente
  static Future<String> saveImageForLater({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // 1. Obter diretório de documentos do app
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/$_pendingImagesDir');

      // 2. Criar diretório se não existir
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
        debugPrint('📁 Diretório de imagens OCR criado: ${imagesDir.path}');
      }

      // 3. Gerar ID único para esta ação
      final actionId = _uuid.v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 4. Copiar imagem para diretório local com nome único
      final fileName = '${userId}_${timestamp}_$actionId.jpg';
      final localPath = '${imagesDir.path}/$fileName';
      await imageFile.copy(localPath);

      debugPrint('💾 Imagem salva localmente: $localPath');

      // 5. Salvar metadados na fila Hive
      await OfflineCacheService.addPendingAction({
        'action_id': actionId,
        'type': 'ocr_upload',
        'image_path': localPath,
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'synced': false,
        'retry_count': 0,
      });

      debugPrint('✅ Imagem adicionada à fila de processamento offline');
      return actionId;
    } catch (e) {
      debugPrint('❌ Erro ao salvar imagem offline: $e');
      rethrow;
    }
  }

  /// Processar todas as imagens pendentes (chamado quando volta online)
  ///
  /// Retorna número de imagens processadas com sucesso
  static Future<int> processPendingImages() async {
    try {
      final pending = await OfflineCacheService.getPendingActions();
      final ocrActions = pending
          .where((a) =>
              a['type'] == 'ocr_upload' &&
              (a['synced'] == false || a['synced'] == null))
          .toList();

      if (ocrActions.isEmpty) {
        debugPrint('✅ Nenhuma imagem OCR pendente');
        return 0;
      }

      debugPrint(
          '🔄 Processando ${ocrActions.length} imagens OCR pendentes...');

      final supabaseService = GetIt.I<SupabaseService>();
      final ocrService = OcrService(supabaseService.client);

      int processed = 0;
      int failed = 0;
      final List<Map<String, dynamic>> toUpdate = [];

      for (final action in ocrActions) {
        try {
          final imagePath = action['image_path'] as String;
          final userId = action['user_id'] as String;
          final actionId = action['action_id'] as String;

          // Verificar se arquivo ainda existe
          final imageFile = File(imagePath);
          if (!await imageFile.exists()) {
            debugPrint('⚠️ Arquivo não encontrado: $imagePath');
            // Marcar como processada para remover da fila
            toUpdate.add({
              ...action,
              'synced': true,
              'synced_at': DateTime.now().toIso8601String(),
              'error': 'Arquivo não encontrado',
            });
            continue;
          }

          // Tentar fazer upload
          debugPrint('📤 Fazendo upload de: $imagePath');
          final ocrId = await ocrService.uploadImageAndRegister(
            imageFile: imageFile,
            userId: userId,
          );

          // Marcar como processada
          toUpdate.add({
            ...action,
            'synced': true,
            'synced_at': DateTime.now().toIso8601String(),
            'ocr_id': ocrId,
          });

          // Deletar imagem local após sucesso
          try {
            await imageFile.delete();
            debugPrint('🗑️ Imagem local deletada após upload: $imagePath');
          } catch (e) {
            debugPrint('⚠️ Erro ao deletar imagem local: $e');
          }

          processed++;
          debugPrint('✅ Imagem processada: $actionId -> OCR ID: $ocrId');
        } catch (e) {
          failed++;
          final actionId = action['action_id'] as String;
          final retryCount = (action['retry_count'] as int?) ?? 0;

          debugPrint('❌ Erro ao processar imagem $actionId: $e');

          // Se exceder 3 tentativas, marcar como falha permanente
          if (retryCount >= 3) {
            debugPrint('⚠️ Máximo de tentativas excedido para $actionId');
            toUpdate.add({
              ...action,
              'synced': true, // Marcar como "processada" para remover da fila
              'synced_at': DateTime.now().toIso8601String(),
              'error': 'Máximo de tentativas excedido',
              'failed': true,
            });
          } else {
            // Incrementar contador de tentativas
            toUpdate.add({
              ...action,
              'retry_count': retryCount + 1,
              'last_error': e.toString(),
            });
          }
        }
      }

      // Atualizar ações no cache
      await _updatePendingActions(ocrActions, toUpdate);

      debugPrint(
          '✅ Processamento concluído: $processed sucessos, $failed falhas');
      return processed;
    } catch (e) {
      debugPrint('❌ Erro ao processar imagens pendentes: $e');
      return 0;
    }
  }

  /// Atualizar ações pendentes no cache
  static Future<void> _updatePendingActions(
    List<Map<String, dynamic>> originalActions,
    List<Map<String, dynamic>> updatedActions,
  ) async {
    try {
      final allPending = await OfflineCacheService.getPendingActions();

      // Criar mapa de ações atualizadas por action_id
      final updatedMap = <String, Map<String, dynamic>>{};
      for (final updated in updatedActions) {
        final actionId = updated['action_id'] as String?;
        if (actionId != null) {
          updatedMap[actionId] = updated;
        }
      }

      // Atualizar ações na lista completa
      final updatedList = allPending.map((action) {
        final actionId = action['action_id'] as String?;
        if (actionId != null && updatedMap.containsKey(actionId)) {
          return updatedMap[actionId]!;
        }
        return action;
      }).toList();

      // Remover ações marcadas como sincronizadas (mas manter as que falharam permanentemente)
      final filteredList = updatedList
          .where((a) =>
              a['synced'] != true ||
              (a['failed'] == true && a['synced'] == true))
          .toList();

      // Salvar lista atualizada
      await OfflineCacheService.replacePendingActions(filteredList);
    } catch (e) {
      debugPrint('❌ Erro ao atualizar ações pendentes: $e');
    }
  }

  /// Obter número de imagens pendentes
  static Future<int> getPendingImagesCount() async {
    try {
      final pending = await OfflineCacheService.getPendingActions();
      return pending
          .where((a) =>
              a['type'] == 'ocr_upload' &&
              (a['synced'] == false || a['synced'] == null))
          .length;
    } catch (e) {
      return 0;
    }
  }

  /// Limpar imagens antigas do diretório local
  static Future<void> cleanupOldImages(
      {Duration maxAge = const Duration(days: 7)}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/$_pendingImagesDir');

      if (!await imagesDir.exists()) return;

      final now = DateTime.now();
      int deleted = 0;

      await for (final entity in imagesDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);

          if (age > maxAge) {
            await entity.delete();
            deleted++;
          }
        }
      }

      if (deleted > 0) {
        debugPrint('🧹 Limpeza: $deleted imagens antigas removidas');
      }
    } catch (e) {
      debugPrint('❌ Erro ao limpar imagens antigas: $e');
    }
  }
}

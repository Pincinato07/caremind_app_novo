import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicamento.dart';
import '../core/errors/error_handler.dart';
import '../core/errors/result.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/data_cleaner.dart';
import 'notification_service.dart';
import 'historico_eventos_service.dart';
import '../models/notificacao_organizacao.dart';
import 'organizacao_validator.dart';
import '../core/injection/injection.dart';

class MedicamentoService {
  final SupabaseClient _client;
  final OrganizacaoValidator _orgValidator = OrganizacaoValidator();

  MedicamentoService(this._client);

  // Buscar todos os medicamentos de um usuário
  Future<Result<List<Medicamento>>> getMedicamentos(String userId) async {
    try {
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      final perfilId = perfilResponse?['id'] as String?;

      final response = await _client
          .from('medicamentos')
          .select()
          .or(perfilId != null
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId')
          .order('created_at', ascending: false);

      final medicamentos =
          (response as List).map((item) => Medicamento.fromMap(item)).toList();

      return Success(medicamentos);
    } on SocketException catch (e) {
      return Failure(NetworkException(
        message: 'Erro de conexão',
        originalError: e,
      ));
    } catch (error) {
      return Failure(ErrorHandler.toAppException(error));
    }
  }

  // Adicionar um novo medicamento
  Future<Medicamento> addMedicamento(Medicamento medicamento) async {
    try {
      // Validação básica
      if (medicamento.nome.trim().isEmpty) {
        throw Exception('Nome do medicamento é obrigatório');
      }

      final data = medicamento.toMap();
      data.remove('id'); // Remove o ID para inserção

      // Garantir que perfil_id ou user_id estejam presentes
      String? perfilIdFinal;
      if (data['perfil_id'] == null) {
        if (medicamento.userId != null && medicamento.userId!.isNotEmpty) {
          final perfilResponse = await _client
              .from('perfis')
              .select('id')
              .eq('user_id', medicamento.userId!)
              .maybeSingle();

          if (perfilResponse != null) {
            perfilIdFinal = perfilResponse['id'] as String;
            data['perfil_id'] = perfilIdFinal;
          } else {
            // Se não encontrou perfil, usar user_id como fallback
            // (compatibilidade durante transição, mas idealmente deveria existir perfil)
            perfilIdFinal = medicamento.userId!;
            data['perfil_id'] = perfilIdFinal;
          }
        } else {
          throw Exception('perfil_id é obrigatório');
        }
      } else {
        perfilIdFinal = data['perfil_id'] as String?;
      }

      // VALIDAÇÃO: Se perfil_id pertence a organização, verificar acesso
      if (perfilIdFinal != null) {
        final podeAcessar = await _orgValidator.podeAcessarIdoso(perfilIdFinal);
        if (!podeAcessar) {
          throw Exception('Acesso negado: você não tem permissão para adicionar medicamentos a este idoso');
        }
      }

      // Garantir que created_at esteja presente
      if (data['created_at'] == null) {
        data['created_at'] = DateTime.now().toIso8601String();
      }

      // Limpar dados antes de inserir (remove strings vazias, mas mantém campos obrigatórios)
      final cleanedData = DataCleaner.cleanData(
        data,
        fieldsToKeepEmpty: ['perfil_id'],
      );

      // Garantir que pelo menos perfil_id ou user_id estejam presentes após limpeza
      if (cleanedData['perfil_id'] == null) {
        throw Exception('É necessário perfil_id para criar medicamento');
      }

      debugPrint('📤 MedicamentoService: Dados para inserção: $cleanedData');

      final response = await _client
          .from('medicamentos')
          .insert(cleanedData)
          .select()
          .single();

      final medicamentoSalvo = Medicamento.fromMap(response);

      // Agendar notificações automaticamente após criar medicamento
      try {
        await NotificationService.scheduleMedicationReminders(medicamentoSalvo);
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        print('⚠️ Erro ao agendar notificações: $e');
      }

      return medicamentoSalvo;
    } catch (error) {
      debugPrint(
          '❌ MedicamentoService: Erro ao adicionar medicamento: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ MedicamentoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar um medicamento existente
  Future<Medicamento> updateMedicamento(
    int medicamentoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Buscar medicamento atual para validar acesso
      final medicamentoAtual = await getMedicamentoPorId(medicamentoId);
      if (medicamentoAtual == null) {
        throw Exception('Medicamento não encontrado');
      }

      // VALIDAÇÃO: Verificar se usuário pode acessar este idoso
      final podeAcessar = await _orgValidator.podeAcessarIdoso(medicamentoAtual.perfilId);
      if (!podeAcessar) {
        throw Exception('Acesso negado: você não tem permissão para atualizar medicamentos deste idoso');
      }

      // Limpar dados antes de atualizar (remove strings vazias, mas mantém campos importantes)
      final cleanedUpdates = DataCleaner.cleanData(
        updates,
        fieldsToKeepEmpty: ['perfil_id'],
      );

      debugPrint(
          '📤 MedicamentoService: Dados para atualização: $cleanedUpdates');

      final response = await _client
          .from('medicamentos')
          .update(cleanedUpdates)
          .eq('id', medicamentoId)
          .select()
          .single();

      final medicamentoAtualizado = Medicamento.fromMap(response);

      // Cancelar notificações antigas e agendar novas com frequência atualizada
      try {
        await NotificationService.cancelMedicamentoNotifications(medicamentoId);
        await NotificationService.scheduleMedicationReminders(
            medicamentoAtualizado);
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        print('⚠️ Erro ao atualizar notificações: $e');
      }

      return medicamentoAtualizado;
    } catch (error) {
      debugPrint(
          '❌ MedicamentoService: Erro ao atualizar medicamento: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ MedicamentoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Deletar um medicamento
  Future<void> deleteMedicamento(int medicamentoId) async {
    try {
      // Cancelar notificações antes de deletar
      try {
        await NotificationService.cancelMedicamentoNotifications(medicamentoId);
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        print('⚠️ Erro ao cancelar notificações: $e');
      }

      await _client.from('medicamentos').delete().eq('id', medicamentoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Marcar medicamento como concluído/não concluído via historico_eventos
  // CORRIGIDO: Usa RPC atômica para evitar race conditions
  Future<void> toggleConcluido(
    int medicamentoId,
    bool concluido,
    DateTime dataPrevista,
  ) async {
    try {
      // Buscar medicamento atual para obter perfil_id
      final medicamentoAtual = await getMedicamentoPorId(medicamentoId);
      if (medicamentoAtual == null) {
        throw Exception('Medicamento não encontrado');
      }

      final perfilId = medicamentoAtual.perfilId;

      // VALIDAÇÃO: Verificar se usuário pode acessar este idoso (individual ou organização)
      final podeAcessar = await _orgValidator.podeAcessarIdoso(perfilId);
      if (!podeAcessar) {
        throw Exception('Acesso negado: você não tem permissão para gerenciar medicamentos deste idoso');
      }

      // Usar RPC atômica que faz tudo de uma vez (cria/atualiza evento, decrementa quantidade, verifica estoque baixo)
      if (concluido) {
        final response = await _client.rpc(
          'marcar_medicamento_tomado_atomico',
          params: {
            'p_medicamento_id': medicamentoId,
            'p_perfil_id': perfilId,
            'p_data_prevista': dataPrevista.toIso8601String(),
          },
        );

        final result = response as Map<String, dynamic>;
        final estoqueBaixo = result['estoque_baixo'] as bool? ?? false;

        if (estoqueBaixo) {
          debugPrint('⚠️ Estoque baixo detectado para medicamento $medicamentoId');
        }

        debugPrint(
            '✅ MedicamentoService: Medicamento $medicamentoId marcado como confirmado (atômico)');
      } else {
        // Desmarcar (marcar como pendente)
        await _client.rpc(
          'desmarcar_medicamento_tomado_atomico',
          params: {
            'p_medicamento_id': medicamentoId,
            'p_perfil_id': perfilId,
            'p_data_prevista': dataPrevista.toIso8601String(),
          },
        );

        debugPrint(
            '✅ MedicamentoService: Medicamento $medicamentoId marcado como pendente (atômico)');
      }
    } catch (error) {
      debugPrint(
          '❌ MedicamentoService: Erro ao marcar medicamento como concluído: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ MedicamentoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar medicamento por ID
  Future<Medicamento?> getMedicamentoPorId(int medicamentoId) async {
    try {
      final response = await _client
          .from('medicamentos')
          .select()
          .eq('id', medicamentoId)
          .maybeSingle();

      if (response != null) {
        return Medicamento.fromMap(response);
      }
      return null;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}

      }

      debugPrint(
          '✅ MedicamentoService: Medicamento $medicamentoId marcado como $novoStatus');
    } catch (error) {
      debugPrint(
          '❌ MedicamentoService: Erro ao marcar medicamento como concluído: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint(
            '❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
        if (error.details != null) {
          debugPrint('❌ MedicamentoService: Detalhes: ${error.details}');
        }
      }
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar medicamento por ID
  Future<Medicamento?> getMedicamentoPorId(int medicamentoId) async {
    try {
      final response = await _client
          .from('medicamentos')
          .select()
          .eq('id', medicamentoId)
          .maybeSingle();

      if (response != null) {
        return Medicamento.fromMap(response);
      }
      return null;
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }
}

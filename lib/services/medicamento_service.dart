import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicamento.dart';
import '../core/errors/error_handler.dart';
import '../core/utils/data_cleaner.dart';
import 'notification_service.dart';
import 'historico_eventos_service.dart';

class MedicamentoService {
  final SupabaseClient _client;

  MedicamentoService(this._client);

  // Buscar todos os medicamentos de um usuário
  // Atualizado para usar user_id (campo correto baseado no schema)
  Future<List<Medicamento>> getMedicamentos(String userId) async {
    try {
      // Baseado no schema, obter o perfil_id do usuário usando user_id
      final perfilResponse = await _client
          .from('perfis')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      final perfilId = perfilResponse?['id'] as String?;
      
      // Usar perfil_id se disponível, senão usar user_id (compatibilidade durante transição)
      final response = await _client
          .from('medicamentos')
          .select()
          .or(perfilId != null 
              ? 'perfil_id.eq.$perfilId'
              : 'perfil_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Medicamento.fromMap(item))
          .toList();
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Adicionar um novo medicamento
  Future<Medicamento> addMedicamento(Medicamento medicamento) async {
    try {
      final data = medicamento.toMap();
      data.remove('id'); // Remove o ID para inserção
      
      // Garantir que perfil_id ou user_id estejam presentes
      if (data['perfil_id'] == null) {
        if (medicamento.userId != null && medicamento.userId!.isNotEmpty) {
          final perfilResponse = await _client
              .from('perfis')
              .select('id')
              .eq('user_id', medicamento.userId!)
              .maybeSingle();
          
          if (perfilResponse != null) {
            data['perfil_id'] = perfilResponse['id'] as String;
          } else {
            // Se não encontrou perfil, garantir que user_id esteja presente
            if (data['perfil_id'] == null || (data['perfil_id'] as String).isEmpty) {
              data['perfil_id'] = medicamento.userId!;
            }
          }
        } else {
          throw Exception('perfil_id é obrigatório');
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
      debugPrint('❌ MedicamentoService: Erro ao adicionar medicamento: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
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
      // Limpar dados antes de atualizar (remove strings vazias, mas mantém campos importantes)
      final cleanedUpdates = DataCleaner.cleanData(
        updates,
        fieldsToKeepEmpty: ['perfil_id'],
      );
      
      debugPrint('📤 MedicamentoService: Dados para atualização: $cleanedUpdates');
      
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
        await NotificationService.scheduleMedicationReminders(medicamentoAtualizado);
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        print('⚠️ Erro ao atualizar notificações: $e');
      }

      return medicamentoAtualizado;
    } catch (error) {
      debugPrint('❌ MedicamentoService: Erro ao atualizar medicamento: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
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

      await _client
          .from('medicamentos')
          .delete()
          .eq('id', medicamentoId);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Marcar medicamento como concluído/não concluído via historico_eventos
  // Se marcar como concluído, decrementa quantidade e verifica estoque baixo
  Future<void> toggleConcluido(
    int medicamentoId,
    bool concluido,
    DateTime dataPrevista,
  ) async {
    try {
      // Buscar medicamento atual para verificar quantidade e perfil_id
      final medicamentoAtual = await getMedicamentoPorId(medicamentoId);
      if (medicamentoAtual == null) {
        throw Exception('Medicamento não encontrado');
      }

      final perfilId = medicamentoAtual.perfilId ?? medicamentoAtual.userId;
      if (perfilId == null) {
        throw Exception('perfil_id não encontrado para o medicamento');
      }

      // Buscar ou criar evento no historico_eventos
      final eventosResponse = await _client
          .from('historico_eventos')
          .select()
          .eq('medicamento_id', medicamentoId)
          .eq('data_prevista', dataPrevista.toIso8601String())
          .maybeSingle();

      final novoStatus = concluido ? 'concluido' : 'pendente';

      if (eventosResponse != null) {
        // Atualizar evento existente
        await _client
            .from('historico_eventos')
            .update({
              'status': novoStatus,
              'horario_programado': DateTime.now().toIso8601String(),
            })
            .eq('id', eventosResponse['id']);
      } else {
        // Criar novo evento
        await _client
            .from('historico_eventos')
            .insert({
              'perfil_id': perfilId,
              'tipo_evento': 'medicamento',
              'evento_id': medicamentoId,
              'medicamento_id': medicamentoId,
              'data_prevista': dataPrevista.toIso8601String(),
              'status': novoStatus,
              'horario_programado': DateTime.now().toIso8601String(),
              'titulo': medicamentoAtual.nome,
              'descricao': 'Dosagem: ${medicamentoAtual.dosagem}',
            });
      }
      
      // Se está marcando como tomado, decrementar quantidade
      if (concluido) {
        final novaQuantidade = medicamentoAtual.quantidade > 0 
            ? medicamentoAtual.quantidade - 1 
            : 0;
        
        await _client
            .from('medicamentos')
            .update({'quantidade': novaQuantidade})
            .eq('id', medicamentoId);

        // Verificar se estoque está baixo (<= 5 unidades)
        if (novaQuantidade <= 5 && novaQuantidade > 0) {
          try {
            await HistoricoEventosService.addEvento({
              'perfil_id': perfilId,
              'tipo_evento': 'estoque_baixo',
              'evento_id': medicamentoId,
              'data_prevista': DateTime.now().toIso8601String(),
              'status': 'pendente',
              'titulo': 'Estoque baixo',
              'descricao': 'Estoque de "${medicamentoAtual.nome}" está baixo ($novaQuantidade unidade(s) restante(s))',
              'medicamento_id': medicamentoId,
            });
          } catch (e) {
            // Log erro mas não interrompe o fluxo
            print('⚠️ Erro ao registrar alerta de estoque baixo: $e');
          }
        }
      }

      debugPrint('✅ MedicamentoService: Medicamento $medicamentoId marcado como $novoStatus');
    } catch (error) {
      debugPrint('❌ MedicamentoService: Erro ao marcar medicamento como concluído: ${error.toString()}');
      debugPrint('❌ MedicamentoService: Tipo do erro: ${error.runtimeType}');
      if (error is PostgrestException) {
        debugPrint('❌ MedicamentoService: Código: ${error.code ?? 'N/A'}, Mensagem: ${error.message}');
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

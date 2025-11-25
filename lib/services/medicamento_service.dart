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
  // Atualizado para usar perfil_id (com fallback para user_id durante transição)
  Future<List<Medicamento>> getMedicamentos(String userId) async {
    try {
      // Primeiro, obter o perfil_id do usuário
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
              ? 'perfil_id.eq.$perfilId,user_id.eq.$userId'
              : 'user_id.eq.$userId')
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
        if (medicamento.userId.isNotEmpty) {
          final perfilResponse = await _client
              .from('perfis')
              .select('id')
              .eq('user_id', medicamento.userId)
              .maybeSingle();
          
          if (perfilResponse != null) {
            data['perfil_id'] = perfilResponse['id'] as String;
          } else {
            // Se não encontrou perfil, garantir que user_id esteja presente
            if (data['user_id'] == null || (data['user_id'] as String).isEmpty) {
              data['user_id'] = medicamento.userId;
            }
          }
        } else {
          throw Exception('user_id é obrigatório quando perfil_id não está disponível');
        }
      }

      // Garantir que created_at esteja presente
      if (data['created_at'] == null) {
        data['created_at'] = DateTime.now().toIso8601String();
      }

      // Limpar dados antes de inserir (remove strings vazias, mas mantém campos obrigatórios)
      final cleanedData = DataCleaner.cleanData(
        data,
        fieldsToKeepEmpty: ['user_id', 'perfil_id'], // Manter mesmo se vazios durante transição
      );
      
      // Garantir que pelo menos perfil_id ou user_id estejam presentes após limpeza
      if (cleanedData['perfil_id'] == null && 
          (cleanedData['user_id'] == null || (cleanedData['user_id'] as String).isEmpty)) {
        throw Exception('É necessário perfil_id ou user_id para criar medicamento');
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
        fieldsToKeepEmpty: ['user_id', 'perfil_id'], // Manter mesmo se vazios durante transição
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

  // Marcar medicamento como concluído/não concluído
  // Se marcar como concluído, decrementa quantidade e verifica estoque baixo
  Future<Medicamento> toggleConcluido(
    int medicamentoId,
    bool concluido,
  ) async {
    try {
      // Buscar medicamento atual para verificar quantidade
      final medicamentoAtual = await getMedicamentoPorId(medicamentoId);
      if (medicamentoAtual == null) {
        throw Exception('Medicamento não encontrado');
      }

      Map<String, dynamic> updates = {'concluido': concluido};
      
      // Se está marcando como tomado, decrementar quantidade
      if (concluido && !medicamentoAtual.concluido) {
        final novaQuantidade = medicamentoAtual.quantidade > 0 
            ? medicamentoAtual.quantidade - 1 
            : 0;
        updates['quantidade'] = novaQuantidade;

        // Verificar se estoque está baixo (<= 5 unidades)
        if (novaQuantidade <= 5 && novaQuantidade > 0) {
          try {
            // Obter perfil_id do medicamento
            final perfilId = medicamentoAtual.perfilId ?? medicamentoAtual.userId;
            await HistoricoEventosService.addEvento({
              'perfil_id': perfilId,
              'tipo_evento': 'estoque_baixo',
              'data_hora': DateTime.now().toIso8601String(),
              'descricao': 'Estoque de "${medicamentoAtual.nome}" está baixo (${novaQuantidade} unidade(s) restante(s))',
              'referencia_id': medicamentoId.toString(),
              'tipo_referencia': 'medicamento',
            });
          } catch (e) {
            // Log erro mas não interrompe o fluxo
            print('⚠️ Erro ao registrar alerta de estoque baixo: $e');
          }
        }
      }

      // Limpar dados antes de atualizar (remove strings vazias)
      final cleanedUpdates = DataCleaner.cleanData(updates);
      
      debugPrint('📤 MedicamentoService: Marcando medicamento $medicamentoId como concluído: $concluido');
      debugPrint('📤 MedicamentoService: Dados para atualização: $cleanedUpdates');
      
      final response = await _client
          .from('medicamentos')
          .update(cleanedUpdates)
          .eq('id', medicamentoId)
          .select()
          .single();

      return Medicamento.fromMap(response);
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

  // Buscar medicamentos por status (concluído/pendente)
  // Atualizado para usar perfil_id (com fallback para user_id durante transição)
  Future<List<Medicamento>> getMedicamentosPorStatus(
    String userId,
    bool concluido,
  ) async {
    try {
      // Primeiro, obter o perfil_id do usuário
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
              ? 'perfil_id.eq.$perfilId,user_id.eq.$userId'
              : 'user_id.eq.$userId')
          .eq('concluido', concluido)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Medicamento.fromMap(item))
          .toList();
    } catch (error) {
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

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicamento.dart';
import '../core/errors/error_handler.dart';
import 'notification_service.dart';
import 'historico_eventos_service.dart';

class MedicamentoService {
  final SupabaseClient _client;

  MedicamentoService(this._client);

  // Buscar todos os medicamentos de um usuário
  Future<List<Medicamento>> getMedicamentos(String userId) async {
    try {
      final response = await _client
          .from('medicamentos')
          .select()
          .eq('user_id', userId)
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

      final response = await _client
          .from('medicamentos')
          .insert(data)
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
      throw ErrorHandler.toAppException(error);
    }
  }

  // Atualizar um medicamento existente
  Future<Medicamento> updateMedicamento(
    int medicamentoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _client
          .from('medicamentos')
          .update(updates)
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
            await HistoricoEventosService.addEvento({
              'perfil_id': medicamentoAtual.userId,
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

      final response = await _client
          .from('medicamentos')
          .update(updates)
          .eq('id', medicamentoId)
          .select()
          .single();

      return Medicamento.fromMap(response);
    } catch (error) {
      throw ErrorHandler.toAppException(error);
    }
  }

  // Buscar medicamentos por status (concluído/pendente)
  Future<List<Medicamento>> getMedicamentosPorStatus(
    String userId,
    bool concluido,
  ) async {
    try {
      final response = await _client
          .from('medicamentos')
          .select()
          .eq('user_id', userId)
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

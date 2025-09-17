import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicamento.dart';

class MedicamentoService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Buscar todos os medicamentos de um usuário
  static Future<List<Medicamento>> getMedicamentos(String userId) async {
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
      throw Exception('Erro ao buscar medicamentos: $error');
    }
  }

  // Adicionar um novo medicamento
  static Future<Medicamento> addMedicamento(Medicamento medicamento) async {
    try {
      final data = medicamento.toMap();
      data.remove('id'); // Remove o ID para inserção

      final response = await _client
          .from('medicamentos')
          .insert(data)
          .select()
          .single();

      return Medicamento.fromMap(response);
    } catch (error) {
      throw Exception('Erro ao adicionar medicamento: $error');
    }
  }

  // Atualizar um medicamento existente
  static Future<Medicamento> updateMedicamento(
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

      return Medicamento.fromMap(response);
    } catch (error) {
      throw Exception('Erro ao atualizar medicamento: $error');
    }
  }

  // Deletar um medicamento
  static Future<void> deleteMedicamento(int medicamentoId) async {
    try {
      await _client
          .from('medicamentos')
          .delete()
          .eq('id', medicamentoId);
    } catch (error) {
      throw Exception('Erro ao deletar medicamento: $error');
    }
  }

  // Marcar medicamento como concluído/não concluído
  static Future<Medicamento> toggleConcluido(
    int medicamentoId,
    bool concluido,
  ) async {
    try {
      final response = await _client
          .from('medicamentos')
          .update({'concluido': concluido})
          .eq('id', medicamentoId)
          .select()
          .single();

      return Medicamento.fromMap(response);
    } catch (error) {
      throw Exception('Erro ao atualizar status do medicamento: $error');
    }
  }

  // Buscar medicamentos por status (concluído/pendente)
  static Future<List<Medicamento>> getMedicamentosPorStatus(
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
      throw Exception('Erro ao buscar medicamentos por status: $error');
    }
  }

  // Buscar medicamento por ID
  static Future<Medicamento?> getMedicamentoPorId(int medicamentoId) async {
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
      throw Exception('Erro ao buscar medicamento: $error');
    }
  }
}
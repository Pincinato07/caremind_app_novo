import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vinculo_familiar.dart';
import '../core/errors/error_handler.dart';

class VinculoFamiliarService {
  final SupabaseClient _client;

  VinculoFamiliarService(this._client);

  Future<List<VinculoFamiliar>> getVinculosByFamiliar(String familiarId) async {
    try {
      final response = await _client
          .from('vinculos_familiares')
          .select()
          .eq('id_familiar', familiarId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => VinculoFamiliar.fromMap(data))
          .toList();
    } catch (error) {
      debugPrint('Erro ao buscar vínculos do familiar: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<List<VinculoFamiliar>> getVinculosByIdoso(String idosoId) async {
    try {
      final response = await _client
          .from('vinculos_familiares')
          .select()
          .eq('id_idoso', idosoId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => VinculoFamiliar.fromMap(data))
          .toList();
    } catch (error) {
      debugPrint('Erro ao buscar vínculos do idoso: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<VinculoFamiliar> createVinculo({
    required String idIdoso,
    required String idFamiliar,
  }) async {
    try {
      final vinculo = VinculoFamiliar(
        idIdoso: idIdoso,
        idFamiliar: idFamiliar,
        createdAt: DateTime.now(),
      );

      final response = await _client
          .from('vinculos_familiares')
          .insert(vinculo.toMap())
          .select()
          .single();

      return VinculoFamiliar.fromMap(response);
    } catch (error) {
      debugPrint('Erro ao criar vínculo: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<void> deleteVinculo({
    required String idIdoso,
    required String idFamiliar,
  }) async {
    try {
      await _client
          .from('vinculos_familiares')
          .delete()
          .eq('id_idoso', idIdoso)
          .eq('id_familiar', idFamiliar);
    } catch (error) {
      debugPrint('Erro ao deletar vínculo: $error');
      throw ErrorHandler.toAppException(error);
    }
  }

  Future<bool> existsVinculo({
    required String idIdoso,
    required String idFamiliar,
  }) async {
    try {
      final response = await _client
          .from('vinculos_familiares')
          .select()
          .eq('id_idoso', idIdoso)
          .eq('id_familiar', idFamiliar)
          .maybeSingle();

      return response != null;
    } catch (error) {
      debugPrint('Erro ao verificar vínculo: $error');
      return false;
    }
  }
}

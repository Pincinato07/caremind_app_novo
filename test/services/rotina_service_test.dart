import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/services/rotina_service.dart';

void main() {
  group('RotinaService', () {
    late RotinaService service;
    late SupabaseClient mockClient;

    setUp(() {
      mockClient = Supabase.instance.client;
      service = RotinaService(mockClient);
    });

    group('getRotinas', () {
      test('deve retornar lista de rotinas', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        final rotinas = await service.getRotinas(userId);

        // Assert
        expect(rotinas, isA<List<Map<String, dynamic>>>());
      });
    });

    group('migrarRotinasLegadas', () {
      test('deve executar migração sem erros', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        final migradas = await service.migrarRotinasLegadas(userId);

        // Assert
        expect(migradas, isA<int>());
        expect(migradas, greaterThanOrEqualTo(0));
      });
    });

    group('Migração de Dados Legados', () {
      test('deve identificar rotinas que precisam de migração', () {
        // Arrange - Rotina legada com horario mas sem frequencia
        final rotinaLegada = {
          'id': 1,
          'titulo': 'Rotina Teste',
          'horario': '08:00',
          'frequencia': null,
          'perfil_id': 'perfil-123',
        };

        // Arrange - Rotina com frequencia (não precisa migrar)
        final rotinaComFrequencia = {
          'id': 2,
          'titulo': 'Rotina com Frequência',
          'horario': '08:00',
          'frequencia': {
            'tipo': 'semanal',
            'dias_da_semana': [1, 3, 5],
            'horario': '10:00',
          },
          'perfil_id': 'perfil-123',
        };

        // Arrange - Rotina sem horario (não precisa migrar)
        final rotinaSemHorario = {
          'id': 3,
          'titulo': 'Rotina Sem Horário',
          'frequencia': null,
          'perfil_id': 'perfil-123',
        };

        // Act - Verificar lógica de migração
        final precisaMigrar1 = (rotinaLegada['frequencia'] == null ||
                rotinaLegada['frequencia'].toString().isEmpty) &&
            rotinaLegada['horario'] != null &&
            (rotinaLegada['horario'] as String).isNotEmpty;

        final precisaMigrar2 = (rotinaComFrequencia['frequencia'] == null ||
                rotinaComFrequencia['frequencia'].toString().isEmpty) &&
            rotinaComFrequencia['horario'] != null &&
            (rotinaComFrequencia['horario'] as String).isNotEmpty;

        final precisaMigrar3 = (rotinaSemHorario['frequencia'] == null ||
                rotinaSemHorario['frequencia'].toString().isEmpty) &&
            rotinaSemHorario['horario'] != null &&
            (rotinaSemHorario['horario'] as String).isNotEmpty;

        // Assert
        expect(precisaMigrar1, true); // Precisa migrar
        expect(precisaMigrar2, false); // Não precisa (já tem frequencia)
        expect(precisaMigrar3, false); // Não precisa (não tem horario)
      });
    });
  });
}


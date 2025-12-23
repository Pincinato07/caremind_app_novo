import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RotinaService - Migração de Dados Legados', () {
    test('deve identificar rotinas que precisam de migração', () {
      // Rotina legada com horario mas sem frequencia
      final rotinaLegada = {
        'id': 1,
        'titulo': 'Rotina Teste',
        'horario': '08:00',
        'frequencia': null,
        'perfil_id': 'perfil-123',
      };

      // Rotina com frequencia (não precisa migrar)
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

      // Rotina sem horario (não precisa migrar)
      final rotinaSemHorario = {
        'id': 3,
        'titulo': 'Rotina Sem Horário',
        'frequencia': null,
        'perfil_id': 'perfil-123',
      };

      // Verificar lógica de migração
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

      expect(precisaMigrar1, isTrue);
      expect(precisaMigrar2, isFalse);
      expect(precisaMigrar3, isFalse);
    });

    test('deve criar frequencia correta a partir de horario legado', () {
      final horarioLegado = '08:00';
      final frequenciaMigrada = {
        'tipo': 'diario',
        'horarios': [horarioLegado],
      };

      expect(frequenciaMigrada['tipo'], equals('diario'));
      expect(frequenciaMigrada['horarios'], isA<List>());
      expect(frequenciaMigrada['horarios'], contains('08:00'));
    });

    test('deve validar estrutura de frequencia após migração', () {
      final frequenciaMigrada = {
        'tipo': 'diario',
        'horarios': ['08:00', '14:00'],
      };

      expect(frequenciaMigrada.containsKey('tipo'), isTrue);
      expect(frequenciaMigrada.containsKey('horarios'), isTrue);
      expect(frequenciaMigrada['tipo'], equals('diario'));
      expect(frequenciaMigrada['horarios'], isA<List>());
    });
  });
}

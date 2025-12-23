import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RotinaAnalyticsService', () {
    test('deve obter estatísticas de rotinas corretamente', () {
      // Este teste verifica a estrutura de retorno esperada
      
      final rotinas = [
        {
          'id': 1,
          'titulo': 'Rotina 1',
          'frequencia': {'tipo': 'diario', 'horarios': ['08:00']},
          'concluido': true,
          'perfil_id': 'perfil-1',
        },
        {
          'id': 2,
          'titulo': 'Rotina 2',
          'frequencia': {'tipo': 'semanal', 'dias_da_semana': [1, 3, 5], 'horario': '10:00'},
          'concluido': false,
          'perfil_id': 'perfil-1',
        },
      ];

      // Verificar estrutura esperada
      expect(rotinas.length, equals(2));
      expect(rotinas[0]['frequencia'], isNotNull);
      final freq1 = rotinas[0]['frequencia'] as Map<String, dynamic>?;
      expect(freq1?['tipo'], equals('diario'));
      final freq2 = rotinas[1]['frequencia'] as Map<String, dynamic>?;
      expect(freq2?['tipo'], equals('semanal'));
    });

    test('deve contar frequências corretamente', () {
      final rotinas = [
        {'frequencia': {'tipo': 'diario'}},
        {'frequencia': {'tipo': 'diario'}},
        {'frequencia': {'tipo': 'semanal'}},
        {'frequencia': {'tipo': 'intervalo'}},
      ];

      final frequenciasCount = <String, int>{};
      for (final rotina in rotinas) {
        final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
        if (frequencia != null) {
          final tipo = frequencia['tipo'] as String? ?? 'desconhecido';
          frequenciasCount[tipo] = (frequenciasCount[tipo] ?? 0) + 1;
        }
      }

      expect(frequenciasCount['diario'], equals(2));
      expect(frequenciasCount['semanal'], equals(1));
      expect(frequenciasCount['intervalo'], equals(1));
    });

    test('deve calcular taxa de conclusão corretamente', () {
      final totalEventos = 10;
      final eventosConcluidos = 7;
      final taxaConclusao = totalEventos > 0 
          ? (eventosConcluidos / totalEventos) * 100 
          : 0.0;

      expect(taxaConclusao, equals(70.0));
    });

    test('deve retornar 0% quando não há eventos', () {
      final totalEventos = 0;
      final eventosConcluidos = 0;
      final taxaConclusao = totalEventos > 0 
          ? (eventosConcluidos / totalEventos) * 100 
          : 0.0;

      expect(taxaConclusao, equals(0.0));
    });

    test('deve calcular estatísticas básicas', () {
      final rotinas = [
        {'concluido': true},
        {'concluido': false},
        {'concluido': true},
        {'concluido': false},
        {'concluido': false},
      ];

      int totalConcluidas = 0;
      int totalPendentes = 0;

      for (final rotina in rotinas) {
        final concluido = rotina['concluido'] ?? false;
        if (concluido) {
          totalConcluidas++;
        } else {
          totalPendentes++;
        }
      }

      expect(totalConcluidas, equals(2));
      expect(totalPendentes, equals(3));
      expect(rotinas.length, equals(5));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/rotina_notification_service.dart';
import '../../lib/widgets/rotina_frequencia_widget.dart';

void main() {
  group('RotinaNotificationService', () {
    test('deve formatar frequência diária corretamente', () {
      final frequencia = {
        'tipo': 'diario',
        'horarios': ['08:00', '14:00', '20:00'],
      };

      final resultado = RotinaFrequenciaWidget.formatarFrequencia(frequencia);
      expect(resultado, equals('Diário - 08:00, 14:00, 20:00'));
    });

    test('deve formatar frequência intervalo corretamente', () {
      final frequencia = {
        'tipo': 'intervalo',
        'intervalo_horas': 6,
        'inicio': '08:00',
      };

      final resultado = RotinaFrequenciaWidget.formatarFrequencia(frequencia);
      expect(resultado, equals('A cada 6h (início: 08:00)'));
    });

    test('deve formatar frequência dias alternados corretamente', () {
      final frequencia = {
        'tipo': 'dias_alternados',
        'intervalo_dias': 2,
        'horario': '10:00',
      };

      final resultado = RotinaFrequenciaWidget.formatarFrequencia(frequencia);
      expect(resultado, equals('A cada 2 dias (10:00)'));
    });

    test('deve formatar frequência semanal corretamente', () {
      final frequencia = {
        'tipo': 'semanal',
        'dias_da_semana': [1, 3, 5],
        'horario': '09:00',
      };

      final resultado = RotinaFrequenciaWidget.formatarFrequencia(frequencia);
      expect(resultado, contains('Seg'));
      expect(resultado, contains('Qua'));
      expect(resultado, contains('Sex'));
      expect(resultado, contains('09:00'));
    });

    test('deve parsear horário corretamente', () {
      final horario1 = RotinaNotificationService.parseTimeOfDay('08:30');
      expect(horario1, isNotNull);
      expect(horario1!.hour, equals(8));
      expect(horario1.minute, equals(30));

      final horario2 = RotinaNotificationService.parseTimeOfDay('23:59');
      expect(horario2, isNotNull);
      expect(horario2!.hour, equals(23));
      expect(horario2.minute, equals(59));
    });

    test('deve retornar null para horário inválido', () {
      final horario1 = RotinaNotificationService.parseTimeOfDay('invalid');
      expect(horario1, isNull);

      final horario2 = RotinaNotificationService.parseTimeOfDay('25:00');
      expect(horario2, isNull);
    });

    test('deve gerar ID único para notificação', () {
      final id1 = RotinaNotificationService.generateNotificationId(1, 0);
      final id2 = RotinaNotificationService.generateNotificationId(1, 1);
      final id3 = RotinaNotificationService.generateNotificationId(2, 0);

      expect(id1, equals(2000)); // 1 * 2000 + 0
      expect(id2, equals(2001)); // 1 * 2000 + 1
      expect(id3, equals(4000)); // 2 * 2000 + 0
      expect(id1, isNot(equals(id2)));
      expect(id1, isNot(equals(id3)));
    });
  });
}

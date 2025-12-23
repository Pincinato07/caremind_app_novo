import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/notification_service.dart';
import '../../lib/models/medicamento.dart';

void main() {
  group('NotificationService', () {
    group('Inicialização', () {
      test('deve ter método initialize', () {
        // Act & Assert
        expect(() => NotificationService.initialize(), returnsNormally);
      });
    });

    group('scheduleMedicationReminders', () {
      test('deve aceitar medicamento válido', () {
        // Arrange
        final medicamento = Medicamento(
          id: 1,
          nome: 'Paracetamol',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
          frequencia: {
            'tipo': 'diario',
            'horarios': ['08:00', '20:00'],
          },
        );

        // Act & Assert
        expect(
          () => NotificationService.scheduleMedicationReminders(medicamento),
          returnsNormally,
        );
      });

      test('deve aceitar diferentes tipos de frequência', () {
        // Arrange - Frequência diária
        final medicamentoDiario = Medicamento(
          id: 1,
          nome: 'Medicamento Diário',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
          frequencia: {
            'tipo': 'diario',
            'horarios': ['08:00'],
          },
        );

        // Arrange - Frequência semanal
        final medicamentoSemanal = Medicamento(
          id: 2,
          nome: 'Medicamento Semanal',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
          frequencia: {
            'tipo': 'semanal',
            'dias_da_semana': [1, 3, 5],
            'horario': '10:00',
          },
        );

        // Arrange - Frequência por intervalo
        final medicamentoIntervalo = Medicamento(
          id: 3,
          nome: 'Medicamento Intervalo',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
          frequencia: {
            'tipo': 'intervalo',
            'intervalo_horas': 8,
            'inicio': '08:00',
          },
        );

        // Act & Assert
        expect(
          () => NotificationService.scheduleMedicationReminders(medicamentoDiario),
          returnsNormally,
        );
        expect(
          () => NotificationService.scheduleMedicationReminders(medicamentoSemanal),
          returnsNormally,
        );
        expect(
          () => NotificationService.scheduleMedicationReminders(medicamentoIntervalo),
          returnsNormally,
        );
      });
    });

    group('cancelMedicamentoNotifications', () {
      test('deve aceitar ID de medicamento válido', () {
        // Arrange
        const medicamentoId = 1;

        // Act & Assert
        expect(
          () => NotificationService.cancelMedicamentoNotifications(medicamentoId),
          returnsNormally,
        );
      });
    });
  });
}


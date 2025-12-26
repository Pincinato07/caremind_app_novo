import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/notification_service.dart';
import '../../lib/models/medicamento.dart';
import '../helpers/test_setup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await setupTests();
  });

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
    });

    group('cancelMedicationReminders', () {
      test('deve aceitar medicamentoId válido', () {
        // Arrange
        const medicamentoId = 1;

        // Act & Assert
        expect(
          () => NotificationService.cancelMedicationReminders(medicamentoId),
          returnsNormally,
        );
      });
    });

    group('scheduleRoutineReminder', () {
      test('deve aceitar parâmetros válidos', () {
        // Arrange
        const rotinaId = 'rotina-123';
        const titulo = 'Tomar remédio';
        final horario = DateTime.now().add(const Duration(hours: 1));

        // Act & Assert
        expect(
          () => NotificationService.scheduleRoutineReminder(
            rotinaId: rotinaId,
            titulo: titulo,
            horario: horario,
          ),
          returnsNormally,
        );
      });
    });

    group('cancelRoutineReminder', () {
      test('deve aceitar rotinaId válido', () {
        // Arrange
        const rotinaId = 'rotina-123';

        // Act & Assert
        expect(
          () => NotificationService.cancelRoutineReminder(rotinaId),
          returnsNormally,
        );
      });
    });
  });
}

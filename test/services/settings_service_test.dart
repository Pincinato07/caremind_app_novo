import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/services/settings_service.dart';
import '../helpers/test_setup.dart';
import 'package:get_it/get_it.dart';

void main() {
  // Inicializar binding do Flutter para testes
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Setup básico
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await setupTests();
    } catch (e) {
      // Ignorar erros de setup
    }
  });

  tearDownAll(() {
    try {
      GetIt.instance.reset();
    } catch (e) {
      // Ignorar erros no teardown
    }
  });

  group('SettingsService', () {
    late SettingsService service;

    setUp(() async {
      // Limpar SharedPreferences antes de cada teste
      SharedPreferences.setMockInitialValues({});
      service = SettingsService();
    });

    group('Inicialização', () {
      test('deve inicializar com valores padrão', () async {
        // Act
        await service.initialize();

        // Assert
        expect(service.notificationsMedicamentos, isA<bool>());
        expect(service.notificationsRotinas, isA<bool>());
        expect(service.fontSize, isA<double>());
      });

      test('deve carregar valores salvos', () async {
        // Arrange
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('notifications_medicamentos', false);
        await prefs.setBool('notifications_rotinas', false);

        // Act
        await service.initialize();

        // Assert
        expect(service.notificationsMedicamentos, false);
        expect(service.notificationsRotinas, false);
      });
    });

    group('Persistência', () {
      test('deve salvar notificationsMedicamentos', () async {
        // Arrange
        await service.initialize();

        // Act
        service.notificationsMedicamentos = false;
        await service.save();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications_medicamentos'), false);
      });

      test('deve salvar notificationsRotinas', () async {
        // Arrange
        await service.initialize();

        // Act
        service.notificationsRotinas = false;
        await service.save();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('notifications_rotinas'), false);
      });

      test('deve salvar fontSize', () async {
        // Arrange
        await service.initialize();

        // Act
        service.fontSize = 18.0;
        await service.save();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getDouble('font_size'), 18.0);
      });
    });

    group('Validação de Range', () {
      test('deve validar fontSize mínimo', () {
        // Arrange
        service.fontSize = 10.0;

        // Act
        service.fontSize = 5.0; // Abaixo do mínimo

        // Assert
        expect(service.fontSize, greaterThanOrEqualTo(10.0));
      });

      test('deve validar fontSize máximo', () {
        // Arrange
        service.fontSize = 10.0;

        // Act
        service.fontSize = 30.0; // Acima do máximo

        // Assert
        expect(service.fontSize, lessThanOrEqualTo(24.0));
      });
    });

    group('resetToDefaults', () {
      test('deve resetar todas as configurações para valores padrão', () async {
        // Arrange
        await service.initialize();
        service.notificationsMedicamentos = false;
        service.notificationsRotinas = false;
        service.fontSize = 20.0;

        // Act
        await service.resetToDefaults();

        // Assert
        expect(service.notificationsMedicamentos, true);
        expect(service.notificationsRotinas, true);
        expect(service.fontSize, 16.0);
      });
    });
  });
}

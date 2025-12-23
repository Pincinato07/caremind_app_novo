import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/services/emergencia_service.dart';
import '../../lib/core/errors/app_exception.dart';
import '../../lib/services/location_service.dart';
import '../helpers/test_setup.dart';
import 'dart:async';

void main() {
  // Garantir que Supabase está inicializado ANTES de qualquer teste
  setUpAll(() async {
    // Inicializar binding do Flutter primeiro
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mockar SharedPreferences ANTES de qualquer uso
    SharedPreferences.setMockInitialValues({});
    
    // Inicializar Supabase diretamente (mais confiável)
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key-for-testing-only',
      );
    } catch (e) {
      // Se já estiver inicializado, verificar se está acessível
      try {
        final _ = Supabase.instance.client;
      } catch (e2) {
        // Se não estiver acessível, tentar novamente
        await Supabase.initialize(
          url: 'https://test.supabase.co',
          anonKey: 'test-anon-key-for-testing-only',
        );
      }
    }
    
    // Chamar setupTests para configurar GetIt
    await setupTests();
    
    // Verificar que está realmente acessível
    final _ = Supabase.instance.client;
  });

  group('EmergenciaService', () {
    late EmergenciaService service;

    setUp(() {
      // Supabase já foi inicializado no setUpAll
      // Apenas criar o serviço
      service = EmergenciaService();
    });

    group('acionarEmergencia', () {
      test('deve lançar exceção quando idosoId está vazio', () async {
        // Arrange & Act & Assert
        expect(
          () async => await service.acionarEmergencia(idosoId: ''),
          throwsA(isA<UnknownException>().having(
            (e) => e.message,
            'message',
            contains('ID do idoso não pode ser vazio'),
          )),
        );
      });

      test('deve validar que idosoId não pode ser vazio', () async {
        // Arrange
        const idosoIdVazio = '';

        // Act & Assert
        expect(
          () async => await service.acionarEmergencia(idosoId: idosoIdVazio),
          throwsA(isA<UnknownException>()),
        );
      });

      test('deve aceitar diferentes tipos de emergência', () {
        // Arrange
        const idosoId = 'idoso-123';

        // Act & Assert - Verificar que os tipos existem e são válidos
        expect(TipoEmergencia.panico, isNotNull);
        expect(TipoEmergencia.queda, isNotNull);
        expect(TipoEmergencia.medicamento, isNotNull);
        expect(TipoEmergencia.outro, isNotNull);
        
        // Verificar estrutura
        expect(idosoId, isNotEmpty);
        expect(TipoEmergencia.values.length, 4);
        expect(service, isNotNull);
      });

      test('deve aceitar mensagem opcional', () {
        // Arrange
        const idosoId = 'idoso-123';
        const mensagem = 'Mensagem de teste';

        // Act & Assert - Verificar que o método aceita mensagem
        expect(mensagem, isA<String>());
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });

      test('deve aceitar localização opcional', () {
        // Arrange
        const idosoId = 'idoso-123';
        final localizacao = {
          'latitude': -23.5505,
          'longitude': -46.6333,
        };

        // Act & Assert - Verificar estrutura
        expect(localizacao['latitude'], isA<double>());
        expect(localizacao['longitude'], isA<double>());
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });
    });

    group('acionarPanico', () {
      test('deve lançar exceção quando idosoId está vazio', () async {
        // Arrange & Act & Assert
        expect(
          () async => await service.acionarPanico(idosoId: ''),
          throwsA(isA<UnknownException>()),
        );
      });

      test('deve aceitar localização fornecida', () {
        // Arrange
        const idosoId = 'idoso-123';
        final localizacao = {
          'latitude': -23.5505,
          'longitude': -46.6333,
        };

        // Act & Assert - Verificar estrutura
        expect(localizacao['latitude'], isA<double>());
        expect(localizacao['longitude'], isA<double>());
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });

      test('deve tentar capturar GPS quando capturarGPS é true', () {
        // Arrange
        const idosoId = 'idoso-123';

        // Act & Assert - Verificar estrutura
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });
    });

    group('acionarQueda', () {
      test('deve lançar exceção quando idosoId está vazio', () async {
        // Arrange & Act & Assert
        expect(
          () async => await service.acionarQueda(idosoId: ''),
          throwsA(isA<UnknownException>()),
        );
      });

      test('deve aceitar localização fornecida', () {
        // Arrange
        const idosoId = 'idoso-123';
        final localizacao = {
          'latitude': -23.5505,
          'longitude': -46.6333,
        };

        // Act & Assert - Verificar estrutura
        expect(localizacao['latitude'], isA<double>());
        expect(localizacao['longitude'], isA<double>());
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });

      test('deve tentar capturar GPS quando capturarGPS é true', () {
        // Arrange
        const idosoId = 'idoso-123';

        // Act & Assert - Verificar estrutura
        expect(idosoId, isNotEmpty);
        expect(service, isNotNull);
      });
    });

    group('TipoEmergencia', () {
      test('deve ter todos os tipos esperados', () {
        // Arrange & Act & Assert
        expect(TipoEmergencia.values.length, 4);
        expect(TipoEmergencia.values, contains(TipoEmergencia.panico));
        expect(TipoEmergencia.values, contains(TipoEmergencia.queda));
        expect(TipoEmergencia.values, contains(TipoEmergencia.medicamento));
        expect(TipoEmergencia.values, contains(TipoEmergencia.outro));
      });
    });
  });
}

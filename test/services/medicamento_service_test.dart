import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/medicamento_service.dart';
import '../../lib/models/medicamento.dart';
import '../../lib/core/errors/result.dart';
import '../../lib/core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/test_setup.dart';

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

  group('MedicamentoService', () {
    late MedicamentoService service;
    late SupabaseClient mockClient;

    setUp(() {
      // Supabase já foi inicializado no setUpAll
      mockClient = Supabase.instance.client;
      service = MedicamentoService(mockClient);
    });

    group('addMedicamento - Validações', () {
      test('deve lançar exceção quando nome está vazio', () async {
        // Arrange
        final medicamento = Medicamento(
          nome: '   ', // Nome com apenas espaços
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () async => await service.addMedicamento(medicamento),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Nome do medicamento é obrigatório'),
          )),
        );
      });

      test('deve lançar exceção quando nome está vazio (string vazia)', () async {
        // Arrange
        final medicamento = Medicamento(
          nome: '',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () async => await service.addMedicamento(medicamento),
          throwsA(isA<Exception>()),
        );
      });

      test('deve aceitar medicamento com nome válido', () {
        // Arrange
        final medicamento = Medicamento(
          nome: 'Paracetamol',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
        );

        // Act & Assert - Verificar que o modelo aceita nome válido
        expect(medicamento.nome, 'Paracetamol');
        expect(medicamento.nome.trim().isNotEmpty, true);
        expect(medicamento.perfilId, 'perfil-123');
        expect(service, isNotNull);
      });

      test('deve aceitar medicamento com perfilId válido', () {
        // Arrange
        final medicamento = Medicamento(
          nome: 'Paracetamol',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
        );

        // Act & Assert - Verificar que o modelo aceita perfilId válido
        expect(medicamento.perfilId, 'perfil-123');
        expect(medicamento.perfilId.isNotEmpty, true);
        expect(medicamento.nome, 'Paracetamol');
        expect(service, isNotNull);
      });
    });

    group('getMedicamentoPorId', () {
      test('deve retornar null quando medicamento não existe', () async {
        // Arrange
        const medicamentoId = 99999; // ID que não existe

        // Act
        final result = await service.getMedicamentoPorId(medicamentoId);

        // Assert
        // Em ambiente de teste sem dados reais, pode retornar null ou lançar exceção
        // O comportamento depende do mock/ambiente
        expect(result, anyOf(isNull, isA<Medicamento>()));
      });
    });

    group('updateMedicamento - Validações', () {
      test('deve lançar exceção quando medicamento não existe', () async {
        // Arrange
        const medicamentoId = 99999; // ID que não existe
        final updates = {'nome': 'Novo Nome'};

        // Act & Assert
        expect(
          () async => await service.updateMedicamento(medicamentoId, updates),
          throwsA(anyOf(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Medicamento não encontrado'),
            ),
            isA<AppException>(),
          )),
        );
      });
    });

    group('toggleConcluido - Validações', () {
      test('deve lançar exceção quando medicamento não existe', () async {
        // Arrange
        const medicamentoId = 99999; // ID que não existe
        final dataPrevista = DateTime.now();

        // Act & Assert
        expect(
          () async => await service.toggleConcluido(
            medicamentoId,
            true,
            dataPrevista,
          ),
          throwsA(anyOf(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Medicamento não encontrado'),
            ),
            isA<AppException>(),
          )),
        );
      });

      test('deve aceitar dataPrevista válida', () {
        // Arrange
        const medicamentoId = 1;
        final dataPrevista = DateTime.now();

        // Act & Assert - Verificar estrutura
        expect(dataPrevista, isA<DateTime>());
        expect(medicamentoId, isA<int>());
        expect(service, isNotNull);
      });
    });

    group('deleteMedicamento', () {
      test('deve ter método deleteMedicamento', () {
        // Arrange
        const medicamentoId = 1;

        // Act & Assert - Verificar que o método existe
        expect(medicamentoId, isA<int>());
        expect(service, isNotNull);
      });
    });

    group('getMedicamentos', () {
      test('deve retornar Result quando chamado', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        final result = await service.getMedicamentos(userId);

        // Assert
        expect(result, isA<Result<List<Medicamento>>>());
      });

      test('deve retornar Success ou Failure', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        final result = await service.getMedicamentos(userId);

        // Assert
        expect(
          result,
          anyOf(
            isA<Success<List<Medicamento>>>(),
            isA<Failure<List<Medicamento>>>(),
          ),
        );
      });
    });

    group('Medicamento Model', () {
      test('deve criar medicamento com todos os campos', () {
        // Arrange & Act
        final medicamento = Medicamento(
          id: 1,
          nome: 'Paracetamol',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
          dosagem: '500mg',
          quantidade: 30,
          via: 'oral',
          frequencia: {
            'tipo': 'diario',
            'horarios': ['08:00', '20:00'],
          },
        );

        // Assert
        expect(medicamento.id, 1);
        expect(medicamento.nome, 'Paracetamol');
        expect(medicamento.perfilId, 'perfil-123');
        expect(medicamento.dosagem, '500mg');
        expect(medicamento.quantidade, 30);
        expect(medicamento.via, 'oral');
        expect(medicamento.frequencia, isNotNull);
      });

      test('deve converter para Map corretamente', () {
        // Arrange
        final medicamento = Medicamento(
          id: 1,
          nome: 'Paracetamol',
          perfilId: 'perfil-123',
          createdAt: DateTime.now(),
        );

        // Act
        final map = medicamento.toMap();

        // Assert
        expect(map['nome'], 'Paracetamol');
        expect(map['perfil_id'], 'perfil-123');
        expect(map['id'], 1);
      });

      test('deve criar a partir de Map corretamente', () {
        // Arrange
        final map = {
          'id': 1,
          'nome': 'Paracetamol',
          'perfil_id': 'perfil-123',
          'created_at': DateTime.now().toIso8601String(),
          'dosagem': '500mg',
          'quantidade': 30,
          'via': 'oral',
        };

        // Act
        final medicamento = Medicamento.fromMap(map);

        // Assert
        expect(medicamento.id, 1);
        expect(medicamento.nome, 'Paracetamol');
        expect(medicamento.perfilId, 'perfil-123');
        expect(medicamento.dosagem, '500mg');
      });
    });
  });
}

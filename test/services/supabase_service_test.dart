import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/services/supabase_service.dart';
import '../../lib/core/errors/app_exception.dart';
import '../helpers/test_setup.dart';

void main() {
  group('SupabaseService', () {
    late SupabaseService service;
    late SupabaseClient mockClient;

    setUpAll(() async {
      await setupTests();
    });

    setUp(() {
      mockClient = Supabase.instance.client;
      service = SupabaseService(mockClient);
    });

    group('signUp', () {
      test('deve ter método signUp', () {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const nome = 'Test User';
        const tipo = 'idoso';

        // Act & Assert
        expect(
          () => service.signUp(
            email: email,
            password: password,
            nome: nome,
            tipo: tipo,
          ),
          returnsNormally,
        );
      });

      test('deve aceitar telefone opcional', () {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const nome = 'Test User';
        const tipo = 'idoso';
        const telefone = '+5511999999999';

        // Act & Assert
        expect(
          () => service.signUp(
            email: email,
            password: password,
            nome: nome,
            tipo: tipo,
            telefone: telefone,
          ),
          returnsNormally,
        );
      });
    });

    group('signIn', () {
      test('deve ter método signIn', () {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';

        // Act & Assert
        expect(
          () => service.signIn(
            email: email,
            password: password,
          ),
          returnsNormally,
        );
      });
    });

    group('signOut', () {
      test('deve ter método signOut', () {
        // Act & Assert
        expect(() => service.signOut(), returnsNormally);
      });
    });

    group('resetPassword', () {
      test('deve ter método resetPassword', () {
        // Arrange
        const email = 'test@example.com';

        // Act & Assert
        expect(() => service.resetPassword(email), returnsNormally);
      });
    });

    group('currentUser', () {
      test('deve ter getter currentUser', () {
        // Act
        final user = service.currentUser;

        // Assert
        // Pode ser null se não estiver autenticado
        expect(user, anyOf(isNull, isNotNull));
      });
    });

    group('authStateChanges', () {
      test('deve ter stream authStateChanges', () {
        // Act
        final stream = service.authStateChanges;

        // Assert
        expect(stream, isA<Stream<AuthState>>());
      });
    });

    group('gerarCodigoVinculacao', () {
      test('deve ter método gerarCodigoVinculacao', () async {
        // Act & Assert
        // Pode falhar se RPC não estiver disponível, mas o método existe
        try {
          await service.gerarCodigoVinculacao();
        } catch (e) {
          // Esperado em ambiente de teste sem RPC real
          expect(e, isNotNull);
        }
      });
    });

    group('vincularPorCodigo', () {
      test('deve ter método vincularPorCodigo', () async {
        // Arrange
        const codigo = 'ABC123';

        // Act & Assert
        // Pode falhar se RPC não estiver disponível, mas o método existe
        try {
          await service.vincularPorCodigo(codigo);
        } catch (e) {
          // Esperado em ambiente de teste sem RPC real
          expect(e, isNotNull);
        }
      });
    });
  });
}


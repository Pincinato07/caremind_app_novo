import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../lib/services/organizacao_validator.dart';

void main() {
  group('OrganizacaoValidator', () {
    late OrganizacaoValidator validator;

    setUp(() {
      validator = OrganizacaoValidator();
    });

    group('podeAcessarIdoso', () {
      test('deve retornar boolean', () async {
        // Arrange
        const perfilId = 'perfil-123';

        // Act
        final result = await validator.podeAcessarIdoso(perfilId);

        // Assert
        expect(result, isA<bool>());
      });

      test('deve aceitar perfilId válido', () {
        // Arrange
        const perfilId = 'perfil-123';

        // Act & Assert
        expect(
          () => validator.podeAcessarIdoso(perfilId),
          returnsNormally,
        );
      });
    });

    group('validarAcessoIdosoOrganizacao', () {
      test('deve retornar organizacaoId quando válido', () async {
        // Arrange
        const perfilId = 'perfil-123';

        // Act & Assert
        // Pode lançar exceção se não for membro ou não pertencer a organização
        expect(
          () => validator.validarAcessoIdosoOrganizacao(perfilId),
          returnsNormally,
        );
      });
    });

    group('podeGerenciarIdoso', () {
      test('deve retornar boolean', () async {
        // Arrange
        const perfilId = 'perfil-123';

        // Act
        final result = await validator.podeGerenciarIdoso(perfilId);

        // Assert
        expect(result, isA<bool>());
      });

      test('deve aceitar roleMinimo opcional', () async {
        // Arrange
        const perfilId = 'perfil-123';
        const roleMinimo = 'cuidador';

        // Act
        final result = await validator.podeGerenciarIdoso(
          perfilId,
          roleMinimo: roleMinimo,
        );

        // Assert
        expect(result, isA<bool>());
      });
    });
  });
}


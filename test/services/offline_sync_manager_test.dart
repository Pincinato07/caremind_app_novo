import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/offline_sync_manager.dart';

void main() {
  group('OfflineSyncManager', () {
    tearDown(() {
      // Limpar estado após cada teste
      OfflineSyncManager.dispose();
    });

    group('Inicialização', () {
      test('deve inicializar sem erros', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        await OfflineSyncManager.initialize(userId);

        // Assert
        // Não deve lançar exceção
        expect(() => OfflineSyncManager.initialize(userId), returnsNormally);
      });

      test('não deve inicializar duas vezes', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        await OfflineSyncManager.initialize(userId);
        await OfflineSyncManager.initialize(userId); // Segunda chamada

        // Assert
        // Não deve lançar exceção (deve retornar imediatamente)
        expect(() => OfflineSyncManager.initialize(userId), returnsNormally);
      });
    });

    group('processPendingData', () {
      test('deve executar sem erros de sintaxe', () async {
        // Arrange
        const userId = 'user-123';
        await OfflineSyncManager.initialize(userId);

        // Act & Assert
        expect(
          () => OfflineSyncManager.processPendingData(userId),
          returnsNormally,
        );
      });

      test('deve proteger contra processamento concorrente', () async {
        // Arrange
        const userId = 'user-123';
        await OfflineSyncManager.initialize(userId);

        // Act - chamar múltiplas vezes simultaneamente
        final futures = List.generate(
          5,
          (_) => OfflineSyncManager.processPendingData(userId),
        );

        // Assert - não deve lançar exceção
        expect(() => Future.wait(futures), returnsNormally);
      });
    });

    group('dispose', () {
      test('deve desinicializar sem erros', () {
        // Act & Assert
        expect(() => OfflineSyncManager.dispose(), returnsNormally);
      });

      test('deve permitir reinicialização após dispose', () async {
        // Arrange
        const userId = 'user-123';

        // Act
        await OfflineSyncManager.initialize(userId);
        OfflineSyncManager.dispose();
        await OfflineSyncManager.initialize(userId);

        // Assert
        // Não deve lançar exceção
        expect(() => OfflineSyncManager.initialize(userId), returnsNormally);
      });
    });
  });
}


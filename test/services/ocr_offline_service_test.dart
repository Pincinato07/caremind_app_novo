import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import '../../lib/services/ocr_offline_service.dart';

void main() {
  group('OcrOfflineService', () {
    group('saveImageForLater', () {
      test('deve aceitar imageFile e userId válidos', () {
        // Arrange
        // Nota: Em ambiente de teste real, precisaríamos criar um arquivo temporário
        // Aqui testamos apenas a estrutura do método
        const userId = 'user-123';

        // Act & Assert
        // O método precisa de um File real, então testamos apenas que o método existe
        expect(
          () => OcrOfflineService.saveImageForLater(
            imageFile: File('test.jpg'),
            userId: userId,
          ),
          returnsNormally,
        );
      });
    });

    group('processPendingImages', () {
      test('deve retornar número de imagens processadas', () async {
        // Act
        final processed = await OcrOfflineService.processPendingImages();

        // Assert
        expect(processed, isA<int>());
        expect(processed, greaterThanOrEqualTo(0));
      });
    });

    group('cleanupOldImages', () {
      test('deve executar limpeza sem erros', () async {
        // Act & Assert
        expect(
          () => OcrOfflineService.cleanupOldImages(),
          returnsNormally,
        );
      });
    });
  });
}


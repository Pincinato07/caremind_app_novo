import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Resultado da validação de imagem
class ImageValidationResult {
  final bool valid;
  final String? message;
  final File? optimizedFile;
  final int? originalSize;
  final int? optimizedSize;

  ImageValidationResult({
    required this.valid,
    this.message,
    this.optimizedFile,
    this.originalSize,
    this.optimizedSize,
  });
}

/// Serviço para validar e otimizar imagens antes do upload OCR
/// Garante que as imagens atendem aos requisitos para processamento
class ImageValidator {
  static const int maxFileSize = 20 * 1024 * 1024; // 20MB
  static const int maxWidth = 1920;
  static const int maxHeight = 1920;
  static const int minWidth = 200;
  static const int minHeight = 200;
  static const double maxAspectRatio = 5.0; // Máximo 5:1 ou 1:5
  static const double minAspectRatio = 0.2; // Mínimo 1:5 ou 5:1

  /// Valida se a imagem é adequada para OCR
  static Future<ImageValidationResult> validateImageForOCR(File imageFile) async {
    try {
      // 1. Verificar se arquivo existe
      if (!await imageFile.exists()) {
        return ImageValidationResult(
          valid: false,
          message: 'Arquivo de imagem não encontrado.',
        );
      }

      // 2. Verificar tamanho do arquivo
      final fileSize = await imageFile.length();
      if (fileSize == 0) {
        return ImageValidationResult(
          valid: false,
          message: 'Arquivo de imagem está vazio.',
        );
      }

      if (fileSize > maxFileSize) {
        return ImageValidationResult(
          valid: false,
          message: 'Imagem muito grande. Máximo permitido: ${formatFileSize(maxFileSize)}. '
              'Tamanho atual: ${formatFileSize(fileSize)}.',
        );
      }

      // 3. Ler e verificar dimensões da imagem
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        return ImageValidationResult(
          valid: false,
          message: 'Não foi possível ler a imagem. Verifique se o arquivo está corrompido.',
        );
      }

      final width = decodedImage.width;
      final height = decodedImage.height;

      // 4. Verificar dimensões mínimas
      if (width < minWidth || height < minHeight) {
        return ImageValidationResult(
          valid: false,
          message: 'Imagem muito pequena. Dimensões mínimas: ${minWidth}x${minHeight}px. '
              'Dimensões atuais: ${width}x${height}px.',
        );
      }

      // 5. Verificar aspect ratio (evitar imagens muito alongadas)
      final aspectRatio = width / height;
      if (aspectRatio > maxAspectRatio || aspectRatio < minAspectRatio) {
        return ImageValidationResult(
          valid: false,
          message: 'Proporção da imagem não adequada para OCR. '
              'A imagem está muito alongada ou muito estreita.',
        );
      }

      // 6. Verificar se precisa otimizar
      bool needsOptimization = false;
      if (width > maxWidth || height > maxHeight) {
        needsOptimization = true;
      }

      if (needsOptimization) {
        // Otimizar imagem
        final optimized = await _optimizeImage(decodedImage, imageFile);
        if (optimized == null) {
          return ImageValidationResult(
            valid: false,
            message: 'Falha ao otimizar imagem. Tente novamente.',
          );
        }

        return ImageValidationResult(
          valid: true,
          optimizedFile: optimized,
          originalSize: fileSize,
          optimizedSize: await optimized.length(),
        );
      }

      // Imagem válida e não precisa otimização
      return ImageValidationResult(
        valid: true,
        optimizedFile: imageFile,
        originalSize: fileSize,
        optimizedSize: fileSize,
      );
    } catch (e) {
      debugPrint('❌ Erro ao validar imagem: $e');
      return ImageValidationResult(
        valid: false,
        message: 'Erro ao validar imagem: ${e.toString()}',
      );
    }
  }

  /// Otimiza imagem redimensionando se necessário
  static Future<File?> _optimizeImage(img.Image originalImage, File originalFile) async {
    try {
      int newWidth = originalImage.width;
      int newHeight = originalImage.height;

      // Calcular novas dimensões mantendo aspect ratio
      if (newWidth > maxWidth || newHeight > maxHeight) {
        final aspectRatio = newWidth / newHeight;

        if (newWidth > newHeight) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }

      // Redimensionar imagem
      final resized = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Converter para JPEG com qualidade 85%
      final jpegBytes = img.encodeJpg(resized, quality: 85);

      // Salvar em arquivo temporário
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(jpegBytes);

      debugPrint('✅ Imagem otimizada: ${originalImage.width}x${originalImage.height} → ${newWidth}x${newHeight}');

      return tempFile;
    } catch (e) {
      debugPrint('❌ Erro ao otimizar imagem: $e');
      return null;
    }
  }

  /// Formata tamanho do arquivo para exibição
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  /// Validação rápida (sem leitura completa da imagem)
  static Future<bool> quickValidate(File imageFile) async {
    try {
      if (!await imageFile.exists()) return false;
      final size = await imageFile.length();
      return size > 0 && size <= maxFileSize;
    } catch (e) {
      return false;
    }
  }
}


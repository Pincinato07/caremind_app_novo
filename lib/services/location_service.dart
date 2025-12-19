import 'package:geolocator/geolocator.dart';

/// Serviço para captura de localização GPS
/// Trata permissões, falhas e fornece fallbacks
class LocationService {
  /// Verifica e solicita permissões de localização
  Future<bool> _verificarPermissoes() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      // Erro ao verificar permissões - retornar false para segurança
      return false;
    }
  }

  /// Captura a localização atual com alta precisão
  /// Retorna null se não conseguir capturar
  /// Lança LocationException em caso de erro crítico
  Future<Map<String, double>?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      // Verificar permissões
      final temPermissao = await _verificarPermissoes();
      if (!temPermissao) {
        throw LocationException(
          'Permissão de localização negada ou GPS desligado',
          type: LocationErrorType.permissionDenied,
        );
      }

      // Tentar capturar localização com timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout, onTimeout: () {
        throw TimeoutException('Timeout ao capturar localização');
      });

      // Validar coordenadas
      if (position.latitude.isNaN || position.longitude.isNaN) {
        throw LocationException(
          'Coordenadas inválidas recebidas',
          type: LocationErrorType.invalidCoordinates,
        );
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } on TimeoutException {
      // Timeout - tentar localização aproximada
      try {
        return await _getLastKnownLocation();
      } catch (e) {
        throw LocationException(
          'Timeout ao capturar localização e nenhuma localização conhecida disponível',
          type: LocationErrorType.timeout,
        );
      }
    } on LocationException {
      // Re-lançar LocationException
      rethrow;
    } catch (e) {
      // Qualquer outro erro - tentar última localização conhecida
      try {
        final lastLocation = await _getLastKnownLocation();
        if (lastLocation != null) {
          return lastLocation;
        }
      } catch (_) {
        // Ignorar erro do fallback
      }

      // Se chegou aqui, não conseguiu capturar nem fallback
      throw LocationException(
        'Erro ao capturar localização: ${e.toString()}',
        type: LocationErrorType.unknown,
      );
    }
  }

  /// Obtém a última localização conhecida (fallback)
  Future<Map<String, double>?> _getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        // Validar coordenadas
        if (position.latitude.isNaN || position.longitude.isNaN) {
          return null;
        }

        // Verificar se a localização não é muito antiga (mais de 1 hora)
        final agora = DateTime.now();
        final diferenca = agora.difference(position.timestamp);
        if (diferenca.inHours > 1) {
          // Localização muito antiga, não usar
          return null;
        }

        return {
          'latitude': position.latitude,
          'longitude': position.longitude,
        };
      }
    } catch (e) {
      // Ignorar erro silenciosamente
    }
    return null;
  }

  /// Verifica se o GPS está disponível
  Future<bool> isLocationAvailable() async {
    try {
      final temPermissao = await _verificarPermissoes();
      if (!temPermissao) {
        return false;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      return serviceEnabled;
    } catch (e) {
      return false;
    }
  }

  /// Obtém mensagem de status da localização
  Future<String> getLocationStatusMessage() async {
    final temPermissao = await _verificarPermissoes();
    if (!temPermissao) {
      return 'Localização não disponível: permissão negada';
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Localização não disponível: GPS desligado';
    }

    return 'Localização disponível';
  }
}

/// Exceção customizada para timeout de localização
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}

/// Tipos de erro de localização
enum LocationErrorType {
  permissionDenied,
  timeout,
  invalidCoordinates,
  serviceUnavailable,
  unknown,
}

/// Exceção customizada para erros de localização
class LocationException implements Exception {
  final String message;
  final LocationErrorType type;

  LocationException(this.message, {required this.type});

  @override
  String toString() => message;

  /// Mensagem amigável para o usuário
  String get userFriendlyMessage {
    switch (type) {
      case LocationErrorType.permissionDenied:
        return 'Localização não disponível. Verifique as permissões do app nas configurações.';
      case LocationErrorType.timeout:
        return 'Tempo esgotado ao capturar localização. Tente novamente.';
      case LocationErrorType.invalidCoordinates:
        return 'Erro ao obter coordenadas válidas.';
      case LocationErrorType.serviceUnavailable:
        return 'Serviço de localização não disponível. Verifique se o GPS está ligado.';
      case LocationErrorType.unknown:
        return 'Erro ao capturar localização. O alerta será enviado sem coordenadas.';
    }
  }
}

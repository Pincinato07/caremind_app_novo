import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Handler para processar Deep Links do app
/// Esquema: caremind://
class DeepLinkHandler {
  static const _channel = MethodChannel('caremind/deep_link');
  
  final _linkController = StreamController<Uri>.broadcast();
  
  /// Stream de deep links recebidos
  Stream<Uri> get linkStream => _linkController.stream;
  
  Uri? _initialLink;
  
  /// Link inicial que abriu o app (se houver)
  Uri? get initialLink => _initialLink;

  DeepLinkHandler() {
    _init();
  }

  void _init() {
    // Escuta links recebidos enquanto o app está aberto
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments as String?;
        if (link != null) {
          final uri = Uri.tryParse(link);
          if (uri != null) {
            debugPrint('🔗 Deep Link recebido: $uri');
            _linkController.add(uri);
          }
        }
      }
      return null;
    });

    // Verifica se o app foi aberto por um deep link
    _getInitialLink();
  }

  Future<void> _getInitialLink() async {
    try {
      final link = await _channel.invokeMethod<String>('getInitialLink');
      if (link != null) {
        _initialLink = Uri.tryParse(link);
        if (_initialLink != null) {
          debugPrint('🔗 Deep Link inicial: $_initialLink');
          _linkController.add(_initialLink!);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao obter deep link inicial: $e');
    }
  }

  /// Processa um deep link e retorna a rota correspondente
  static DeepLinkRoute? parseRoute(Uri uri) {
    if (uri.scheme != 'caremind') return null;

    switch (uri.host) {
      case 'alexa-callback':
        return DeepLinkRoute.alexaCallback;
      case 'success':
        return DeepLinkRoute.success;
      case 'error':
        return DeepLinkRoute.error;
      default:
        return null;
    }
  }

  void dispose() {
    _linkController.close();
  }
}

/// Rotas possíveis de deep link
enum DeepLinkRoute {
  alexaCallback,
  success,
  error,
}


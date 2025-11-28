import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';
import '../services/notificacoes_app_service.dart';
import '../core/injection/injection.dart';
import 'in_app_notification.dart';

/// Widget wrapper que configura o handler de FCM foreground
/// e mostra in-app notifications quando o app está aberto.
/// 
/// Deve envolver o widget principal do app (geralmente MaterialApp ou similar).
/// 
/// Exemplo de uso:
/// ```dart
/// FCMForegroundHandler(
///   child: MaterialApp(...),
/// )
/// ```
class FCMForegroundHandler extends StatefulWidget {
  final Widget child;
  
  /// Callback opcional quando uma notificação é recebida
  final void Function(RemoteMessage message)? onNotificationReceived;
  
  /// Se deve mostrar in-app notification automaticamente
  final bool showInAppNotification;

  const FCMForegroundHandler({
    super.key,
    required this.child,
    this.onNotificationReceived,
    this.showInAppNotification = true,
  });

  @override
  State<FCMForegroundHandler> createState() => _FCMForegroundHandlerState();
}

class _FCMForegroundHandlerState extends State<FCMForegroundHandler> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupForegroundHandler();
  }

  void _setupForegroundHandler() {
    // Configurar o callback para notificações em foreground
    NotificationService.onForegroundMessage = (RemoteMessage message) {
      debugPrint('🔔 FCMForegroundHandler: Notificação recebida');
      
      // Chamar callback opcional
      widget.onNotificationReceived?.call(message);
      
      // Mostrar in-app notification se habilitado
      if (widget.showInAppNotification && mounted) {
        _showInAppNotification(message);
      }
      
      // Atualizar contagem de notificações não lidas
      _refreshNotificationsCount();
    };
  }

  void _showInAppNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Determinar o tipo baseado no payload
    String tipo = 'info';
    if (message.data.containsKey('type')) {
      final type = message.data['type'] as String?;
      if (type != null) {
        if (type.contains('medicamento')) {
          tipo = 'medicamento';
        } else if (type.contains('rotina')) {
          tipo = 'rotina';
        } else if (type.contains('compromisso')) {
          tipo = 'compromisso';
        } else if (type.contains('error') || type.contains('atrasado')) {
          tipo = 'warning';
        }
      }
    }

    // Usar o context do navigator para mostrar a notificação
    final context = _navigatorKey.currentContext;
    if (context != null) {
      InAppNotification.show(
        context,
        titulo: notification.title ?? 'CareMind',
        mensagem: notification.body ?? '',
        tipo: tipo,
        onTap: () {
          // Navegar para a tela de notificações ao tocar
          Navigator.of(context).pushNamed('/alertas');
        },
      );
    }
  }

  void _refreshNotificationsCount() {
    try {
      final service = getIt<NotificacoesAppService>();
      service.atualizarContagem();
      service.carregarNotificacoes();
    } catch (e) {
      debugPrint('Erro ao atualizar contagem: $e');
    }
  }

  @override
  void dispose() {
    // Limpar o callback ao desmontar
    NotificationService.onForegroundMessage = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usar um Navigator key para ter acesso ao context
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => widget.child,
        );
      },
    );
  }
}

/// Mixin para adicionar suporte a in-app notifications em qualquer StatefulWidget
/// 
/// Exemplo de uso:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   @override
///   State<MyScreen> createState() => _MyScreenState();
/// }
/// 
/// class _MyScreenState extends State<MyScreen> with InAppNotificationMixin {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(...);
///   }
/// }
/// ```
mixin InAppNotificationMixin<T extends StatefulWidget> on State<T> {
  /// Mostrar uma in-app notification
  void showInAppNotification({
    required String titulo,
    required String mensagem,
    String tipo = 'info',
    VoidCallback? onTap,
  }) {
    InAppNotification.show(
      context,
      titulo: titulo,
      mensagem: mensagem,
      tipo: tipo,
      onTap: onTap,
    );
  }

  /// Mostrar notificação de sucesso
  void showSuccessNotification(String mensagem, {String? titulo}) {
    showInAppNotification(
      titulo: titulo ?? 'Sucesso',
      mensagem: mensagem,
      tipo: 'success',
    );
  }

  /// Mostrar notificação de erro
  void showErrorNotification(String mensagem, {String? titulo}) {
    showInAppNotification(
      titulo: titulo ?? 'Erro',
      mensagem: mensagem,
      tipo: 'error',
    );
  }

  /// Mostrar notificação de aviso
  void showWarningNotification(String mensagem, {String? titulo}) {
    showInAppNotification(
      titulo: titulo ?? 'Atenção',
      mensagem: mensagem,
      tipo: 'warning',
    );
  }
}


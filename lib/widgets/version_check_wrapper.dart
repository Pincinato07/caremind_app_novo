import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/version_check_provider.dart';
import 'version_blocker_dialog.dart';
import 'version_notification_dialog.dart';

/// Widget wrapper que verifica a versão do app e mostra diálogos apropriados
/// Deve ser envolvido em telas principais ou no root do app
class VersionCheckWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const VersionCheckWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<VersionCheckWrapper> createState() => _VersionCheckWrapperState();
}

class _VersionCheckWrapperState extends ConsumerState<VersionCheckWrapper> {
  bool _hasChecked = false;
  bool _blockerShown = false;
  bool _notificationShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  Future<void> _checkVersion() async {
    if (_hasChecked) return;
    
    // Aguardar um pouco para garantir que o app está inicializado
    await Future.delayed(const Duration(milliseconds: 500));
    
    await ref.read(versionCheckProvider.notifier).checkVersion();
    _hasChecked = true;
  }

  @override
  Widget build(BuildContext context) {
    final versionState = ref.watch(versionCheckProvider);

    // Verificar se deve mostrar bloqueador
    if (versionState.shouldShowBlocker && !_blockerShown) {
      _blockerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          VersionBlockerDialog.show(
            context,
            latestVersion: versionState.latestVersion!,
          );
        }
      });
    }

    // Verificar se deve mostrar notificação
    if (versionState.shouldShowNotification && !_notificationShown) {
      _notificationShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (context.mounted) {
          // Verificar se o usuário escolheu "lembrar depois"
          final shouldRemindLater = await ref
              .read(versionCheckProvider.notifier)
              .clearRemindLater()
              .then((_) => false)
              .catchError((_) => false);

          if (!shouldRemindLater && context.mounted) {
            VersionNotificationDialog.show(
              context,
              latestVersion: versionState.latestVersion!,
            ).then((_) {
              // Quando o diálogo fechar, marcar como visto
              ref.read(versionCheckProvider.notifier).markAsSeen();
            });
          }
        }
      });
    }

    return widget.child;
  }
}

import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../core/injection/injection.dart';
import 'voice_interface_widget.dart';

/// Mixin para adicionar facilmente interface de voz em qualquer tela
///
/// Uso:
/// ```dart
/// class MinhaTela extends StatefulWidget {
///   ...
/// }
///
/// class _MinhaTelaState extends State<MinhaTela> with VoiceInterfaceMixin {
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       body: Stack(
///         children: [
///           // Seu conteúdo aqui
///           buildVoiceInterface(), // Adiciona o botão de voz
///         ],
///       ),
///     );
///   }
/// }
/// ```
mixin VoiceInterfaceMixin<T extends StatefulWidget> on State<T> {
  String? _userId;
  bool _showVoiceInterface = false;

  /// Verifica se o usuário atual é idoso e deve ter acesso à interface de voz
  bool get shouldShowVoiceInterface => _showVoiceInterface;

  /// Inicializa a interface de voz (chame no initState)
  Future<void> initVoiceInterface({bool forceShow = false}) async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        final isIdoso = perfil?.tipo?.toLowerCase() == 'idoso';

        if (mounted) {
          setState(() {
            _userId = user.id;
            _showVoiceInterface = forceShow || isIdoso;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar interface de voz: $e');
    }
  }

  /// Constrói o widget de interface de voz
  /// Retorna um widget posicionado que pode ser adicionado em um Stack
  Widget buildVoiceInterface({
    bool showAsFloatingButton = true,
    Color? buttonColor,
    Color? listeningColor,
  }) {
    if (!_showVoiceInterface || _userId == null || _userId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return VoiceInterfaceWidget(
      userId: _userId!,
      showAsFloatingButton: showAsFloatingButton,
      buttonColor: buttonColor,
      listeningColor: listeningColor,
    );
  }

  /// Wrapper para envolver o body de uma tela com interface de voz
  Widget wrapBodyWithVoiceInterface(
    Widget body, {
    bool showAsFloatingButton = true,
    Color? buttonColor,
    Color? listeningColor,
  }) {
    return Stack(
      children: [
        body,
        buildVoiceInterface(
          showAsFloatingButton: showAsFloatingButton,
          buttonColor: buttonColor,
          listeningColor: listeningColor,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/state/familiar_state.dart';
import '../core/injection/injection.dart';

/// Banner de contexto que mostra qual idoso está sendo gerenciado
/// Aparece abaixo da AppBar nas telas de gestão quando o perfil é Familiar
class BannerContextoFamiliar extends StatelessWidget {
  const BannerContextoFamiliar({super.key});

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();

    return ListenableBuilder(
      listenable: familiarState,
      builder: (context, _) {
        final idosoSelecionado = familiarState.idosoSelecionado;

        // Só mostra o banner se houver um idoso selecionado
        if (idosoSelecionado == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFFFFF9C4).withValues(alpha: 0.95),
                const Color(0xFFFFF59D).withValues(alpha: 0.95),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFF57C00),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Gerenciando dados de:',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFF57C00),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      idosoSelecionado.nome ?? 'Idoso',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



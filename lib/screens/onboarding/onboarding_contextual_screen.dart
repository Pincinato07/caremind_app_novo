import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/perfil.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../services/onboarding_service.dart';
import '../../core/feedback/feedback_service.dart';

/// Tela de onboarding contextual que aparece após o primeiro login
/// Guia o usuário para a primeira ação baseado no tipo de perfil
class OnboardingContextualScreen extends StatefulWidget {
  final Perfil perfil;

  const OnboardingContextualScreen({
    super.key,
    required this.perfil,
  });

  @override
  State<OnboardingContextualScreen> createState() =>
      _OnboardingContextualScreenState();
}

class _OnboardingContextualScreenState
    extends State<OnboardingContextualScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Marcar que o onboarding foi mostrado (com tratamento de erro)
    _markOnboardingShownSafely();
  }

  Future<void> _markOnboardingShownSafely() async {
    try {
      if (widget.perfil.id.isNotEmpty) {
        await OnboardingService.markOnboardingShown(widget.perfil.id);
      }
    } catch (e) {
      debugPrint('⚠️ Erro ao marcar onboarding mostrado: $e');
      // Não bloqueia o fluxo se falhar
    }
  }

  Future<void> _handleAction(String action) async {
    if (_isLoading) return; // Previne múltiplos cliques

    setState(() => _isLoading = true);

    try {
      // Validar perfil
      if (widget.perfil.id.isEmpty) {
        throw Exception('Perfil inválido');
      }

      // Marcar onboarding como completado
      await OnboardingService.markOnboardingCompleted(widget.perfil.id);

      if (!mounted) return;

      // Navegar para a ação escolhida
      Navigator.of(context).pop(action);
    } catch (e) {
      debugPrint('⚠️ Erro ao processar ação do onboarding: $e');

      if (mounted) {
        // Mostrar erro ao usuário de forma não intrusiva
        FeedbackService.showWarning(
          context,
          'Erro ao processar. Tente novamente.',
          duration: const Duration(seconds: 2),
        );

        // Ainda assim, permite navegar para não bloquear usuário
        Navigator.of(context).pop(action);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildIndividualOnboarding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedCard(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_liquid,
              size: 80,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Bem-vindo ao CareMind! 👋',
          style: AppTextStyles.leagueSpartan(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Que tal cadastrar seu primeiro medicamento agora?',
          style: AppTextStyles.leagueSpartan(
            fontSize: 18,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        AnimatedCard(
          index: 1,
          child: CareMindCard(
            variant: CardVariant.solid,
            onTap: _isLoading ? null : () => _handleAction('add_medicamento'),
            padding: AppSpacing.paddingLarge,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_circle,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adicionar Primeiro Medicamento',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comece a cuidar da sua saúde',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => _handleAction('skip'),
          child: Text(
            'Pular por enquanto',
            style: AppTextStyles.leagueSpartan(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFamiliarOnboarding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedCard(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.accent.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people,
              size: 80,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Bem-vindo ao CareMind! 👋',
          style: AppTextStyles.leagueSpartan(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Que tal cadastrar o primeiro idoso que você cuida?',
          style: AppTextStyles.leagueSpartan(
            fontSize: 18,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        AnimatedCard(
          index: 1,
          child: CareMindCard(
            variant: CardVariant.solid,
            onTap: _isLoading ? null : () => _handleAction('add_idoso'),
            padding: AppSpacing.paddingLarge,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_add,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cadastrar Primeiro Idoso',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comece a acompanhar a saúde',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => _handleAction('skip'),
          child: Text(
            'Pular por enquanto',
            style: AppTextStyles.leagueSpartan(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tipoPerfil = widget.perfil.tipo?.toLowerCase() ?? 'individual';
    final isFamiliar = tipoPerfil == 'familiar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLarge,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : isFamiliar
                  ? _buildFamiliarOnboarding()
                  : _buildIndividualOnboarding(),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';
import '../../core/injection/injection.dart';
import '../../services/supabase_service.dart';
import 'package:url_launcher/url_launcher.dart';

class PremiumSalesModal extends StatefulWidget {
  final VoidCallback? onSubscribeTapped;

  const PremiumSalesModal({
    super.key,
    this.onSubscribeTapped,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onSubscribeTapped}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumSalesModal(onSubscribeTapped: onSubscribeTapped),
    );
  }

  @override
  State<PremiumSalesModal> createState() => _PremiumSalesModalState();
}

class _PremiumSalesModalState extends State<PremiumSalesModal> {
  bool _isLoading = false;

  Future<void> _handleSubscribe() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final supabase = getIt<SupabaseService>().client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário não autenticado. Faça login para continuar.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Buscar ID do plano Premium do banco (com tratamento de erro)
      String? planoId;
      try {
        final planoResponse = await supabase
            .from('planos')
            .select('id')
            .eq('nome', 'Premium')
            .maybeSingle();

        if (planoResponse != null && planoResponse['id'] != null) {
          planoId = planoResponse['id'] as String;
        }
      } catch (e) {
        debugPrint('⚠️ Erro ao buscar plano Premium: $e');
        // Continua com fallback
      }
      
      // Fallback: ID do plano Premium (ed8ea704-3720-4670-9e63-1b75c3251307)
      planoId ??= 'ed8ea704-3720-4670-9e63-1b75c3251307';

      // ✅ Melhorado: Adicionar deep link de retorno para preservar contexto
      // Após pagamento, usuário retorna ao app automaticamente
      final returnUrl = 'caremind://premium/success?user_id=${user.id}';
      
      // Chama a Edge Function correta (com tratamento de erro)
      FunctionResponse response;
      try {
        response = await supabase.functions.invoke(
          'asaas-create-subscription',
          body: {
            'user_id': user.id,
            'plano_id': planoId,
            'tipo': 'individual',
            'return_url': returnUrl, // ✅ Deep link de retorno
          },
        );
      } catch (e) {
        debugPrint('⚠️ Erro ao chamar Edge Function: $e');
        throw Exception('Erro de conexão. Verifique sua internet e tente novamente.');
      }

      // Verificar se houve erro (status != 200)
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        final errorMessage = errorData?['error'] as String? ?? 
                           errorData?['message'] as String? ??
                           'Erro ao criar checkout';
        throw Exception(errorMessage);
      }

      final responseData = response.data as Map<String, dynamic>?;
      final url = responseData?['url'] as String?;
      
      if (url == null || url.isEmpty) {
        throw Exception('URL de checkout não retornada. Tente novamente.');
      }

      // Validar URL antes de abrir
      Uri? uri;
      try {
        uri = Uri.parse(url);
        if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
          throw Exception('URL de checkout inválida');
        }
      } catch (e) {
        debugPrint('⚠️ URL de checkout inválida: $url');
        throw Exception('URL de checkout inválida. Tente novamente.');
      }

      if (mounted) {
        // Fecha o modal
        Navigator.pop(context);
        
        // Abre o navegador com o link de pagamento (com tratamento de erro)
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Não foi possível abrir o link de pagamento');
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao abrir URL: $e');
          throw Exception('Não foi possível abrir o navegador. Verifique as configurações do dispositivo.');
        }

        // Callback customizado (se fornecido)
        if (widget.onSubscribeTapped != null) {
          widget.onSubscribeTapped!();
        }

        // Mostra mensagem informativa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirecionando para pagamento...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao criar checkout';
        
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (e.toString().contains('autenticado') || e.toString().contains('auth')) {
          errorMessage = 'Sessão expirada. Faça login novamente.';
        } else if (e.toString().contains('checkout') || e.toString().contains('pagamento')) {
          errorMessage = 'Erro ao processar pagamento. Tente novamente em alguns instantes.';
        } else {
          errorMessage = 'Erro: ${e.toString().replaceAll('Exception: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Fechar',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            Colors.white,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade600,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                Text(
                  'Desbloqueie o Premium',
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'Turbine seu CareMind com recursos exclusivos',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xlarge),
                _buildBenefitItem(
                  icon: Icons.document_scanner_rounded,
                  title: 'OCR Ilimitado',
                  description: 'Escaneie receitas médicas sem limites',
                  color: Colors.blue,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildBenefitItem(
                  icon: Icons.mic_rounded,
                  title: 'Integração Alexa',
                  description: 'Controle por voz com sua assistente',
                  color: Colors.cyan,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildBenefitItem(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Relatórios Completos',
                  description: 'Exporte PDFs detalhados de aderência',
                  color: Colors.red,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildBenefitItem(
                  icon: Icons.medication_rounded,
                  title: 'Medicamentos Ilimitados',
                  description: 'Cadastre quantos remédios precisar',
                  color: Colors.green,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildBenefitItem(
                  icon: Icons.family_restroom_rounded,
                  title: 'Dependentes Ilimitados',
                  description: 'Cuide de toda sua família',
                  color: Colors.purple,
                ),
                const SizedBox(height: AppSpacing.medium),
                _buildBenefitItem(
                  icon: Icons.history_rounded,
                  title: 'Histórico Completo',
                  description: 'Acesso a todo histórico de medicamentos',
                  color: Colors.orange,
                ),
                const SizedBox(height: AppSpacing.xlarge),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.shade50,
                        Colors.amber.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'R\$',
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '29',
                            style: AppTextStyles.displayLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Text(
                            ',90',
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'por mês',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubscribe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Assinar Premium',
                              style: AppTextStyles.titleLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Agora não',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 28,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

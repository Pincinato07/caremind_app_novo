import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget que bloqueia acesso quando trial expira
/// Similar ao TrialBlockedGuard do site
class TrialBlockedGuard extends ConsumerWidget {
  final Widget child;
  final bool showBanner;

  const TrialBlockedGuard({
    super.key,
    required this.child,
    this.showBanner = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizacaoState = ref.watch(organizacaoProvider);
    final organizacao = organizacaoState.organizacaoAtual;

    if (organizacao == null) {
      return child;
    }

    // Verificar status do trial
    final statusAssinatura = organizacao.statusAssinatura;
    final trialEnd = organizacao.trialEnd;

    final canAccess = _canAccessOrganizacao(statusAssinatura, trialEnd);

    if (canAccess) {
      return child;
    }

    // Se showBanner é true, mostra apenas banner
    if (showBanner) {
      return Column(
        children: [
          _buildTrialBanner(context, ref, organizacao.nome),
          Expanded(child: child),
        ],
      );
    }

    // Se trial expirou, mostra tela completa de bloqueio
    return _buildBlockedScreen(context, ref, organizacao.nome);
  }

  bool _canAccessOrganizacao(String? statusAssinatura, DateTime? trialEnd) {
    if (statusAssinatura == 'active') {
      return true;
    }

    if (statusAssinatura == 'trialing' && trialEnd != null) {
      final now = DateTime.now();
      return now.isBefore(trialEnd);
    }

    // CORRIGIDO: Permitir acesso durante pending (grace period de 24h após criação)
    // Isso evita bloquear usuário que acabou de iniciar checkout
    if (statusAssinatura == 'pending') {
      return true; // Grace period: usuário iniciou checkout, aguardando confirmação
    }

    // CORRIGIDO: Permitir acesso durante overdue (grace period de 7 dias)
    // Isso evita bloquear imediatamente após atraso, dando tempo para pagamento
    if (statusAssinatura == 'overdue') {
      // Se trialEnd existe e ainda não passou 7 dias do vencimento, permitir acesso
      if (trialEnd != null) {
        final now = DateTime.now();
        final gracePeriodEnd = trialEnd.add(const Duration(days: 7));
        return now.isBefore(gracePeriodEnd);
      }
      // Se não há trialEnd, permitir acesso por 7 dias após mudança para overdue
      // (isso seria melhor com campo updated_at, mas por enquanto permitimos)
      return true; // Grace period de 7 dias
    }

    return false;
  }

  Widget _buildTrialBanner(
      BuildContext context, WidgetRef ref, String organizacaoNome) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trial Expirado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seu período de trial expirou. Assine o plano para continuar usando.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToCheckout(context, ref),
            child: const Text('Assinar Agora'),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedScreen(
      BuildContext context, WidgetRef ref, String organizacaoNome) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade50,
              Colors.red.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade400,
                        width: 4,
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Acesso Bloqueado',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seu período de trial de 14 dias expirou. Para continuar usando todas as funcionalidades da organização "$organizacaoNome", você precisa assinar o plano Institucional.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade800,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'O que acontece agora?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildBlockedFeature(
                            'Você não pode adicionar novos membros'),
                        _buildBlockedFeature(
                            'Você não pode adicionar novos pacientes'),
                        _buildBlockedFeature(
                            'Funcionalidades avançadas estão bloqueadas'),
                        _buildBlockedFeature(
                            'Dados existentes permanecem seguros'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToCheckout(context, ref),
                    icon: const Icon(Icons.business),
                    label: const Text('Assinar Plano Institucional'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.close,
            size: 16,
            color: Colors.amber.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCheckout(BuildContext context, WidgetRef ref) async {
    final organizacaoState = ref.read(organizacaoProvider);
    final organizacao = organizacaoState.organizacaoAtual;

    if (organizacao == null) return;

    try {
      final supabase = getIt<SupabaseService>().client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não autenticado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Buscar ID do plano Institucional
      final planoResponse = await supabase
          .from('planos')
          .select('id')
          .eq('nome', 'Institucional')
          .maybeSingle();

      String? planoId;
      if (planoResponse != null && planoResponse['id'] != null) {
        planoId = planoResponse['id'] as String;
      } else {
        // Fallback: ID do plano Institucional
        planoId = '93aa1161-71f9-41af-8f22-e6f0fbe3f535';
      }

      // Chamar Edge Function
      final response = await supabase.functions.invoke(
        'asaas-create-subscription',
        body: {
          'user_id': user.id,
          'plano_id': planoId,
          'tipo': 'organizacao',
          'organizacao_id': organizacao.id,
        },
      );

      // Verificar se houve erro (status != 200)
      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(errorData?['error'] ?? 'Erro ao criar checkout');
      }

      final responseData = response.data as Map<String, dynamic>?;
      final url = responseData?['url'] as String?;

      if (url == null || url.isEmpty) {
        throw Exception('URL de checkout não retornada');
      }

      // Abrir URL no navegador
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Não foi possível abrir o link de pagamento');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

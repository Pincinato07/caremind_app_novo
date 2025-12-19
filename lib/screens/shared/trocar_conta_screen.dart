import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/account_manager_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../core/state/familiar_state.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../auth/auth_shell.dart';

class TrocarContaScreen extends StatefulWidget {
  const TrocarContaScreen({super.key});

  @override
  State<TrocarContaScreen> createState() => _TrocarContaScreenState();
}

class _TrocarContaScreenState extends State<TrocarContaScreen> {
  final AccountManagerService _accountManager = AccountManagerService();
  final SupabaseService _supabaseService = getIt<SupabaseService>();

  List<AccountInfo> _accounts = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _accountManager.getSavedAccounts();
      final currentUser = _supabaseService.currentUser;

      setState(() {
        _accounts = accounts;
        _currentUserId = currentUser?.id;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchToAccount(AccountInfo account) async {
    if (_isSwitching || account.userId == _currentUserId) return;

    setState(() {
      _isSwitching = true;
    });

    try {
      // Fazer logout da conta atual
      await _supabaseService.signOut();

      // Redirecionar para tela de login
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthShell(initialMode: AuthMode.login),
        ),
        (route) => false,
      );

      // Mostrar mensagem informando que precisa fazer login novamente
      FeedbackService.showInfo(
        context,
        'Faça login com ${account.email}',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSwitching = false;
      });

      FeedbackService.showError(context, ErrorHandler.toAppException(e));
    }
  }

  Future<void> _removeAccount(AccountInfo account) async {
    final isCurrentAccount = account.userId == _currentUserId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade400, size: 24),
            const SizedBox(width: 12),
            const Expanded(child: Text('Remover Conta')),
          ],
        ),
        content: Text(
          isCurrentAccount
              ? 'Deseja remover ${account.email} da lista de contas? Você será deslogado automaticamente.'
              : 'Deseja remover ${account.email} da lista de contas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _accountManager.removeAccount(account.userId);

      // Se for a conta atual, fazer logout também
      if (isCurrentAccount) {
        await _supabaseService.signOut();

        if (!mounted) return;

        // Redirecionar para tela de login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthShell(initialMode: AuthMode.login),
          ),
          (route) => false,
        );

        FeedbackService.showSuccess(
            context, 'Conta removida e logout realizado');
      } else {
        await _loadAccounts();

        if (mounted) {
          FeedbackService.showSuccess(context, 'Conta removida da lista');
        }
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    }
  }

  Future<void> _addNewAccount() async {
    // Fazer logout e ir para tela de login
    await _supabaseService.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const AuthShell(initialMode: AuthMode.login),
      ),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 12),
            const Expanded(child: Text('Fazer Logout')),
          ],
        ),
        content: const Text(
            'Deseja sair da conta atual? Você precisará fazer login novamente para acessar o app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() {
        _isSwitching = true;
      });

      // Fazer logout
      await _supabaseService.signOut();

      if (!mounted) return;

      // Redirecionar para tela de login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const AuthShell(initialMode: AuthMode.login),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSwitching = false;
      });

      FeedbackService.showError(context, ErrorHandler.toAppException(e));
    }
  }

  Widget _buildAccountCard(AccountInfo account, int index) {
    final isCurrent = account.userId == _currentUserId;

    return AnimatedCard(
      index: index,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isCurrent || _isSwitching
                ? null
                : () => _switchToAccount(account),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: isCurrent
                    ? Border.all(
                        color: const Color(0xFF0400BA).withValues(alpha: 0.5),
                        width: 2,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar com indicador de conta atual
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF0400BA)
                                  : Colors.white.withValues(alpha: 0.3),
                              width: isCurrent ? 2.5 : 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: _buildAvatar(account),
                          ),
                        ),
                        if (isCurrent)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0400BA),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Informações da conta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account.nome ?? account.email,
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0400BA)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF0400BA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Atual',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0400BA),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  account.email,
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (account.tipo != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _getTipoIcon(account.tipo!),
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getTipoLabel(account.tipo!),
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Botões de ação
                    if (!_isSwitching) ...[
                      const SizedBox(width: 8),
                      // Botão remover
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _removeAccount(account),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade300,
                            ),
                          ),
                        ),
                      ),
                      if (!isCurrent) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ],
                    ] else if (isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AccountInfo account) {
    try {
      if (account.fotoUrl != null && account.fotoUrl!.isNotEmpty) {
        return Hero(
          tag: 'profile_image_${account.userId}',
          child: Image.network(
            account.fotoUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('⚠️ Erro ao carregar foto da conta: $error');
              return _buildDefaultAvatar();
            },
          ),
        );
      } else {
        return Hero(
          tag: 'profile_image_${account.userId}',
          child: _buildDefaultAvatar(),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao construir avatar da conta: $e');
      debugPrint('Stack trace: $stackTrace');
      return _buildDefaultAvatar();
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white.withValues(alpha: 0.1),
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'individual':
        return Icons.person_outline;
      case 'familiar':
        return Icons.family_restroom;
      case 'idoso':
        return Icons.elderly;
      default:
        return Icons.account_circle_outlined;
    }
  }

  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'individual':
        return 'Individual';
      case 'familiar':
        return 'Familiar';
      case 'idoso':
        return 'Idoso';
      default:
        return tipo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos;

    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Trocar de Conta',
        isFamiliar: isFamiliar,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                padding: AppSpacing.paddingScreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header melhorado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gerenciar Contas',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Toque em uma conta para fazer login',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Lista de contas
                    if (_accounts.isEmpty)
                      _buildEmptyState()
                    else
                      ..._accounts.asMap().entries.map((entry) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key < _accounts.length - 1 ? 12 : 0,
                          ),
                          child: _buildAccountCard(entry.value, entry.key),
                        );
                      }),

                    if (_accounts.isNotEmpty) const SizedBox(height: 24),

                    // Botões de ação
                    if (_accounts.isNotEmpty) ...[
                      // Botão adicionar nova conta
                      AnimatedCard(
                        index: _accounts.length + 1,
                        child: CareMindCard(
                          variant: CardVariant.glass,
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isSwitching ? null : _addNewAccount,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Adicionar Nova Conta',
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botão de logout
                    if (_currentUserId != null)
                      AnimatedCard(
                        index: _accounts.length + 2,
                        child: CareMindCard(
                          variant: CardVariant.glass,
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isSwitching ? null : _logout,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.logout_rounded,
                                        color: Colors.red.shade300,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Fazer Logout',
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_currentUserId != null) const SizedBox(height: 16),

                    // Dica de uso
                    if (_accounts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Toque no ícone de lixeira para remover uma conta da lista',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhuma conta salva',
              style: AppTextStyles.leagueSpartan(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione uma conta para começar',
              style: AppTextStyles.leagueSpartan(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

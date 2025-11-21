import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/account_manager_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faça login com ${account.email}'),
          backgroundColor: const Color(0xFF0400BA),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSwitching = false;
      });

      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao trocar de conta: $e';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAccount(AccountInfo account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Conta'),
        content: Text('Deseja remover ${account.email} da lista de contas?'),
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
      await _loadAccounts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta removida da lista'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover conta: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Selecione uma conta',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toque em uma conta para fazer login',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Lista de contas
                    if (_accounts.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_circle_outlined,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma conta salva',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._accounts.map((account) {
                        final isCurrent = account.userId == _currentUserId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassCard(
                            padding: EdgeInsets.zero,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isCurrent || _isSwitching
                                    ? null
                                    : () => _switchToAccount(account),
                                onLongPress: isCurrent
                                    ? null
                                    : () => _removeAccount(account),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.2),
                                          border: Border.all(
                                            color: isCurrent
                                                ? const Color(0xFF0400BA)
                                                : Colors.white.withValues(alpha: 0.3),
                                            width: isCurrent ? 2 : 1,
                                          ),
                                        ),
                                        child: account.fotoUrl != null &&
                                                account.fotoUrl!.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  account.fotoUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 28,
                                                    );
                                                  },
                                                ),
                                              )
                                            : Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Informações
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    account.nome ?? account.email,
                                                    style: GoogleFonts.leagueSpartan(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isCurrent)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0400BA),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'Atual',
                                                      style: GoogleFonts.leagueSpartan(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              account.email,
                                              style: GoogleFonts.leagueSpartan(
                                                fontSize: 13,
                                                color: Colors.white.withValues(alpha: 0.7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (account.tipo != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                account.tipo == 'individual'
                                                    ? 'Individual'
                                                    : account.tipo == 'familiar'
                                                        ? 'Familiar'
                                                        : account.tipo == 'idoso'
                                                            ? 'Idoso'
                                                            : account.tipo!,
                                                style: GoogleFonts.leagueSpartan(
                                                  fontSize: 11,
                                                  color: Colors.white.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!isCurrent && !_isSwitching)
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),

                    const SizedBox(height: 24),

                    // Botão adicionar nova conta
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isSwitching ? null : _addNewAccount,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Adicionar Nova Conta',
                                  style: GoogleFonts.leagueSpartan(
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

                    const SizedBox(height: 16),

                    // Aviso sobre remover
                    if (_accounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'Mantenha pressionado uma conta para removê-la',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}


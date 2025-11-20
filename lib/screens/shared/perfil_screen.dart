// lib/screens/perfil_screen.dart

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/lgpd_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/compromisso_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigation.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../auth/auth_shell.dart';
import '../lgpd/termos_privacidade_screen.dart';
import '../integracoes/integracoes_screen.dart';
import 'configuracoes_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _isLoggingOut = false;
  bool _isExporting = false;
  bool _isDeleting = false;

  Future<void> _handleLogout() async {
    // Diálogo de confirmação
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Tem certeza que deseja sair da sua conta?'),
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

    setState(() => _isLoggingOut = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      await supabaseService.signOut();

      if (!mounted) return;

      // Navegar para AuthShell removendo todas as rotas anteriores
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoggingOut = false);

      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao fazer logout: $e';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header com gradiente
              Container(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFA8B8FF).withValues(alpha: 0.3),
                      const Color(0xFF9B7EFF).withValues(alpha: 0.3),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Meu Perfil',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gerencie suas informações',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Cards de opções
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                children: [
                  _buildProfileButton(
                    context,
                    icon: Icons.edit,
                    text: 'Editar Perfil',
                    onTap: () {
                      // Navegar para tela de edição de perfil
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.settings,
                    text: 'Configurações',
                    onTap: () {
                      Navigator.push(
                        context,
                        AppNavigation.smoothRoute(
                          const ConfiguracoesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.camera_alt,
                    text: 'Integrações (OCR)',
                    onTap: () {
                      Navigator.push(
                        context,
                        AppNavigation.smoothRoute(
                          const IntegracoesScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.help_outline,
                    text: 'Ajuda e Suporte',
                    onTap: () {
                      // Navegar para tela de ajuda
                    },
                  ),
                  const SizedBox(height: 24),
                  // Divisor LGPD
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.primary.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'LGPD - Privacidade',
                          style: GoogleFonts.leagueSpartan(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: colors.primary.withOpacity(0.3))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.description_outlined,
                    text: 'Termos de Uso',
                    onTap: () {
                      Navigator.push(
                        context,
                        AppNavigation.smoothRoute(
                          const TermosPrivacidadeScreen(showTerms: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.privacy_tip_outlined,
                    text: 'Política de Privacidade',
                    onTap: () {
                      Navigator.push(
                        context,
                        AppNavigation.smoothRoute(
                          const TermosPrivacidadeScreen(showTerms: false),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.download_outlined,
                    text: 'Exportar Meus Dados',
                    onTap: _isExporting ? null : _handleExportData,
                    isLoading: _isExporting,
                  ),
                  const SizedBox(height: 16),
                  _buildProfileButton(
                    context,
                    icon: Icons.delete_outline,
                    text: 'Excluir Conta',
                    isDestructive: true,
                    onTap: _isDeleting ? null : _handleDeleteAccount,
                    isLoading: _isDeleting,
                  ),
                  const SizedBox(height: 24),
                  _buildProfileButton(
                    context,
                    icon: Icons.logout,
                    text: 'Sair',
                    isLogout: true,
                    isLoading: _isLoggingOut,
                    onTap: _isLoggingOut ? null : _handleLogout,
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _handleExportData() async {
    setState(() => _isExporting = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      final lgpdService = LgpdService(
        supabaseService,
        getIt<MedicamentoService>(),
        getIt<CompromissoService>(),
      );

      final jsonData = await lgpdService.exportUserDataAsJson(user.id);

      // Compartilhar arquivo JSON
      await Share.share(
        jsonData,
        subject: 'Meus Dados - CareMind',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados exportados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao exportar dados: $e';
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    // Diálogo de confirmação crítico
    final confirm = await AppNavigation.showAppDialog<bool>(
      context: context,
      title: '⚠️ Excluir Conta Permanentemente',
      message:
          'Esta ação não pode ser desfeita. Todos os seus dados serão excluídos permanentemente:\n\n'
          '• Todos os medicamentos\n'
          '• Todos os compromissos\n'
          '• Dados do perfil\n\n'
          'Tem certeza absoluta?',
      confirmText: 'Sim, Excluir',
      cancelText: 'Cancelar',
      isDestructive: true,
    );

    if (confirm != true) return;

    // Segunda confirmação
    final confirm2 = await AppNavigation.showAppDialog<bool>(
      context: context,
      title: 'Última Confirmação',
      message:
          'Para confirmar, digite "EXCLUIR" (sem aspas) na caixa abaixo.\n\n'
          'Esta é sua última chance de cancelar.',
      confirmText: 'Confirmar Exclusão',
      cancelText: 'Cancelar',
      isDestructive: true,
    );

    if (confirm2 != true) return;

    setState(() => _isDeleting = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      final lgpdService = LgpdService(
        supabaseService,
        getIt<MedicamentoService>(),
        getIt<CompromissoService>(),
      );

      // Excluir dados
      await lgpdService.deleteUserData(user.id);

      // Fazer logout
      await supabaseService.signOut();

      if (!mounted) return;

      // Navegar para tela de login
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );

      // Mostrar mensagem final
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluída com sucesso'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDeleting = false);

      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao excluir conta: $e';
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildProfileButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool isLogout = false,
    bool isDestructive = false,
    bool isLoading = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: (isLogout || isDestructive)
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
        color: (isLogout || isDestructive) ? Colors.red.withValues(alpha: 0.2) : null,
        borderRadius: AppBorderRadius.largeAll,
        border: Border.all(
          color: (isLogout || isDestructive)
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ((isLogout || isDestructive) ? colors.error : colors.primary).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBorderRadius.largeAll,
          child: Opacity(
            opacity: isLoading ? 0.6 : 1.0,
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isLogout || isDestructive)
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: (isLogout || isDestructive) ? Colors.red.shade300 : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 16,
                      color: (isLogout || isDestructive) ? Colors.red.shade300 : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: (isLogout || isDestructive) ? Colors.red.shade300 : Colors.white.withValues(alpha: 0.6),
                  ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

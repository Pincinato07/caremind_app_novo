import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../models/perfil.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/caremind_app_bar.dart';
import 'adicionar_idoso_form.dart';
import 'editar_idoso_form.dart';

class FamiliaresScreen extends StatefulWidget {
  const FamiliaresScreen({super.key});

  @override
  State<FamiliaresScreen> createState() => _FamiliaresScreenState();
}

class _FamiliaresScreenState extends State<FamiliaresScreen> {
  List<Perfil> _idosos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdosos();
  }

  Future<void> _loadIdosos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        // Carregar idosos e atualizar o FamiliarState
        await familiarState.carregarIdosos(user.id);
        setState(() {
          _idosos = familiarState.idososVinculados;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Usuário não encontrado';
          _isLoading = false;
        });
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao carregar idosos: $error';
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _adicionarIdoso() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const AdicionarIdosoForm(),
    );
    
    if (result == true) {
      _loadIdosos();
    }
  }

  Future<void> _editarIdoso(Perfil idoso) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditarIdosoForm(idoso: idoso),
    );
    
    if (result == true) {
      _loadIdosos();
    }
  }

  Future<void> _desvincularIdoso(Perfil idoso) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular Idoso'),
        content: Text(
          'Tem certeza que deseja desvincular ${idoso.nome ?? 'este idoso'}? '
          'O idoso continuará existindo, mas você não terá mais acesso aos seus dados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
            ),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabaseService = getIt<SupabaseService>();
      await supabaseService.desvincularIdoso(idoso.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${idoso.nome ?? 'Idoso'} desvinculado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIdosos();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Erro ao desvincular idoso: $error',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removerIdoso(Perfil idoso) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Idoso'),
        content: Text(
          'ATENÇÃO: Esta ação é irreversível!\n\n'
          'Tem certeza que deseja remover completamente ${idoso.nome ?? 'este idoso'}? '
          'Todos os dados do idoso serão perdidos permanentemente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remover Permanentemente'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final supabaseService = getIt<SupabaseService>();
      await supabaseService.removerIdoso(idoso.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${idoso.nome ?? 'Idoso'} removido com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        _loadIdosos();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Erro ao remover idoso: $error',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOptionsMenu(Perfil idoso) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(context);
                  _editarIdoso(idoso);
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.orange),
                title: const Text('Desvincular'),
                subtitle: const Text('Remove o vínculo, mantém o idoso'),
                onTap: () {
                  Navigator.pop(context);
                  _desvincularIdoso(idoso);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Remover Permanentemente'),
                subtitle: const Text('Remove o idoso e todos os dados'),
                onTap: () {
                  Navigator.pop(context);
                  _removerIdoso(idoso);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Família',
        isFamiliar: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GlassCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Erro ao carregar idosos',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.leagueSpartan(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppPrimaryButton(
                              label: 'Tentar novamente',
                              onPressed: _loadIdosos,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _idosos.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GlassCard(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.family_restroom,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Gerencie sua Família',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Visualize os idosos vinculados à sua conta e adicione novos membros diretamente',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            GlassCard(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.groups_rounded,
                                        size: 32,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Seus Idosos',
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Nenhum idoso vinculado ainda',
                                                style: AppTextStyles.leagueSpartan(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Use o botão abaixo para adicionar o primeiro idoso',
                                                style: AppTextStyles.leagueSpartan(
                                                  fontSize: 14,
                                                  color: Colors.white.withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.person_add_disabled,
                                          color: Colors.white.withValues(alpha: 0.6),
                                          size: 32,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppPrimaryButton(
                              label: 'Adicionar Idoso',
                              onPressed: _adicionarIdoso,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadIdosos,
                        backgroundColor: Colors.white,
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Idosos Vinculados',
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${_idosos.length} idoso(s) vinculado(s)',
                                      style: AppTextStyles.leagueSpartan(
                                        fontSize: 16,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final idoso = _idosos[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    child: _buildIdosoCard(idoso, familiarState),
                                  );
                                },
                                childCount: _idosos.length,
                              ),
                            ),
                            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.bottomNavBarPadding)),
                          ],
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarIdoso,
        backgroundColor: const AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          'Adicionar Idoso',
          style: AppTextStyles.leagueSpartan(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildIdosoCard(Perfil idoso, FamiliarState familiarState) {
    final isSelected = familiarState.idosoSelecionado?.id == idoso.id;
    
    return GlassCard(
      onTap: () {
        // Selecionar o idoso ao tocar no card
        familiarState.selecionarIdoso(idoso);
        // Mostrar menu de opções
        _showOptionsMenu(idoso);
      },
      borderColor: isSelected ? Colors.green.withValues(alpha: 0.6) : null,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idoso.nome ?? 'Idoso',
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Idoso',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _showOptionsMenu(idoso),
            tooltip: 'Opções',
          ),
        ],
      ),
    );
  }
}

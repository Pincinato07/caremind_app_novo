import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../services/historico_eventos_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/banner_contexto_familiar.dart';
import 'add_edit_compromisso_form.dart';

class GestaoCompromissosScreen extends StatefulWidget {
  final String? idosoId; // Para familiar gerenciar compromissos do idoso
  final bool embedded; // Se true, não mostra AppScaffoldWithWaves nem SliverAppBar

  const GestaoCompromissosScreen({
    super.key,
    this.idosoId,
    this.embedded = false,
  });

  @override
  State<GestaoCompromissosScreen> createState() => _GestaoCompromissosScreenState();
}

class _GestaoCompromissosScreenState extends State<GestaoCompromissosScreen> {
  List<Map<String, dynamic>> _compromissos = [];
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCompromissos();
    
    // Escutar mudanças no FamiliarState para recarregar quando o idoso mudar
    final familiarState = getIt<FamiliarState>();
    familiarState.addListener(_onFamiliarStateChanged);
  }

  @override
  void dispose() {
    final familiarState = getIt<FamiliarState>();
    familiarState.removeListener(_onFamiliarStateChanged);
    super.dispose();
  }

  void _onFamiliarStateChanged() {
    // Recarregar compromissos quando o idoso selecionado mudar
    if (mounted && widget.idosoId == null) {
      _loadCompromissos();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user != null) {
        final perfil = await supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _perfilTipo = perfil.tipo?.toLowerCase();
          });
        }
      }
    } catch (e) {
      // Ignora erro
    }
  }

  bool get _isIdoso => _perfilTipo == 'idoso';
  bool get _isFamiliar {
    final familiarState = getIt<FamiliarState>();
    return familiarState.hasIdosos && widget.idosoId == null;
  }

  Future<void> _loadCompromissos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final compromissoService = getIt<CompromissoService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        // Prioridade: widget.idosoId > FamiliarState.idosoSelecionado > user.id
        final familiarState = getIt<FamiliarState>();
        final targetId = widget.idosoId ?? 
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
                ? familiarState.idosoSelecionado!.id 
                : user.id);
        
        final compromissos = await compromissoService.getCompromissos(targetId);
        
        setState(() {
          _compromissos = compromissos;
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
          : 'Erro ao carregar compromissos: $error';
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleConcluido(Map<String, dynamic> compromisso) async {
    try {
      final compromissoService = getIt<CompromissoService>();
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      
      final compromissoId = compromisso['id'] as int;
      final concluido = compromisso['concluido'] as bool? ?? false;
      final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
      final novoEstado = !concluido;
      
      // Determinar o perfil_id do idoso (não do familiar)
      final user = supabaseService.currentUser;
      if (user == null) return;
      
      // Se for familiar gerenciando idoso, usar o id do idoso; senão usar o user.id
      final targetPerfilId = widget.idosoId ?? 
          (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
              ? familiarState.idosoSelecionado!.id 
              : user.id);
      
      // Atualizar o compromisso
      await compromissoService.toggleConcluido(compromissoId, novoEstado);
      
      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': targetPerfilId,
          'tipo_evento': novoEstado ? 'compromisso_realizado' : 'compromisso_desmarcado',
          'data_hora': DateTime.now().toIso8601String(),
          'descricao': novoEstado 
              ? 'Compromisso "$titulo" marcado como realizado'
              : 'Compromisso "$titulo" desmarcado',
          'referencia_id': compromissoId.toString(),
          'tipo_referencia': 'compromisso',
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }
      
      _loadCompromissos();
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao atualizar compromisso: $error';
      _showError(errorMessage);
    }
  }

  Future<void> _deleteCompromisso(Map<String, dynamic> compromisso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir o compromisso "${compromisso['titulo'] ?? 'Compromisso'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final compromissoService = getIt<CompromissoService>();
        await compromissoService.deleteCompromisso(compromisso['id'] as int);
        _loadCompromissos();
        _showSuccess('Compromisso excluído com sucesso');
      } catch (error) {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao excluir compromisso: $error';
        _showError(errorMessage);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos && widget.idosoId == null;
    
    final content = CustomScrollView(
      slivers: [
        // Banner de contexto para perfil familiar
        if (isFamiliar)
          SliverToBoxAdapter(
            child: const BannerContextoFamiliar(),
          ),
        // Header moderno - apenas se não estiver embedded
        if (!widget.embedded)
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Compromissos',
                style: GoogleFonts.leagueSpartan(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFA8B8FF),
                      Color(0xFF9B7EFF),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.calendar_today, size: 48, color: Colors.white),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadCompromissos,
              ),
            ],
          ),
        SliverToBoxAdapter(child: _buildBody()),
      ],
    );

    if (widget.embedded) {
      // Modo embedded: retorna apenas o conteúdo, sem AppScaffoldWithWaves
      return content;
    }

    // Modo standalone: retorna com AppScaffoldWithWaves e FAB
    return AppScaffoldWithWaves(
      body: content,
      floatingActionButton: _isIdoso
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                // Obter idosoId do FamiliarState se não foi fornecido via widget
                final familiarState = getIt<FamiliarState>();
                final idosoId = widget.idosoId ?? 
                    (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEditCompromissoForm(idosoId: idosoId),
                  ),
                );
                if (result == true) {
                  _loadCompromissos();
                }
              },
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0400BA),
              elevation: 4,
              icon: const Icon(Icons.add),
              label: Text(
                'Adicionar',
                style: GoogleFonts.leagueSpartan(
                  color: const Color(0xFF0400BA),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Carregando compromissos...',
                style: GoogleFonts.leagueSpartan(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar compromissos',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.leagueSpartan(
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCompromissos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0400BA),
                ),
                child: Text(
                  'Tentar novamente',
                  style: GoogleFonts.leagueSpartan(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_compromissos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.calendar_today, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nenhum compromisso encontrado',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0400B9)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isIdoso
                          ? 'Seus compromissos aparecerão aqui'
                          : 'Toque no botão "+" para adicionar seu primeiro compromisso',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, const Color(0xFF0400B9).withOpacity(0.02)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF0400B9).withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0400B9).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0400B9), Color(0xFF0600E0)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total de Compromissos',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_compromissos.length} compromisso(s)',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Seus Compromissos',
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...(_compromissos.map((compromisso) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildCompromissoCard(compromisso),
            ))),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildCompromissoCard(Map<String, dynamic> compromisso) {
    final concluido = compromisso['concluido'] as bool? ?? false;
    final dataHora = DateTime.parse(compromisso['data_hora'] as String);
    final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
    final descricao = compromisso['descricao'] as String?;
    final isPassado = dataHora.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: concluido
                    ? Colors.green.shade300
                    : isPassado
                        ? Colors.red.shade300
                        : Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0400B9).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isIdoso
              ? () => _toggleConcluido(compromisso)
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        // Obter idosoId do FamiliarState se não foi fornecido via widget
                        final familiarState = getIt<FamiliarState>();
                        final idosoId = widget.idosoId ?? 
                            (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                        return AddEditCompromissoForm(compromisso: compromisso, idosoId: idosoId);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadCompromissos();
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: concluido
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : isPassado
                                  ? [Colors.red.shade400, Colors.red.shade600]
                                  : [const Color(0xFF0400B9), const Color(0xFF0600E0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        concluido ? Icons.check_circle : Icons.calendar_today,
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
                            titulo,
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: concluido
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white,
                              decoration: concluido ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${dataHora.day}/${dataHora.month}/${dataHora.year} às ${dataHora.hour.toString().padLeft(2, '0')}:${dataHora.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 14,
                              color: concluido
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isIdoso)
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'toggle':
                              _toggleConcluido(compromisso);
                              break;
                            case 'delete':
                              _deleteCompromisso(compromisso);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  concluido ? Icons.undo : Icons.check,
                                  size: 20,
                                  color: concluido ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Text(concluido ? 'Marcar como pendente' : 'Marcar como concluído'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Excluir', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (descricao != null && descricao.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      descricao,
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
                
                // Botão de ação rápida para familiares marcarem como concluído
                if (_isFamiliar && !concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluido(compromisso),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Realizado',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Botão para desmarcar (se já estiver concluído e for familiar)
                if (_isFamiliar && concluido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade400,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _toggleConcluido(compromisso),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.undo, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Pendente',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


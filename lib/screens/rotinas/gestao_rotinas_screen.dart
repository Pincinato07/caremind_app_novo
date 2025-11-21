import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/rotina_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/state/familiar_state.dart';
import '../../services/historico_eventos_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/banner_contexto_familiar.dart';
import 'add_edit_rotina_form.dart';

class GestaoRotinasScreen extends StatefulWidget {
  final String? idosoId; // Para familiar gerenciar rotinas do idoso
  final bool embedded; // Se true, não mostra AppScaffoldWithWaves nem SliverAppBar

  const GestaoRotinasScreen({
    super.key,
    this.idosoId,
    this.embedded = false,
  });

  @override
  State<GestaoRotinasScreen> createState() => _GestaoRotinasScreenState();
}

class _GestaoRotinasScreenState extends State<GestaoRotinasScreen> {
  List<Map<String, dynamic>> _rotinas = [];
  bool _isLoading = true;
  String? _error;
  String? _perfilTipo;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadRotinas();
    
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
    // Recarregar rotinas quando o idoso selecionado mudar
    if (mounted && widget.idosoId == null) {
      _loadRotinas();
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

  Future<void> _loadRotinas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final rotinaService = getIt<RotinaService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        // Prioridade: widget.idosoId > FamiliarState.idosoSelecionado > user.id
        final familiarState = getIt<FamiliarState>();
        final targetId = widget.idosoId ?? 
            (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
                ? familiarState.idosoSelecionado!.id 
                : user.id);
        
        final rotinas = await rotinaService.getRotinas(targetId);
        
        setState(() {
          _rotinas = rotinas;
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
          : 'Erro ao carregar rotinas: $error';
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleConcluida(Map<String, dynamic> rotina) async {
    try {
      final rotinaService = getIt<RotinaService>();
      final supabaseService = getIt<SupabaseService>();
      final familiarState = getIt<FamiliarState>();
      
      final rotinaId = rotina['id'] as int;
      final concluida = rotina['concluida'] as bool? ?? false;
      final titulo = rotina['titulo'] as String? ?? 'Rotina';
      final novoEstado = !concluida;
      
      // Determinar o perfil_id do idoso (não do familiar)
      final user = supabaseService.currentUser;
      if (user == null) return;
      
      // Se for familiar gerenciando idoso, usar o id do idoso; senão usar o user.id
      final targetPerfilId = widget.idosoId ?? 
          (familiarState.hasIdosos && familiarState.idosoSelecionado != null 
              ? familiarState.idosoSelecionado!.id 
              : user.id);
      
      // Atualizar a rotina
      await rotinaService.toggleConcluida(rotinaId, novoEstado);
      
      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': targetPerfilId,
          'tipo_evento': novoEstado ? 'rotina_concluida' : 'rotina_desmarcada',
          'data_hora': DateTime.now().toIso8601String(),
          'descricao': novoEstado 
              ? 'Rotina "$titulo" marcada como concluída'
              : 'Rotina "$titulo" desmarcada',
          'referencia_id': rotinaId.toString(),
          'tipo_referencia': 'rotina',
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }
      
      _loadRotinas();
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao atualizar rotina: $error';
      _showError(errorMessage);
    }
  }

  Future<void> _deleteRotina(Map<String, dynamic> rotina) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir a rotina "${rotina['titulo'] ?? 'Rotina'}"?'),
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
        final rotinaService = getIt<RotinaService>();
        await rotinaService.deleteRotina(rotina['id'] as int);
        _loadRotinas();
        _showSuccess('Rotina excluída com sucesso');
      } catch (error) {
        final errorMessage = error is AppException
            ? error.message
            : 'Erro ao excluir rotina: $error';
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
                'Rotinas',
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
                  child: Icon(Icons.schedule, size: 48, color: Colors.white),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadRotinas,
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
                    builder: (context) => AddEditRotinaForm(idosoId: idosoId),
                  ),
                );
                if (result == true) {
                  _loadRotinas();
                }
              },
              backgroundColor: const Color(0xFF0400B9),
              elevation: 4,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Adicionar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        height: 300,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0400B9)),
              SizedBox(height: 16),
              Text('Carregando rotinas...', style: TextStyle(color: Colors.grey, fontSize: 16)),
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
              Text('Erro ao carregar rotinas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade600)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadRotinas,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0400B9), foregroundColor: Colors.white),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_rotinas.isEmpty) {
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
                      const Color(0xFF0400B9).withOpacity(0.1),
                      const Color(0xFF0600E0).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF0400B9).withOpacity(0.2), width: 1),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0400B9), Color(0xFF0600E0)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.schedule, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Nenhuma rotina encontrada',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0400B9)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isIdoso
                          ? 'Suas rotinas aparecerão aqui'
                          : 'Toque no botão "+" para adicionar sua primeira rotina',
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
                      const Text('Total de Rotinas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('${_rotinas.length} rotina(s)', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: const Text('Suas Rotinas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        const SizedBox(height: 16),
        ...(_rotinas.map((rotina) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: _buildRotinaCard(rotina),
            ))),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildRotinaCard(Map<String, dynamic> rotina) {
    final concluida = rotina['concluida'] as bool? ?? false;
    final titulo = rotina['titulo'] as String? ?? 'Rotina';
    final descricao = rotina['descricao'] as String?;
    final horario = rotina['horario'] as String?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF0400B9).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: concluida
              ? Colors.green.shade300
              : const Color(0xFF0400B9).withOpacity(0.1),
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
              ? () => _toggleConcluida(rotina)
              : () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        // Obter idosoId do FamiliarState se não foi fornecido via widget
                        final familiarState = getIt<FamiliarState>();
                        final idosoId = widget.idosoId ?? 
                            (familiarState.hasIdosos ? familiarState.idosoSelecionado?.id : null);
                        return AddEditRotinaForm(rotina: rotina, idosoId: idosoId);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadRotinas();
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
                          colors: concluida
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [const Color(0xFF0400B9), const Color(0xFF0600E0)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        concluida ? Icons.check_circle : Icons.schedule,
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: concluida ? Colors.grey.shade600 : Colors.black87,
                              decoration: concluida ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (horario != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Horário: $horario',
                              style: TextStyle(
                                fontSize: 14,
                                color: concluida ? Colors.grey.shade500 : Colors.grey.shade700,
                              ),
                            ),
                          ],
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
                              _toggleConcluida(rotina);
                              break;
                            case 'delete':
                              _deleteRotina(rotina);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'toggle',
                            child: Row(
                              children: [
                                Icon(
                                  concluida ? Icons.undo : Icons.check,
                                  size: 20,
                                  color: concluida ? Colors.orange : Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Text(concluida ? 'Marcar como pendente' : 'Marcar como concluída'),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ),
                ],
                
                // Botão de ação rápida para familiares marcarem como concluída
                if (_isFamiliar && !concluida) ...[
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
                        onTap: () => _toggleConcluida(rotina),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Marcar como Concluída',
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
                
                // Botão para desmarcar (se já estiver concluída e for familiar)
                if (_isFamiliar && concluida) ...[
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
                        onTap: () => _toggleConcluida(rotina),
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


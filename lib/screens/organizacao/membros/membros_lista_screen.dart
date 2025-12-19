import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/organizacao_provider.dart';
import '../../../services/membro_organizacao_service.dart';
import '../../../services/organizacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';
import 'adicionar_membro_screen.dart';
import 'editar_membro_screen.dart';

/// Tela para listar membros da organização
class MembrosListaScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const MembrosListaScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<MembrosListaScreen> createState() => _MembrosListaScreenState();
}

class _MembrosListaScreenState extends ConsumerState<MembrosListaScreen> {
  final MembroOrganizacaoService _membroService =
      getIt<MembroOrganizacaoService>();
  bool _isLoading = true;
  List<MembroOrganizacao> _membros = [];

  @override
  void initState() {
    super.initState();
    _carregarMembros();
  }

  Future<void> _carregarMembros() async {
    setState(() => _isLoading = true);
    try {
      _membros = await _membroService.listarMembros(widget.organizacaoId);
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizacaoState = ref.watch(organizacaoProvider);
    final podeGerenciar = organizacaoState.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membros da Organização'),
        actions: [
          if (podeGerenciar)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdicionarMembroScreen(
                      organizacaoId: widget.organizacaoId,
                    ),
                  ),
                );
                if (result == true) {
                  _carregarMembros();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _membros.isEmpty
              ? const Center(child: Text('Nenhum membro encontrado'))
              : RefreshIndicator(
                  onRefresh: _carregarMembros,
                  child: ListView.builder(
                    itemCount: _membros.length,
                    itemBuilder: (context, index) {
                      final membro = _membros[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              membro.nomePerfil
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  '?',
                            ),
                          ),
                          title: Text(membro.nomePerfil ?? 'Sem nome'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (membro.emailPerfil != null)
                                Text(membro.emailPerfil!),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text(membro.role),
                                labelStyle: const TextStyle(fontSize: 12),
                                backgroundColor: _getRoleColor(membro.role),
                              ),
                            ],
                          ),
                          trailing: membro.ativo
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.cancel, color: Colors.red),
                          onTap: podeGerenciar
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditarMembroScreen(
                                        membroId: membro.id,
                                        organizacaoId: widget.organizacaoId,
                                        nomeMembro:
                                            membro.nomePerfil ?? 'Sem nome',
                                        roleAtual: membro.role,
                                      ),
                                    ),
                                  ).then((result) {
                                    if (result == true) {
                                      _carregarMembros();
                                    }
                                  });
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red.shade100;
      case 'medico':
        return Colors.blue.shade100;
      case 'enfermeiro':
        return Colors.purple.shade100;
      case 'cuidador':
        return Colors.green.shade100;
      case 'recepcionista':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/organizacao_provider.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../services/organizacao_service.dart';
import '../../../core/injection/injection.dart';
import 'adicionar_idoso_organizacao_screen.dart';
import 'editar_idoso_organizacao_screen.dart';

/// Tela para listar idosos da organização
class IdososOrganizacaoListaScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const IdososOrganizacaoListaScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<IdososOrganizacaoListaScreen> createState() =>
      _IdososOrganizacaoListaScreenState();
}

class _IdososOrganizacaoListaScreenState
    extends ConsumerState<IdososOrganizacaoListaScreen> {
  final IdosoOrganizacaoService _idosoService = getIt<IdosoOrganizacaoService>();
  bool _isLoading = true;
  List<IdosoOrganizacao> _idosos = [];

  @override
  void initState() {
    super.initState();
    _carregarIdosos();
  }

  Future<void> _carregarIdosos() async {
    setState(() => _isLoading = true);
    try {
      _idosos = await _idosoService.listarIdosos(widget.organizacaoId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar idosos: $e')),
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
    final organizacaoNotifier = ref.read(organizacaoProvider.notifier);
    final podeGerenciar = organizacaoNotifier.podeGerenciarIdosos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Idosos da Organização'),
        actions: [
          if (podeGerenciar)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdicionarIdosoOrganizacaoScreen(
                      organizacaoId: widget.organizacaoId,
                    ),
                  ),
                );
                if (result == true) {
                  _carregarIdosos();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _idosos.isEmpty
              ? const Center(child: Text('Nenhum idoso encontrado'))
              : RefreshIndicator(
                  onRefresh: _carregarIdosos,
                  child: ListView.builder(
                    itemCount: _idosos.length,
                    itemBuilder: (context, index) {
                      final idoso = _idosos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: idoso.isVirtual
                                ? Colors.orange.shade100
                                : Colors.blue.shade100,
                            child: Icon(
                              idoso.isVirtual ? Icons.person_outline : Icons.person,
                              color: idoso.isVirtual
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                          title: Text(idoso.nomePerfil ?? 'Sem nome'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (idoso.quarto != null) Text('Quarto: ${idoso.quarto}'),
                              if (idoso.setor != null) Text('Setor: ${idoso.setor}'),
                              if (idoso.isVirtual)
                                const Chip(
                                  label: Text('Perfil Virtual'),
                                  labelStyle: TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditarIdosoOrganizacaoScreen(
                                  idosoId: idoso.id,
                                  organizacaoId: widget.organizacaoId,
                                  idoso: idoso,
                                ),
                              ),
                            ).then((result) {
                              if (result == true) {
                                _carregarIdosos();
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}


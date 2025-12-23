import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../services/organizacao_service.dart';

/// Widget para selecionar contexto (Pessoal vs Organização)
class ContextSelectorWidget extends ConsumerWidget {
  const ContextSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizacaoState = ref.watch(organizacaoProvider);

    // Só mostrar se usuário tem organizações
    if (organizacaoState.organizacoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: organizacaoState.isModoOrganizacao
            ? Colors.blue.shade50
            : Colors.green.shade50,
        border: Border(
          bottom: BorderSide(
            color: organizacaoState.isModoOrganizacao
                ? Colors.blue.shade200
                : Colors.green.shade200,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            organizacaoState.isModoOrganizacao ? Icons.business : Icons.person,
            color: organizacaoState.isModoOrganizacao
                ? Colors.blue.shade700
                : Colors.green.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _mostrarSeletor(context, ref, organizacaoState),
              child: Text(
                organizacaoState.isModoOrganizacao
                    ? 'Modo Organização: ${organizacaoState.organizacaoAtual?.nome ?? ""}'
                    : 'Modo Individual',
                style: TextStyle(
                  color: organizacaoState.isModoOrganizacao
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_drop_down),
            onPressed: () => _mostrarSeletor(context, ref, organizacaoState),
            color: organizacaoState.isModoOrganizacao
                ? Colors.blue.shade700
                : Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  void _mostrarSeletor(
    BuildContext context,
    WidgetRef ref,
    OrganizacaoState state,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ContextSelectorSheet(
        organizacoes: state.organizacoes,
        organizacaoAtual: state.organizacaoAtual,
        isModoOrganizacao: state.isModoOrganizacao,
      ),
    );
  }
}

class _ContextSelectorSheet extends ConsumerWidget {
  final List<Organizacao> organizacoes;
  final Organizacao? organizacaoAtual;
  final bool isModoOrganizacao;

  const _ContextSelectorSheet({
    required this.organizacoes,
    this.organizacaoAtual,
    required this.isModoOrganizacao,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecionar Contexto',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Opção: Modo Pessoal
          ListTile(
            leading: Icon(
              Icons.person,
              color: !isModoOrganizacao ? Colors.green : Colors.grey,
            ),
            title: const Text('Modo Individual'),
            subtitle: const Text('Ver seus próprios dados e idosos familiares'),
            selected: !isModoOrganizacao,
            onTap: () async {
              await ref.read(organizacaoProvider.notifier).alternarModoPessoal();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const Divider(),
          // Opções: Organizações
          ...organizacoes.map((org) => ListTile(
                leading: Icon(
                  Icons.business,
                  color: isModoOrganizacao && organizacaoAtual?.id == org.id
                      ? Colors.blue
                      : Colors.grey,
                ),
                title: Text(org.nome),
                subtitle: Text(org.cnpj ?? 'Sem CNPJ'),
                selected: isModoOrganizacao && organizacaoAtual?.id == org.id,
                onTap: () async {
                  await ref
                      .read(organizacaoProvider.notifier)
                      .alternarModoOrganizacao(org.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              )),
        ],
      ),
    );
  }
}

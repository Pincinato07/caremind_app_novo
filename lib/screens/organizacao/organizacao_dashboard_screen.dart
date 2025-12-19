import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../widgets/organizacao/trial_blocked_guard.dart';
import 'membros/membros_lista_screen.dart';
import 'idosos/idosos_organizacao_lista_screen.dart';
import 'relatorios/relatorios_organizacao_screen.dart';
import 'organizacao_configuracoes_screen.dart';

/// Dashboard da organização
class OrganizacaoDashboardScreen extends ConsumerWidget {
  final String organizacaoId;

  const OrganizacaoDashboardScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizacaoState = ref.watch(organizacaoProvider);
    final organizacao = organizacaoState.organizacaoAtual;

    if (organizacao == null || organizacao.id != organizacaoId) {
      // Carregar organização se ainda não estiver carregada
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(organizacaoProvider.notifier)
            .selecionarOrganizacao(organizacaoId);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return TrialBlockedGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(organizacao.nome),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrganizacaoConfiguracoesScreen(
                      organizacaoId: organizacaoId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de informações
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        organizacao.nome,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (organizacao.cnpj != null) ...[
                        const SizedBox(height: 8),
                        Text('CNPJ: ${organizacao.cnpj}'),
                      ],
                      if (organizacao.telefone != null) ...[
                        const SizedBox(height: 4),
                        Text('Telefone: ${organizacao.telefone}'),
                      ],
                      if (organizacaoState.roleAtual != null) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            'Função: ${organizacaoState.roleAtual}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Ações rápidas
              const Text(
                'Ações Rápidas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildActionCard(
                    context,
                    icon: Icons.people,
                    title: 'Idosos',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IdososOrganizacaoListaScreen(
                            organizacaoId: organizacaoId,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.group,
                    title: 'Membros',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MembrosListaScreen(
                            organizacaoId: organizacaoId,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.assessment,
                    title: 'Relatórios',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RelatoriosOrganizacaoScreen(
                            organizacaoId: organizacaoId,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.settings,
                    title: 'Configurações',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrganizacaoConfiguracoesScreen(
                            organizacaoId: organizacaoId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

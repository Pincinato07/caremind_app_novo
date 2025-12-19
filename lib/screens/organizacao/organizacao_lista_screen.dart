import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../services/organizacao_service.dart';
import 'criar_organizacao_screen.dart';
import 'organizacao_dashboard_screen.dart';

/// Tela para listar organizações do usuário
class OrganizacaoListaScreen extends ConsumerStatefulWidget {
  const OrganizacaoListaScreen({super.key});

  @override
  ConsumerState<OrganizacaoListaScreen> createState() =>
      _OrganizacaoListaScreenState();
}

class _OrganizacaoListaScreenState
    extends ConsumerState<OrganizacaoListaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(organizacaoProvider.notifier).carregarOrganizacoes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final organizacaoState = ref.watch(organizacaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Organizações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CriarOrganizacaoScreen(),
                ),
              );
              if (result == true) {
                ref.read(organizacaoProvider.notifier).carregarOrganizacoes();
              }
            },
          ),
        ],
      ),
      body: organizacaoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : organizacaoState.organizacoes.isEmpty
              ? _buildEmptyState()
              : _buildLista(organizacaoState.organizacoes),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100.withValues(alpha: 0.3),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.business_center,
                size: 80,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Nenhuma organização encontrada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Organizações são para instituições de saúde como:\n'
              '• Casas de repouso\n'
              '• Clínicas e hospitais\n'
              '• Consultórios médicos\n'
              '• Equipes de cuidadores',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CriarOrganizacaoScreen(),
                    ),
                  );
                  if (result == true) {
                    ref.read(organizacaoProvider.notifier).carregarOrganizacoes();
                  }
                },
                icon: const Icon(Icons.add_circle_outline, size: 24),
                label: const Text(
                  'Criar Minha Primeira Organização',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Voltar',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(List<Organizacao> organizacoes) {
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(organizacaoProvider.notifier).carregarOrganizacoes();
      },
      child: ListView.builder(
        itemCount: organizacoes.length,
        itemBuilder: (context, index) {
          final org = organizacoes[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Icon(
                  Icons.business,
                  color: Colors.blue.shade700,
                ),
              ),
              title: Text(
                org.nome,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (org.cnpj != null) Text('CNPJ: ${org.cnpj}'),
                  if (org.telefone != null) Text('Tel: ${org.telefone}'),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref
                    .read(organizacaoProvider.notifier)
                    .selecionarOrganizacao(org.id);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrganizacaoDashboardScreen(
                        organizacaoId: org.id,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}


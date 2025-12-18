import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/organizacao_provider.dart';
import '../../services/organizacao_service.dart';
import '../../core/injection/injection.dart';

/// Tela de configurações da organização
class OrganizacaoConfiguracoesScreen extends ConsumerStatefulWidget {
  final String organizacaoId;

  const OrganizacaoConfiguracoesScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  ConsumerState<OrganizacaoConfiguracoesScreen> createState() =>
      _OrganizacaoConfiguracoesScreenState();
}

class _OrganizacaoConfiguracoesScreenState
    extends ConsumerState<OrganizacaoConfiguracoesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final OrganizacaoService _organizacaoService = getIt<OrganizacaoService>();
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final org = await _organizacaoService.obterOrganizacao(widget.organizacaoId);
      _nomeController.text = org.nome;
      _cnpjController.text = org.cnpj ?? '';
      _telefoneController.text = org.telefone ?? '';
      _emailController.text = org.email ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _organizacaoService.atualizarOrganizacao(
        widget.organizacaoId,
        nome: _nomeController.text.trim(),
        cnpj: _cnpjController.text.trim().isEmpty
            ? null
            : _cnpjController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );

      // Atualizar provider
      await ref.read(organizacaoProvider.notifier).atualizarOrganizacaoAtual();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Dados da Organização',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cnpjController,
                decoration: const InputDecoration(
                  labelText: 'CNPJ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


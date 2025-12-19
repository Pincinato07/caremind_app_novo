import 'package:flutter/material.dart';
import '../../../services/membro_organizacao_service.dart';
import '../../../core/injection/injection.dart';

/// Tela para editar membro da organização
class EditarMembroScreen extends StatefulWidget {
  final String membroId;
  final String organizacaoId;
  final String nomeMembro;
  final String roleAtual;

  const EditarMembroScreen({
    super.key,
    required this.membroId,
    required this.organizacaoId,
    required this.nomeMembro,
    required this.roleAtual,
  });

  @override
  State<EditarMembroScreen> createState() => _EditarMembroScreenState();
}

class _EditarMembroScreenState extends State<EditarMembroScreen> {
  final MembroOrganizacaoService _membroService = getIt<MembroOrganizacaoService>();
  String _roleSelecionado = 'cuidador';
  bool _ativo = true;
  bool _isLoading = false;
  bool _isSaving = false;

  final List<String> _roles = [
    'admin',
    'medico',
    'enfermeiro',
    'cuidador',
    'recepcionista',
  ];

  @override
  void initState() {
    super.initState();
    _roleSelecionado = widget.roleAtual;
  }

  Future<void> _salvar() async {
    setState(() => _isSaving = true);

    try {
      await _membroService.atualizarRole(
        membroId: widget.membroId,
        role: _roleSelecionado,
      );

      await _membroService.atualizarStatus(
        membroId: widget.membroId,
        ativo: _ativo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membro atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar membro: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Membro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.nomeMembro,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _roleSelecionado,
              decoration: const InputDecoration(
                labelText: 'Função *',
                border: OutlineInputBorder(),
              ),
              items: _roles.map((role) {
                return DropdownMenuItem(
                  value: role,
                  child: Text(_getRoleLabel(role)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _roleSelecionado = value);
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ativo'),
              subtitle: const Text('Membro ativo na organização'),
              value: _ativo,
              onChanged: (value) {
                setState(() => _ativo = value);
              },
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
            const SizedBox(height: 24),
            Divider(color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Zona de Perigo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _removerMembro,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text(
                'Remover Membro da Organização',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removerMembro() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text(
          'Tem certeza que deseja remover ${widget.nomeMembro} da organização?\n\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      final precisaRedirecionar = await _membroService.removerMembro(widget.membroId);

      if (mounted) {
        if (precisaRedirecionar) {
          // Usuário foi removido e não é membro de nenhuma organização
          // Redirecionar para Dashboard Individual
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você foi removido da organização. Redirecionando...'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );

          // Aguardar um pouco para mostrar a mensagem
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            // Limpar stack de navegação e ir para dashboard individual
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/individual-dashboard',
              (route) => false,
            );
          }
        } else {
          // Apenas outro membro foi removido, voltar para lista
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Membro removido com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        String mensagemUsuario = 'Erro ao remover membro';
        
        // Tratar diferentes tipos de erro
        if (errorMessage.contains('conexão') || errorMessage.contains('internet') || errorMessage.contains('network')) {
          mensagemUsuario = 'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (errorMessage.contains('não encontrado') || errorMessage.contains('sem permissão')) {
          mensagemUsuario = 'Membro não encontrado ou você não tem permissão para removê-lo.';
        } else if (errorMessage.contains('não autenticado') || errorMessage.contains('Token')) {
          mensagemUsuario = 'Sua sessão expirou. Faça login novamente.';
        } else {
          // Extrair mensagem do erro
          final match = RegExp(r'Exception:\s*(.+?)(?:\n|$)').firstMatch(errorMessage);
          mensagemUsuario = match?.group(1)?.trim() ?? 'Erro ao remover membro. Tente novamente.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensagemUsuario),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'medico':
        return 'Médico';
      case 'enfermeiro':
        return 'Enfermeiro';
      case 'cuidador':
        return 'Cuidador';
      case 'recepcionista':
        return 'Recepcionista';
      default:
        return role;
    }
  }
}


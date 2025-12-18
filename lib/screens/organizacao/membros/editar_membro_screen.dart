import 'package:flutter/material.dart';
import '../../../services/membro_organizacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../services/organizacao_service.dart';

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
              value: _roleSelecionado,
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
          ],
        ),
      ),
    );
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


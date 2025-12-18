import 'package:flutter/material.dart';
import '../../../services/membro_organizacao_service.dart';
import '../../../core/injection/injection.dart';

/// Tela para adicionar membro à organização
class AdicionarMembroScreen extends StatefulWidget {
  final String organizacaoId;

  const AdicionarMembroScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<AdicionarMembroScreen> createState() => _AdicionarMembroScreenState();
}

class _AdicionarMembroScreenState extends State<AdicionarMembroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final MembroOrganizacaoService _membroService = getIt<MembroOrganizacaoService>();
  String _roleSelecionado = 'cuidador';
  bool _isLoading = false;

  final List<String> _roles = [
    'admin',
    'medico',
    'enfermeiro',
    'cuidador',
    'recepcionista',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _convidarMembro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _membroService.convidarMembro(
        organizacaoId: widget.organizacaoId,
        email: _emailController.text.trim(),
        role: _roleSelecionado,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite enviado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao convidar membro: $e'),
            backgroundColor: Colors.red,
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Membro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Convidar membro para organização',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'email@exemplo.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email é obrigatório';
                  }
                  if (!value.contains('@')) {
                    return 'Email inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _convidarMembro,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar Convite'),
              ),
            ],
          ),
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


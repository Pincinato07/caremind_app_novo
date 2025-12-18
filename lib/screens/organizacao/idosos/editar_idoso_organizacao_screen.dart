import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../services/organizacao_service.dart';

/// Tela para editar idoso da organização
class EditarIdosoOrganizacaoScreen extends StatefulWidget {
  final String idosoId;
  final String organizacaoId;
  final IdosoOrganizacao idoso;

  const EditarIdosoOrganizacaoScreen({
    super.key,
    required this.idosoId,
    required this.organizacaoId,
    required this.idoso,
  });

  @override
  State<EditarIdosoOrganizacaoScreen> createState() =>
      _EditarIdosoOrganizacaoScreenState();
}

class _EditarIdosoOrganizacaoScreenState
    extends State<EditarIdosoOrganizacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _quartoController = TextEditingController();
  final _setorController = TextEditingController();
  final _observacoesController = TextEditingController();
  final IdosoOrganizacaoService _idosoService = getIt<IdosoOrganizacaoService>();
  DateTime? _dataNascimento;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController.text = widget.idoso.nomePerfil ?? '';
    _telefoneController.text = widget.idoso.telefonePerfil ?? '';
    _quartoController.text = widget.idoso.quarto ?? '';
    _setorController.text = widget.idoso.setor ?? '';
    _observacoesController.text = widget.idoso.observacoes ?? '';
    _dataNascimento = widget.idoso.dataNascimentoPerfil;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    _quartoController.dispose();
    _setorController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime.now().subtract(const Duration(days: 365 * 70)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (data != null) {
      setState(() => _dataNascimento = data);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _idosoService.atualizarIdoso(
        idosoId: widget.idosoId,
        nome: _nomeController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty
            ? null
            : _telefoneController.text.trim(),
        dataNascimento: _dataNascimento,
        quarto: _quartoController.text.trim().isEmpty
            ? null
            : _quartoController.text.trim(),
        setor: _setorController.text.trim().isEmpty
            ? null
            : _setorController.text.trim(),
        observacoes: _observacoesController.text.trim().isEmpty
            ? null
            : _observacoesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Idoso atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar idoso: $e'),
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
        title: const Text('Editar Idoso'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Nascimento',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dataNascimento != null
                        ? DateFormat('dd/MM/yyyy').format(_dataNascimento!)
                        : 'Selecione a data',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quartoController,
                decoration: const InputDecoration(
                  labelText: 'Quarto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _setorController,
                decoration: const InputDecoration(
                  labelText: 'Setor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
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


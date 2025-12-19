import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../core/injection/injection.dart';

/// Tela para adicionar idoso virtual à organização
class AdicionarIdosoOrganizacaoScreen extends StatefulWidget {
  final String organizacaoId;

  const AdicionarIdosoOrganizacaoScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<AdicionarIdosoOrganizacaoScreen> createState() =>
      _AdicionarIdosoOrganizacaoScreenState();
}

class _AdicionarIdosoOrganizacaoScreenState
    extends State<AdicionarIdosoOrganizacaoScreen> {
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
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 70)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (data != null) {
      setState(() => _dataNascimento = data);
    }
  }

  Future<void> _adicionarIdoso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final resultado = await _idosoService.adicionarIdoso(
        organizacaoId: widget.organizacaoId,
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
        // Verificar se retornou duplicado
        if (resultado.containsKey('duplicado')) {
          final duplicado = resultado['duplicado'] as Map<String, dynamic>;
          final nomeOrg = duplicado['organizacao_nome'] as String? ?? 'uma organização';
          
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Idoso Já Cadastrado'),
              content: Text(
                'Este idoso já está cadastrado no sistema na organização "$nomeOrg".\n\n'
                'Verifique os dados ou entre em contato com o administrador.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Idoso adicionado com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        String mensagemUsuario = 'Erro ao adicionar idoso';
        
        // Tratar diferentes tipos de erro
        if (errorMessage.contains('já existe') || errorMessage.contains('duplicado') || errorMessage.contains('Já existe')) {
          // Já tratado no código acima, mas garantir que não mostre erro genérico
          return;
        } else if (errorMessage.contains('conexão') || errorMessage.contains('internet') || errorMessage.contains('network')) {
          mensagemUsuario = 'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (errorMessage.contains('não encontrada') || errorMessage.contains('sem permissão')) {
          mensagemUsuario = 'Organização não encontrada ou você não tem permissão para adicionar idosos.';
        } else if (errorMessage.contains('não autenticado') || errorMessage.contains('Token')) {
          mensagemUsuario = 'Sua sessão expirou. Faça login novamente.';
        } else {
          // Extrair mensagem do erro
          final match = RegExp(r'Exception:\s*(.+?)(?:\n|$)').firstMatch(errorMessage);
          mensagemUsuario = match?.group(1)?.trim() ?? 'Erro ao adicionar idoso. Tente novamente.';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Idoso'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Adicionar Idoso Virtual',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este idoso será criado como perfil virtual (sem conta de usuário)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Nascimento (opcional)',
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
                  labelText: 'Quarto (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _setorController,
                decoration: const InputDecoration(
                  labelText: 'Setor (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _adicionarIdoso,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Adicionar Idoso'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


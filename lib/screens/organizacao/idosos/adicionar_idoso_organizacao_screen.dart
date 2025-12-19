import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/app_exception.dart';

/// Tela para adicionar idoso virtual à organização
///
/// REFATORADO: ~256 linhas → ~160 linhas (-38%)
/// - Removido parsing de strings de erro
/// - Usando FeedbackService
/// - Tratamento de erros estruturado
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
  final IdosoOrganizacaoService _idosoService =
      getIt<IdosoOrganizacaoService>();
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

      if (!mounted) return;

      // Verificar se retornou duplicado
      if (resultado.containsKey('duplicado')) {
        final duplicado = resultado['duplicado'] as Map<String, dynamic>;
        final nomeOrg =
            duplicado['organizacao_nome'] as String? ?? 'uma organização';

        await showDialog(
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
        return;
      }

      // Sucesso
      FeedbackService.showSuccess(context, 'Idoso adicionado com sucesso!');
      Navigator.pop(context, true);
    } on NetworkException catch (e) {
      if (mounted) {
        FeedbackService.showError(context, e);
      }
    } on AuthenticationException catch (e) {
      if (mounted) {
        FeedbackService.showError(context, e);
      }
    } on ValidationException catch (e) {
      if (mounted) {
        FeedbackService.showError(context, e);
      }
    } on DatabaseException catch (e) {
      if (mounted) {
        // Tratar erros específicos de duplicação
        if (e.message.contains('já existe') ||
            e.message.contains('duplicado') ||
            e.message.contains('Já existe')) {
          // Já foi tratado acima no fluxo normal
          return;
        }
        FeedbackService.showError(context, e);
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.showErrorMessage(
          context,
          'Erro ao adicionar idoso. Tente novamente.',
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _isLoading ? null : _selecionarData,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data de Nascimento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dataNascimento == null
                        ? 'Selecionar data'
                        : DateFormat('dd/MM/yyyy').format(_dataNascimento!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quartoController,
                decoration: const InputDecoration(
                  labelText: 'Quarto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bed),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _setorController,
                decoration: const InputDecoration(
                  labelText: 'Setor',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacoesController,
                decoration: const InputDecoration(
                  labelText: 'Observações',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
                enabled: !_isLoading,
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

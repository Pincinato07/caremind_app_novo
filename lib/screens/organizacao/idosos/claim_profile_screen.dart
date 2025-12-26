import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/claim_profile_provider.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../widgets/rate_limit_dialog.dart';
import '../../../core/errors/app_exception.dart';

/// Tela para reivindicar Perfil Gerenciado
///
/// REFATORADO: 369 linhas → ~150 linhas (-60%)
/// - StatefulWidget → ConsumerWidget
/// - Removido todo parsing de string de erros
/// - Removido rate limiting client-side
/// - Removido state management manual
/// - Usando Riverpod + FeedbackService + RateLimitDialog
class ClaimProfileScreen extends ConsumerStatefulWidget {
  final String perfilId;
  final String nomePerfil;

  const ClaimProfileScreen({
    super.key,
    required this.perfilId,
    required this.nomePerfil,
  });

  @override
  ConsumerState<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends ConsumerState<ClaimProfileScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  String? _actionSelecionada;

  @override
  void dispose() {
    _codigoController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Reseta o estado quando a tela é criada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(claimProfileProvider.notifier).reset();
    });
  }

  Future<void> _reivindicar() async {
    // Validar ação selecionada
    if (_actionSelecionada == null) {
      FeedbackService.showWarning(context, 'Selecione uma ação');
      return;
    }

    // Validar código
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      FeedbackService.showWarning(
        context,
        'Por favor, informe o código de vinculação',
      );
      return;
    }

    // VALIDAÇÃO CRÍTICA: Telefone obrigatório para SOS
    final telefone = _telefoneController.text.trim();
    if (telefone.isEmpty) {
      FeedbackService.showWarning(
        context,
        'O telefone é obrigatório para receber alertas de emergência (SOS). '
        'Os familiares precisam de um número válido para retornar chamadas.',
      );
      return;
    }

    // Validar formato básico de telefone (mínimo 10 dígitos)
    final telefoneLimpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
    if (telefoneLimpo.length < 10) {
      FeedbackService.showWarning(
        context,
        'Por favor, informe um número de telefone válido (mínimo 10 dígitos)',
      );
      return;
    }

    // Executar claim (a Edge Function deve validar e salvar o telefone)
    await ref.read(claimProfileProvider.notifier).claimProfile(
          perfilId: widget.perfilId,
          action: _actionSelecionada!,
          codigo: codigo,
          telefone: telefone,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Observar estado do provider
    final state = ref.watch(claimProfileProvider);

    // Listener para tratar sucesso e erros
    ref.listen<ClaimProfileState>(claimProfileProvider, (previous, current) {
      if (current.isSuccess) {
        FeedbackService.showSuccess(context, current.successMessage!);
        Navigator.pop(context, true);
      } else if (current.error != null) {
        _handleError(current.error!);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reivindicar Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informação
            const Text(
              'Este é um Perfil Gerenciado (criado por uma organização). Você pode:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Opções de ação
            RadioGroup<String>(
              groupValue: _actionSelecionada,
              onChanged: state.isLoading
                  ? (_) {}
                  : (value) => setState(() => _actionSelecionada = value),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Converter em Perfil Conectado'),
                    subtitle: const Text('Este perfil será vinculado à sua conta'),
                    value: 'convert',
                  ),
                  RadioListTile<String>(
                    title: const Text('Vincular como Familiar'),
                    subtitle: const Text(
                      'Mantém o Perfil Gerenciado, mas você terá acesso como familiar',
                    ),
                    value: 'link_family',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Campo de código
            TextFormField(
              controller: _codigoController,
              decoration: const InputDecoration(
                labelText: 'Código de Vinculação *',
                hintText: 'Digite o código fornecido pela organização',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              enabled: !state.isLoading,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            
            // Campo de telefone (obrigatório para SOS)
            TextFormField(
              controller: _telefoneController,
              decoration: const InputDecoration(
                labelText: 'Telefone Celular *',
                hintText: '(00) 00000-0000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                helperText: 'Obrigatório para receber alertas de emergência (SOS)',
              ),
              enabled: !state.isLoading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),

            // Botão de ação
            ElevatedButton(
              onPressed: state.isLoading ? null : _reivindicar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reivindicar Perfil'),
            ),
          ],
        ),
      ),
    );
  }

  /// Trata erros de forma apropriada
  void _handleError(AppException exception) {
    // Rate Limit - mostrar dialog específico
    if (exception is RateLimitException) {
      RateLimitDialog.show(context, exception);
      return;
    }

    // ClaimProfile Exception - mostrar SnackBar com detalhes
    if (exception is ClaimProfileException) {
      FeedbackService.showError(context, exception);
      return;
    }

    // Erro genérico
    FeedbackService.showError(context, exception);
  }
}

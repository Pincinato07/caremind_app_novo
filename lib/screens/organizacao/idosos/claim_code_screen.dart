import 'package:flutter/material.dart';
import 'claim_profile_screen.dart';

/// Tela para digitar código de claim profile
class ClaimCodeScreen extends StatefulWidget {
  const ClaimCodeScreen({super.key});

  @override
  State<ClaimCodeScreen> createState() => _ClaimCodeScreenState();
}

class _ClaimCodeScreenState extends State<ClaimCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _validateAndNavigate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Implementar validação do código via API
      // Por enquanto, vamos assumir que o código é válido e navegar
      // Na implementação real, você deve:
      // 1. Chamar API para validar o código
      // 2. Obter perfil_id e nome_perfil da resposta
      // 3. Navegar para ClaimProfileScreen com esses dados
      
      final code = _codeController.text.trim();
      
      // Simulação - substituir por chamada real à API
      // final perfilData = await _idosoService.validateClaimCode(code);
      
      // Por enquanto, vamos mostrar um erro se o código não tiver formato válido
      if (code.length < 6) {
        setState(() {
          _errorMessage = 'Código inválido. Verifique e tente novamente.';
          _isLoading = false;
        });
        return;
      }

      // Navegar para a tela de claim profile
      // Em produção, você deve passar os dados reais do perfil
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ClaimProfileScreen(
              perfilId: code, // Em produção, usar perfil_id real
              nomePerfil: 'Perfil Virtual', // Em produção, usar nome real
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao validar código: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular Perfil'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ícone e título
              const SizedBox(height: 32),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              Text(
                'Digite o Código de Vinculação',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Se uma organização criou um perfil virtual para você, '
                'você receberá um código de vinculação. Digite-o abaixo para assumir o perfil.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Campo de código
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Código de Vinculação',
                  hintText: 'Ex: ABC123',
                  prefixIcon: const Icon(Icons.vpn_key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, digite o código';
                  }
                  if (value.trim().length < 6) {
                    return 'Código deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _validateAndNavigate(),
              ),
              const SizedBox(height: 24),

              // Mensagem de erro
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (_errorMessage != null) const SizedBox(height: 24),

              // Botão de ação
              ElevatedButton(
                onPressed: _isLoading ? null : _validateAndNavigate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Validar e Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // Informações adicionais
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Como obter o código?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O código de vinculação é fornecido pela organização que criou seu perfil. '
                      'Entre em contato com a clínica ou casa de repouso para obter seu código.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


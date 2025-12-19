import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'claim_profile_screen.dart';

/// Tela para entrada do código de 6 dígitos para vincular perfil
class CodigoVinculoScreen extends StatefulWidget {
  final String perfilId;
  final String nomePerfil;

  const CodigoVinculoScreen({
    super.key,
    required this.perfilId,
    required this.nomePerfil,
  });

  @override
  State<CodigoVinculoScreen> createState() => _CodigoVinculoScreenState();
}

class _CodigoVinculoScreenState extends State<CodigoVinculoScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1) {
      // Mover para o próximo campo
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Último campo preenchido, validar código
        _validateCode();
      }
    } else if (value.isEmpty && index > 0) {
      // Voltar para o campo anterior
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _validateCode() {
    final code = _controllers.map((c) => c.text).join();
    
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os 6 dígitos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Aqui você pode validar o código se necessário
    // Por enquanto, vamos direto para a tela de claim
    _navigateToClaim();
  }

  void _navigateToClaim() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimProfileScreen(
          perfilId: widget.perfilId,
          nomePerfil: widget.nomePerfil,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Código de Vínculo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 80,
              color: Color(0xFF667eea),
            ),
            const SizedBox(height: 24),
            const Text(
              'Digite o código de 6 dígitos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'O familiar que criou o Perfil Gerenciado "${widget.nomePerfil}" forneceu este código para você vincular-se.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 50,
                  height: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF667eea),
                          width: 2,
                        ),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) => _onCodeChanged(index, value),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _isLoading ? null : _validateCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF667eea),
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
                      'Continuar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


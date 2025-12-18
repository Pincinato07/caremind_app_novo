import 'package:flutter/material.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../core/injection/injection.dart';
import '../../../services/organizacao_service.dart';

/// Tela para reivindicar perfil virtual
class ClaimProfileScreen extends StatefulWidget {
  final String perfilId;
  final String nomePerfil;

  const ClaimProfileScreen({
    super.key,
    required this.perfilId,
    required this.nomePerfil,
  });

  @override
  State<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends State<ClaimProfileScreen> {
  final IdosoOrganizacaoService _idosoService = getIt<IdosoOrganizacaoService>();
  String? _actionSelecionada;
  bool _isLoading = false;

  Future<void> _reivindicar() async {
    if (_actionSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma ação'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _idosoService.claimProfile(
        perfilId: widget.perfilId,
        action: _actionSelecionada!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _actionSelecionada == 'convert'
                  ? 'Perfil convertido com sucesso!'
                  : 'Vínculo familiar criado com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
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
        title: const Text('Reivindicar Perfil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Este perfil é virtual (criado por uma organização). Você pode:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            RadioListTile<String>(
              title: const Text('Converter em Perfil Real'),
              subtitle: const Text('Este perfil será vinculado à sua conta'),
              value: 'convert',
              groupValue: _actionSelecionada,
              onChanged: (value) {
                setState(() => _actionSelecionada = value);
              },
            ),
            RadioListTile<String>(
              title: const Text('Vincular como Familiar'),
              subtitle: const Text('Mantém o perfil virtual, mas você terá acesso como familiar'),
              value: 'link_family',
              groupValue: _actionSelecionada,
              onChanged: (value) {
                setState(() => _actionSelecionada = value);
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _reivindicar,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
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
}


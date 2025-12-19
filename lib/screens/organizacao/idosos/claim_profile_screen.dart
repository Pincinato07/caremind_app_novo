import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/idoso_organizacao_service.dart';
import '../../../core/injection/injection.dart';

/// Tela para reivindicar Perfil Gerenciado
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
  final TextEditingController _codigoController = TextEditingController();
  String? _actionSelecionada;
  bool _isLoading = false;
  int _tentativasRestantes = 3;
  DateTime? _bloqueadoAte;
  bool _mostrarModalBloqueio = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

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

    // Validar código de vinculação
    if (_codigoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o código de vinculação'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar se está bloqueado
    if (_bloqueadoAte != null && _bloqueadoAte!.isAfter(DateTime.now())) {
      _mostrarModalBloqueio = true;
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _idosoService.claimProfile(
        perfilId: widget.perfilId,
        action: _actionSelecionada!,
        codigoVinculacao: _codigoController.text.trim(),
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
        final errorMessage = e.toString();
        String mensagemUsuario = 'Erro ao reivindicar perfil';
        
        // Verificar se é erro de bloqueio (formato: BLOQUEADO:mensagem\nMINUTOS:15)
        if (errorMessage.contains('BLOQUEADO:')) {
          final partes = errorMessage.split('\n');
          final minutosParte = partes.firstWhere(
            (p) => p.startsWith('MINUTOS:'),
            orElse: () => 'MINUTOS:15'
          );
          final minutos = int.tryParse(minutosParte.split(':')[1]) ?? 15;
          
          _tentativasRestantes = 0;
          _bloqueadoAte = DateTime.now().add(Duration(minutes: minutos));
          _mostrarModalBloqueio = true;
          setState(() {});
          return;
        }
        
        // Tratar diferentes tipos de erro
        if (errorMessage.contains('Código inválido') || errorMessage.contains('não corresponde')) {
          mensagemUsuario = 'O código de vinculação está incorreto. Verifique e tente novamente.';
          _tentativasRestantes = (_tentativasRestantes - 1).clamp(0, 3);
        } else if (errorMessage.contains('Código expirado')) {
          mensagemUsuario = 'O código de vinculação expirou. Solicite um novo código à organização.';
        } else if (errorMessage.contains('Perfil já vinculado')) {
          mensagemUsuario = 'Este perfil já está vinculado a uma conta.';
        } else if (errorMessage.contains('conexão') || errorMessage.contains('internet') || errorMessage.contains('network')) {
          mensagemUsuario = 'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (errorMessage.contains('não autenticado') || errorMessage.contains('Token')) {
          mensagemUsuario = 'Sua sessão expirou. Faça login novamente.';
        } else {
          // Extrair mensagem do erro
          final match = RegExp(r'Exception:\s*(.+?)(?:\n|$)').firstMatch(errorMessage);
          mensagemUsuario = match?.group(1)?.trim() ?? 'Erro ao reivindicar perfil. Tente novamente.';
          _tentativasRestantes = (_tentativasRestantes - 1).clamp(0, 3);
        }
        
        if (_tentativasRestantes == 0 && !errorMessage.contains('Código expirado') && !errorMessage.contains('já vinculado')) {
          _bloqueadoAte = DateTime.now().add(const Duration(minutes: 15));
          _mostrarModalBloqueio = true;
        } else if (_tentativasRestantes > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$mensagemUsuario\nTentativas restantes: $_tentativasRestantes'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensagemUsuario),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _abrirWhatsAppSuporte() async {
    const numero = '5511953362516'; // Número do suporte CareMind
    const mensagem = 'Olá, preciso de ajuda com o código de vinculação do CareMind.';
    final url = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _fecharModalBloqueio() {
    setState(() {
      _mostrarModalBloqueio = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reivindicar Perfil'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Este é um Perfil Gerenciado (criado por uma organização). Você pode:',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_tentativasRestantes < 3 && _tentativasRestantes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tentativas restantes: $_tentativasRestantes',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                RadioListTile<String>(
                  title: const Text('Converter em Perfil Conectado'),
                  subtitle: const Text('Este perfil será vinculado à sua conta'),
                  value: 'convert',
                  groupValue: _actionSelecionada,
                  onChanged: (_bloqueadoAte != null && _bloqueadoAte!.isAfter(DateTime.now()))
                      ? null
                      : (value) {
                          setState(() => _actionSelecionada = value);
                        },
                ),
                RadioListTile<String>(
                  title: const Text('Vincular como Familiar'),
                  subtitle: const Text('Mantém o Perfil Gerenciado, mas você terá acesso como familiar'),
                  value: 'link_family',
                  groupValue: _actionSelecionada,
                  onChanged: (_bloqueadoAte != null && _bloqueadoAte!.isAfter(DateTime.now()))
                      ? null
                      : (value) {
                          setState(() => _actionSelecionada = value);
                        },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Vinculação *',
                    hintText: 'Digite o código fornecido pela organização',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  enabled: !(_bloqueadoAte != null && _bloqueadoAte!.isAfter(DateTime.now())),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_isLoading || 
                              (_bloqueadoAte != null && _bloqueadoAte!.isAfter(DateTime.now())))
                      ? null
                      : _reivindicar,
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
          // Modal de Bloqueio
          if (_mostrarModalBloqueio)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_clock,
                          size: 64,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Acesso Bloqueado',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Você excedeu o limite de 3 tentativas.\n'
                          'O acesso foi bloqueado por 15 minutos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (_bloqueadoAte != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Tente novamente às ${_bloqueadoAte!.hour.toString().padLeft(2, '0')}:${_bloqueadoAte!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        const Text(
                          'Precisa de ajuda?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _abrirWhatsAppSuporte,
                          icon: const Icon(Icons.chat),
                          label: const Text('Abrir WhatsApp do Suporte'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _fecharModalBloqueio,
                          child: const Text('Fechar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

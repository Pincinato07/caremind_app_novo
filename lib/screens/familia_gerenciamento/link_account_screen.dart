import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../utils/qr_scanner_screen.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> {
  final TextEditingController _linkController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _handleQRCodeResult(String qrData) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // Mostrar diálogo de carregamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      String codigoParaVincular = qrData;

      // Verificar se é um deep link e extrair o código
      if (qrData.startsWith('https://app.caremind.online/vincular?codigo=')) {
        Uri uri = Uri.parse(qrData);
        codigoParaVincular = uri.queryParameters['codigo'] ?? qrData;
      }

      final response = await SupabaseService.vincularPorCodigo(codigoParaVincular);

      if (!mounted) return;

      Navigator.of(context).pop(); // Fecha o diálogo de carregamento

      if (response['success'] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Vinculação Concluída'),
            content: Text(
              'Você foi vinculado com sucesso à família de ${response['familiar_nome']}!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Fecha o diálogo de sucesso
                  Navigator.pushReplacementNamed(context, '/individual-dashboard');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Erro na Vinculação'),
            content: Text(response['message'] ?? 'Ocorreu um erro ao tentar vincular as contas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      Navigator.of(context).pop(); // Fecha o diálogo de carregamento

      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Erro'),
          content: Text('Ocorreu um erro ao processar o código. Tente novamente.'),
          actions: [
            TextButton(
              onPressed: null,
              child: Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular Conta'),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.link,
                size: 80,
                color: Color(0xFF0400B9),
              ),
              const SizedBox(height: 24),
              Text(
                'Vincular Conta Familiar',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Escaneie o código QR fornecido pelo seu familiar, clique no link recebido ou insira o código manualmente para vincular as contas.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRScannerScreen(),
                          ),
                        );
                        
                        if (result != null) {
                          _linkController.text = result;
                          await _handleQRCodeResult(result);
                        }
                      },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear Código QR'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'OU',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _linkController,
                decoration: InputDecoration(
                  labelText: 'Código de Vinculação',
                  hintText: 'Digite o código de 6 dígitos ou cole o link de convite',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.link),
                  filled: true,
                  fillColor: colors.surfaceVariant.withOpacity(0.5),
                ),
                keyboardType: TextInputType.text,
                maxLength: 200,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || _linkController.text.isEmpty
                      ? null
                      : () => _handleQRCodeResult(_linkController.text),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Vincular Conta',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Navegar de volta para a tela anterior
                  Navigator.pop(context);
                },
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

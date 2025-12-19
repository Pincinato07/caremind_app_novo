import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';

class ExibirConviteScreen extends StatelessWidget {
  final String codigoConvite;
  final String deepLink;

  const ExibirConviteScreen(
      {Key? key, required this.codigoConvite, required this.deepLink})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convite de Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Compartilhe este código ou QR code com o idoso para que ele possa fazer login no aplicativo pela primeira vez:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            // QR Code com o deep link
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: deepLink.isNotEmpty
                      ? QrImageView(
                          data: deepLink,
                          version: QrVersions.auto,
                          size: 200.0,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        )
                      : const Center(
                          child: Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Escaneie com a câmera do dispositivo ou com o app CareMind',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              'Código: $codigoConvite',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Ou compartilhe o link de convite:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Validar dados antes de compartilhar
                  if (deepLink.isEmpty || codigoConvite.isEmpty) {
                    if (context.mounted) {
                      FeedbackService.showError(
                        context,
                        ErrorHandler.toAppException(
                            Exception('Dados do convite inválidos')),
                      );
                    }
                    return;
                  }

                  await Share.share(
                    'Use este link para fazer login no CareMind: $deepLink\n\nCódigo alternativo: $codigoConvite',
                    subject: 'Convite de Login - CareMind',
                  );
                } on PlatformException catch (e) {
                  debugPrint('Erro ao compartilhar: $e');
                  if (context.mounted) {
                    FeedbackService.showWarning(
                      context,
                      'Erro ao compartilhar: ${e.message ?? "Erro desconhecido"}',
                      action: SnackBarAction(
                        label: 'Copiar Link',
                        textColor: Colors.white,
                        onPressed: () {
                          // Copiar para clipboard seria implementado aqui se necessário
                        },
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Erro inesperado ao compartilhar: $e');
                  if (context.mounted) {
                    FeedbackService.showError(
                      context,
                      ErrorHandler.toAppException(e),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar Link'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Instruções:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '1. Compartilhe o QR code ou link com o idoso\n'
                '2. O idoso pode escanear o QR code com a câmera do celular ou abrir o link\n'
                '3. O app abrirá automaticamente e fará o login\n'
                '4. Após o primeiro login, o idoso poderá usar email e senha normalmente',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

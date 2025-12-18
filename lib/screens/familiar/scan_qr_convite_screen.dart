import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/deep_link/deep_link_handler.dart';
import '../auth/processar_convite_screen.dart';
import '../../theme/app_theme.dart';

/// Tela para escanear QR code de convite
class ScanQrConviteScreen extends StatefulWidget {
  const ScanQrConviteScreen({super.key});

  @override
  State<ScanQrConviteScreen> createState() => _ScanQrConviteScreenState();
}

class _ScanQrConviteScreenState extends State<ScanQrConviteScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _processarCodigo(String codigo) {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    // Tentar parsear como URI primeiro
    final uri = Uri.tryParse(codigo);
    if (uri != null && uri.scheme == 'caremind' && uri.host == 'convite') {
      final token = DeepLinkHandler.extractConviteToken(uri);
      final codigoConvite = DeepLinkHandler.extractConviteCodigo(uri);
      
      if (token != null || codigoConvite != null) {
        final tokenOuCodigo = token ?? codigoConvite!;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProcessarConviteScreen(
              tokenOuCodigo: tokenOuCodigo,
            ),
          ),
        );
        return;
      }
    }

    // Se não for URI, tratar como código direto
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProcessarConviteScreen(
          tokenOuCodigo: codigo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR Code'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processarCodigo(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Overlay com guia de escaneamento
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(),
              child: Container(),
            ),
          ),
          // Instruções
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Posicione o QR code dentro da área de escaneamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O código será processado automaticamente',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Área de escaneamento (quadrado central)
    final scanAreaSize = size.width * 0.7;
    final scanAreaLeft = (size.width - scanAreaSize) / 2;
    final scanAreaTop = (size.height - scanAreaSize) / 2 - 50;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(scanAreaLeft, scanAreaTop, scanAreaSize, scanAreaSize),
      const Radius.circular(20),
    );

    // Desenhar overlay escuro ao redor
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, borderPaint);

    // Desenhar borda do quadrado de escaneamento
    canvas.drawRRect(scanRect, paint);

    // Desenhar cantos decorativos
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Canto superior esquerdo
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + cornerLength),
      Offset(scanAreaLeft, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop),
      Offset(scanAreaLeft + cornerLength, scanAreaTop),
      cornerPaint,
    );

    // Canto superior direito
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + cornerLength),
      cornerPaint,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + cornerLength, scanAreaTop + scanAreaSize),
      cornerPaint,
    );

    // Canto inferior direito
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize - cornerLength, scanAreaTop + scanAreaSize),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize - cornerLength),
      Offset(scanAreaLeft + scanAreaSize, scanAreaTop + scanAreaSize),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


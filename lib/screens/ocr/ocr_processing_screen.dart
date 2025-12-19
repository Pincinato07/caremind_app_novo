import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/ocr_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/wave_background.dart';
import 'ocr_review_screen.dart';

/// Tela de processamento OCR com loading e barra de progresso
class OcrProcessingScreen extends StatefulWidget {
  final String ocrId;
  final String userId;

  const OcrProcessingScreen({
    super.key,
    required this.ocrId,
    required this.userId,
  });

  @override
  State<OcrProcessingScreen> createState() => _OcrProcessingScreenState();
}

class _OcrProcessingScreenState extends State<OcrProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  double _progress = 0.0;
  String _statusMessage = 'Enviando receita...';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _startPolling();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startPolling() async {
    try {
      final supabaseService = GetIt.I<SupabaseService>();
      final ocrService = OcrService(supabaseService.client);

      final result = await ocrService.pollStatus(
        ocrId: widget.ocrId,
        onStatusUpdate: (status) {
          if (!mounted) return;
          setState(() {
            switch (status) {
              case 'PENDENTE':
                _statusMessage = 'Aguardando processamento...';
                break;
              case 'PROCESSANDO':
                _statusMessage = 'Analisando receita...';
                break;
              case 'AGUARDANDO-VALIDACAO':
                _statusMessage = 'Processamento concluído!';
                break;
              default:
                _statusMessage = 'Processando...';
            }
          });
        },
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Extrair medicamentos do resultado
        final medicamentos = ocrService.parseMedicamentosFromResult(
          result['result_json'],
        );

        if (medicamentos.isEmpty) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Nenhum medicamento foi encontrado na receita. '
                'Tente uma foto mais clara ou adicione manualmente.';
          });
          return;
        }

        // Navegar para tela de revisão
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OcrReviewScreen(
              ocrId: widget.ocrId,
              userId: widget.userId,
              medicamentos: medicamentos,
            ),
          ),
        );
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = result['error_message'] as String? ??
              'Erro ao processar a receita. Tente novamente.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const WaveBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // AppBar
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Processando Receita',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),

                  Expanded(
                    child: Center(
                      child:
                          _hasError ? _buildErrorState() : _buildLoadingState(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone animado
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.1),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.document_scanner,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 48),

        // Mensagem de status
        Text(
          _statusMessage,
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Barra de progresso
        SizedBox(
          width: 280,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${(_progress * 100).toInt()}%',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // Dica
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withValues(alpha: 0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Isso pode levar alguns segundos...',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Ícone de erro
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),

        // Título
        Text(
          'Ops! Algo deu errado',
          style: AppTextStyles.headlineSmall.copyWith(
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Mensagem de erro
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _errorMessage ?? 'Erro desconhecido',
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 48),

        // Botões
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Voltar',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      ],
    );
  }
}

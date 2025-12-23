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
              case 'AGUARDANDO_VALIDACAO':
              case 'AGUARDANDO-VALIDACAO': // Suporte para ambos os formatos
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
        // Ícone animado com efeito de pulso
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Círculo de fundo pulsante
                Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.15),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Ícone principal
                Container(
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
              ],
            );
          },
        ),
        const SizedBox(height: 48),

        // Mensagem de status com animação
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _statusMessage,
            key: ValueKey(_statusMessage),
            style: AppTextStyles.headlineSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),

        // Barra de progresso melhorada
        SizedBox(
          width: 280,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 14,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getProgressSubtext(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // Dicas contextuais baseadas no status
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey(_statusMessage),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(),
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _getStatusHint(),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getProgressSubtext() {
    if (_progress < 0.3) return 'Iniciando...';
    if (_progress < 0.6) return 'Processando...';
    if (_progress < 0.9) return 'Quase lá...';
    return 'Finalizando...';
  }

  IconData _getStatusIcon() {
    if (_statusMessage.contains('Enviando')) return Icons.cloud_upload;
    if (_statusMessage.contains('Aguardando')) return Icons.hourglass_empty;
    if (_statusMessage.contains('Analisando')) return Icons.auto_awesome;
    if (_statusMessage.contains('concluído')) return Icons.check_circle;
    return Icons.info_outline;
  }

  String _getStatusHint() {
    if (_statusMessage.contains('Enviando')) {
      return 'Enviando imagem para processamento...';
    }
    if (_statusMessage.contains('Aguardando')) {
      return 'Aguardando processamento na fila...';
    }
    if (_statusMessage.contains('Analisando')) {
      return 'Nossa IA está identificando os medicamentos...';
    }
    if (_statusMessage.contains('concluído')) {
      return 'Processamento concluído com sucesso!';
    }
    return 'Isso pode levar alguns segundos...';
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

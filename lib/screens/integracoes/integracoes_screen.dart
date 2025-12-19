import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../core/injection/injection.dart';
import '../../services/ocr_service.dart';
import '../../services/supabase_service.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';

/// Tela de Integrações com OCR
/// Permite tirar foto de uma receita/caixa de remédio e preencher automaticamente
class IntegracoesScreen extends StatefulWidget {
  final File? initialImage;
  final String? idosoId; // ID do idoso quando familiar está adicionando remédio
  final VoidCallback? onMedicamentosUpdated;

  const IntegracoesScreen({
    super.key,
    this.initialImage,
    this.idosoId,
    this.onMedicamentosUpdated,
  });

  @override
  State<IntegracoesScreen> createState() => _IntegracoesScreenState();
}

class _IntegracoesScreenState extends State<IntegracoesScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  bool _isPolling = false;
  String? _currentStatus;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Se uma imagem inicial foi fornecida, usar ela
    if (widget.initialImage != null) {
      _selectedImage = widget.initialImage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 32.0,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Voltar',
          ),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Leitura de Receita',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tire uma foto da caixa de remédio ou receita',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card principal de instruções
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedCard(
                  index: 0,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingLarge,
                    child: Column(
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 64,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Como usar',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Tire uma foto clara da caixa do remédio ou receita médica\n'
                          '2. Aguarde a leitura automática do texto\n'
                          '3. Revise e confirme as informações',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.large)),

            // Botão de captura de imagem
            if (_selectedImage == null && !_isProcessing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.camera_alt, size: 28),
                        label: Text(
                          'Tirar Foto',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0400BA),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library, size: 24),
                        label: Text(
                          'Escolher da Galeria',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Preview da imagem selecionada
            if (_selectedImage != null && !_isProcessing)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedCard(
                    index: 1,
                    child: CareMindCard(
                      variant: CardVariant.glass,
                      padding: AppSpacing.paddingCard,
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _processImage,
                                  icon: const Icon(Icons.text_fields),
                                  label: Text(
                                    'Ler Texto',
                                    style: AppTextStyles.leagueSpartan(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0400BA),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _clearImage,
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.white,
                                iconSize: 28,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Loading durante upload
            if (_isProcessing && !_isPolling)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedCard(
                    index: 2,
                    child: CareMindCard(
                      variant: CardVariant.glass,
                      padding: AppSpacing.paddingXLarge,
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Enviando foto...',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aguarde enquanto enviamos a imagem',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Polling durante processamento OCR
            if (_isPolling)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedCard(
                    index: 2,
                    child: CareMindCard(
                      variant: CardVariant.glass,
                      padding: AppSpacing.paddingXLarge,
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _getStatusMessage(),
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Aguardando processamento da receita...',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          if (_currentStatus != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Status: $_currentStatus',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Erro
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: AnimatedCard(
                    index: 4,
                    child: CareMindCard(
                      variant: CardVariant.glass,
                      padding: AppSpacing.paddingLarge,
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erro ao processar imagem',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _processImage,
                            child: Text(
                              'Tentar Novamente',
                              style: AppTextStyles.leagueSpartan(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.large)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _error = null;
          _currentStatus = null;
          _isProcessing = false;
          _isPolling = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao capturar imagem: $e';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _error = null;
          _currentStatus = null;
          _isProcessing = false;
          _isPolling = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao selecionar imagem: $e';
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _error = null;
      _currentStatus = null;
      _isProcessing = false;
      _isPolling = false;
    });
  }

  String _getStatusMessage() {
    switch (_currentStatus) {
      case 'PENDENTE':
        return 'Registrando processamento...';
      case 'CONCLUIDO':
        return 'Extraindo medicamentos...';
      default:
        return 'Processando imagem...';
    }
  }

  /// Processa a imagem: upload → registro → polling
  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    final ocrService = getIt<OcrService>();
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Usuário não autenticado';
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _currentStatus = null;
    });

    try {
      // 1. Upload da imagem e registro no banco
      // Se idosoId foi fornecido (familiar), usar ele; senão usar userId
      final targetId = widget.idosoId ?? user.id;
      debugPrint('📤 Fazendo upload e registro...');
      final ocrId = await ocrService.uploadImageAndRegister(
        imageFile: _selectedImage!,
        userId: targetId,
      );

      setState(() {
        _isProcessing = false;
        _isPolling = true;
        _currentStatus = 'PENDENTE';
      });

      // 2. Iniciar polling para verificar status
      debugPrint('🔄 Iniciando polling para OCR ID: $ocrId');
      final resultado = await ocrService.pollStatus(
        ocrId: ocrId,
        onStatusUpdate: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
            });
          }
        },
        timeout: 600, // 10 minutos
        interval: 5, // 5 segundos
      );

      if (mounted) {
        if (resultado['success'] == true) {
          // Sucesso: medicamentos foram inseridos automaticamente
          final count = resultado['medicamentos_count'] as int? ?? 0;

          setState(() {
            _isPolling = false;
            _currentStatus = resultado['status'] as String;
          });

          // Mostrar mensagem de sucesso
          _showSuccessMessage(
            count > 0
                ? 'Receita processada! $count medicamento(s) adicionado(s).'
                : 'Receita processada com sucesso!',
          );

          // Limpar imagem após sucesso
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _clearImage();
            }
          });

          // Chamar callback para atualizar lista de medicamentos
          widget.onMedicamentosUpdated?.call();

          // Retornar true para indicar sucesso
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          // Erro no processamento
          final errorMsg = resultado['error_message'] as String? ??
              'Não foi possível processar a receita.';

          setState(() {
            _isPolling = false;
            _error = errorMsg;
            _currentStatus = null;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Erro no processamento OCR: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isPolling = false;
          _error =
              e is AppException ? e.message : 'Erro ao processar imagem: $e';
          _currentStatus = null;
        });
      }
    }
  }

  void _showSuccessMessage(String message) {
    FeedbackService.showSuccess(
      context,
      message,
      duration: const Duration(seconds: 4),
    );
  }
}

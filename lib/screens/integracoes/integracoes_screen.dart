import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/caremind_card.dart';
import '../../models/ocr_medicamento.dart';
import '../../core/injection/injection.dart';
import '../../services/ocr_service.dart';
import '../../services/supabase_service.dart';
import '../../services/profile_service.dart';
import '../../utils/timezone_utils.dart';
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
  List<OcrMedicamento> _extractedMeds = [];
  bool _isValidating = false;
  String? _currentOcrId;

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

            
            if (_isValidating) _buildValidationList(),
            
            if (!_isValidating) ...[
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

                ),
              ),
            ],
            
            if (!_isValidating) SliverToBoxAdapter(child: SizedBox(height: AppSpacing.large)),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationList() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            CareMindCard(
              variant: CardVariant.glass,
              padding: AppSpacing.paddingSmall,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'REVISÃO OBRIGATÓRIA: Verifique as dosagens e nomes antes de confirmar.',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._extractedMeds.asMap().entries.map((entry) {
              final idx = entry.key;
              final med = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: CareMindCard(
                  variant: CardVariant.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xFF0400BA),
                              child: Text('${idx + 1}', style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: med.nome,
                                decoration: const InputDecoration(labelText: 'Nome do Remédio'),
                                onChanged: (val) => med.nome = val,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _extractedMeds.removeAt(idx)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: med.dosagem,
                                decoration: const InputDecoration(labelText: 'Dosagem (ex: 500mg)'),
                                onChanged: (val) => med.dosagem = val,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: med.frequencia,
                                decoration: const InputDecoration(labelText: 'Frequência (ex: 8/8h)'),
                                onChanged: (val) => med.frequencia = val,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _finalizarConfirmacao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'CONFIRMAR E SALVAR',
                  style: AppTextStyles.leagueSpartan(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isValidating = false),
              child: const Text('Cancelar e voltar', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizarConfirmacao() async {
    if (_extractedMeds.isEmpty) {
      FeedbackService.showErrorMessage(context, 'Nenhum medicamento para salvar.');
      return;
    }

    setState(() => _isProcessing = true);
    final ocrService = getIt<OcrService>();
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final targetId = widget.idosoId ?? user!.id;
    
    // Buscar perfil_id real
    final perfil = await supabaseService.getProfile(targetId);
    if (perfil == null) return;

    try {
      await ocrService.salvarMedicamentosValidados(
        medicamentos: _extractedMeds,
        perfilId: perfil.id,
        userId: targetId,
      );

      if (_currentOcrId != null) {
        await ocrService.marcarComoValidado(_currentOcrId!);
      }

      if (mounted) {
        _showSuccessMessage('Medicamentos salvos com sucesso!');
        widget.onMedicamentosUpdated?.call();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.showErrorMessage(context, 'Erro ao salvar: $e');
        setState(() => _isProcessing = false);
      }
    }
  }
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
      _isValidating = false;
      _extractedMeds = [];
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
      _currentOcrId = ocrId;
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
          // Extrair medicamentos para validação obrigatória
          final meds = ocrService.parseMedicamentosFromResult(resultado['result_json']);

          setState(() {
            _isPolling = false;
            _extractedMeds = meds;
            _isValidating = true;
            _currentStatus = resultado['status'] as String;
          });

          // Anunciar para acessibilidade
          if (meds.isNotEmpty) {
            FeedbackService.showSuccess(context, 'Receita lida! Por favor, revise os ${meds.length} medicamentos encontrados.');
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

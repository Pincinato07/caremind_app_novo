import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import '../../services/ocr_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/wave_background.dart';
import '../../core/state/familiar_state.dart';
import 'ocr_processing_screen.dart';

/// Tela para captura de imagem da receita médica
class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _captureImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      final File imageFile = File(image.path);
      await _processImage(imageFile);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao capturar imagem: $e';
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final supabaseService = GetIt.I<SupabaseService>();
      final ocrService = OcrService(supabaseService.client);
      
      // Obter userId - pode ser do idoso selecionado ou do usuário atual
      final familiarState = GetIt.I<FamiliarState>();
      final String userId;
      
      if (familiarState.idosoSelecionado != null) {
        // Familiar gerenciando idoso - usar o perfil_id diretamente
        userId = familiarState.idosoSelecionado!.id;
      } else {
        // Usuário próprio
        final currentUser = supabaseService.currentUser;
        if (currentUser == null) {
          throw Exception('Usuário não autenticado');
        }
        userId = currentUser.id;
      }

      // Fazer upload e registrar
      final ocrId = await ocrService.uploadImageAndRegister(
        imageFile: imageFile,
        userId: userId,
      );

      if (!mounted) return;

      // Navegar para tela de processamento
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OcrProcessingScreen(
            ocrId: ocrId,
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
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
            child: Column(
              children: [
                // AppBar customizada
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Escanear Receita',
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
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ícone principal
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.document_scanner_outlined,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Título
                        Text(
                          'Importe sua Receita',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Descrição
                        Text(
                          'Tire uma foto ou selecione uma imagem da sua receita médica. '
                          'Nosso sistema irá extrair automaticamente os medicamentos.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Erro
                        if (_errorMessage != null) ...[
                          AnimatedCard(
                            index: 0,
                            child: CareMindCard(
                              variant: CardVariant.glass,
                              borderColor: AppColors.error.withValues(alpha: 0.5),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error),
                                  SizedBox(width: AppSpacing.small + 4),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(color: AppColors.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.large),
                        ],

                        // Botões de ação
                        if (_isLoading)
                          const CircularProgressIndicator(color: Colors.white)
                        else ...[
                          // Botão Câmera
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _captureImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Tirar Foto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botão Galeria
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _captureImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Escolher da Galeria'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Dicas
                        AnimatedCard(
                          index: 1,
                          child: CareMindCard(
                            variant: CardVariant.glass,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.amber.shade300,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Dicas para melhor resultado:',
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildTip('Certifique-se que a receita está bem iluminada'),
                              _buildTip('Evite sombras sobre o documento'),
                              _buildTip('Mantenha a câmera estável'),
                              _buildTip('Inclua todo o texto da receita na foto'),
                            ],
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


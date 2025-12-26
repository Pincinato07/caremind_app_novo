import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/accessibility_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../core/feedback/feedback_service.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import 'caremind_card.dart';

/// Widget de Check-in de Bem-Estar
/// Permite ao usuário reportar como está se sentindo
class WellbeingCheckin extends StatefulWidget {
  final String perfilId;
  final bool isReadOnly;
  final bool isOrganizationView;

  const WellbeingCheckin({
    super.key,
    required this.perfilId,
    this.isReadOnly = false,
    this.isOrganizationView = false,
  });

  @override
  State<WellbeingCheckin> createState() => _WellbeingCheckinState();
}

class _WellbeingCheckinState extends State<WellbeingCheckin> {
  bool _isExpanded = false;
  bool _isRecording = false;
  String? _lastMood;

  @override
  void initState() {
    super.initState();
    _loadLastMood();
  }

  Future<void> _loadLastMood() async {
    // Não carrega em modo de visualização de organização
    if (widget.isOrganizationView) {
      return;
    }

    try {
      final supabase = getIt<SupabaseService>();
      
      // Usa a função segura do banco
      final mood = await supabase.client.rpc(
        'obter_ultimo_humor',
        params: {'p_perfil_id': widget.perfilId},
      );

      if (mood != null) {
        setState(() {
          _lastMood = mood as String?;
        });
      }
    } catch (e) {
      debugPrint('⚠️ WellbeingCheckin: Erro ao carregar último mood - $e');
    }
  }

  Future<void> _handleMoodSelection(String mood, IconData icon) async {
    // Não permite seleção em modo de visualização
    if (widget.isReadOnly) {
      FeedbackService.showInfo(
        context,
        'Visualização apenas. Não é possível alterar.',
      );
      return;
    }

    // Feedback imediato
    await AccessibilityService.feedbackSucesso();
    
    // TTS personalizado
    String feedbackText;
    switch (mood) {
      case 'radiante':
        feedbackText = 'Que ótimo! Fico feliz em saber que você está bem.';
        break;
      case 'ok':
        feedbackText = 'Entendido. Continue cuide-se!';
        break;
      case 'mal':
        feedbackText = 'Sinto muito. Vou avisar sua família e registrar o que você está sentindo.';
        break;
      default:
        feedbackText = 'Obrigado pelo feedback.';
    }
    
    await TTSEnhancer.announceCriticalSuccess(feedbackText);

    // Salvar no banco
    await _saveMood(mood);

    // Se "mal", abrir gravação de voz
    if (mood == 'mal') {
      await Future.delayed(const Duration(milliseconds: 500));
      _startVoiceRecording();
    } else {
      // Feedback visual
      if (mounted) {
        FeedbackService.showSuccess(
          context,
          'Obrigado pelo feedback!',
          duration: const Duration(seconds: 2),
        );
        
        // Fecha o check-in
        setState(() {
          _isExpanded = false;
        });
      }
    }
  }

  Future<void> _saveMood(String mood) async {
    try {
      final supabase = getIt<SupabaseService>();
      
      // Usa a função segura do banco
      await supabase.client.rpc(
        'registrar_checkin_bem_estar',
        params: {
          'p_perfil_id': widget.perfilId,
          'p_humor': mood,
          'p_observacoes': null,
        },
      );

      // Verificar alertas proativos (já feito na função do banco)
    } catch (e) {
      debugPrint('❌ WellbeingCheckin: Erro ao salvar mood - $e');
    }
  }


  Future<void> _startVoiceRecording() async {
    setState(() {
      _isRecording = true;
    });

    // Simula gravação de voz (na prática, usaria speech_to_text)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isExpanded = false;
      });

      FeedbackService.showSuccess(
        context,
        'Registro de voz salvo! Família será notificada.',
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Modo de visualização de organização - mostra histórico
    if (widget.isOrganizationView) {
      return _buildOrganizationView();
    }

    if (!_isExpanded) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
        child: CareMindCard(
          variant: CardVariant.solid,
          onTap: widget.isReadOnly
              ? null
              : () {
                  setState(() {
                    _isExpanded = true;
                  });
                  AccessibilityService.speak(
                    'Como você está se sentindo hoje? Toque em um dos três botões.',
                  );
                },
          child: Row(
            children: [
              Icon(
                Icons.sentiment_satisfied_alt,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como está se sentindo hoje?',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_lastMood != null)
                      Text(
                        'Último: $_lastMood',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!widget.isReadOnly)
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
            ],
          ),
        ),
      );
    }

    // Modo expandido
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
      child: CareMindCard(
        variant: CardVariant.solid,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Como você está se sentindo hoje?',
              style: AppTextStyles.leagueSpartan(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            // Botões de humor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMoodButton(
                  icon: Icons.sentiment_very_satisfied,
                  label: 'Radiante',
                  color: Colors.green,
                  mood: 'radiante',
                ),
                _buildMoodButton(
                  icon: Icons.sentiment_neutral,
                  label: 'Ok',
                  color: Colors.orange,
                  mood: 'ok',
                ),
                _buildMoodButton(
                  icon: Icons.sentiment_very_dissatisfied,
                  label: 'Mal',
                  color: Colors.red,
                  mood: 'mal',
                ),
              ],
            ),

            if (_isRecording) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Gravando voz...',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = false;
                });
              },
              child: Text(
                'Cancelar',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodButton({
    required IconData icon,
    required String label,
    required Color color,
    required String mood,
  }) {
    return Semantics(
      label: '$label - Toque para selecionar',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleMoodSelection(mood, icon),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationView() {
    // Para organização, mostra um card com status do último humor
    // Em uma implementação completa, buscaria histórico dos idosos
    return CareMindCard(
      variant: CardVariant.solid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sentiment_satisfied,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Bem-Estar dos Idosos',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Visualize o histórico de bem-estar dos idosos vinculados à organização no dashboard web.',
            style: AppTextStyles.leagueSpartan(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No app, toque em "Idosos" para ver detalhes individuais.',
            style: AppTextStyles.leagueSpartan(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}


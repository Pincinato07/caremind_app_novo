import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'package:vibration/vibration.dart';
import '../../services/supabase_service.dart';
import '../../services/emergencia_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';

/// Tela de Ajuda/Emergência para o perfil IDOSO
class AjudaScreen extends StatefulWidget {
  const AjudaScreen({super.key});

  @override
  State<AjudaScreen> createState() => _AjudaScreenState();
}

class _AjudaScreenState extends State<AjudaScreen> {
  String? _telefoneCuidador;
  String? _nomeCuidador;
  bool _isLoading = true;
  bool _isDisparandoEmergencia = false;
  final EmergenciaService _emergenciaService = EmergenciaService();

  @override
  void initState() {
    super.initState();
    _carregarTelefoneCuidador();
  }

  Future<void> _carregarTelefoneCuidador() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final cuidador = await supabaseService.getCuidadorPrincipal(user.id);
        
        if (mounted) {
          setState(() {
            _telefoneCuidador = cuidador?['telefone'] as String?;
            _nomeCuidador = cuidador?['nome'] as String?;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Aciona botão de pânico - dispara alerta para TODOS os familiares
  /// Envia SMS, notificações push e registra no histórico
  Future<void> _acionarPanico() async {
    if (_isDisparandoEmergencia) return;

    // Confirmação antes de acionar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          '🚨 Confirmar Emergência',
          style: AppTextStyles.leagueSpartan(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Isso enviará alertas de emergência para TODOS os seus familiares via SMS e notificações. Deseja continuar?',
          style: AppTextStyles.leagueSpartan(
            fontSize: 16,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'SIM, ACIONAR',
              style: AppTextStyles.leagueSpartan(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isDisparandoEmergencia = true);

    // Vibração forte para feedback tátil
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate(duration: 1000);
    }

    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        throw UnknownException(message: 'Usuário não autenticado');
      }

      // Acionar emergência via Edge Function
      final resultado = await _emergenciaService.acionarPanico(
        idosoId: user.id,
      );

      // Feedback de sucesso
      await AccessibilityService.speak(
        'Alerta de emergência enviado para ${resultado['familiares_notificados']} familiar(es).',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🚨 Alerta enviado para ${resultado['familiares_notificados']} familiar(es)!',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      await AccessibilityService.speak('Erro ao acionar emergência. Tente ligar diretamente.');

      if (mounted) {
        final errorMessage = e is AppException
            ? e.message
            : 'Erro ao acionar emergência: $e';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Erro ao Acionar Emergência',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
            content: Text(
              errorMessage,
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (_telefoneCuidador != null && _telefoneCuidador!.isNotEmpty)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _ligarParaFamiliar();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'LIGAR DIRETO',
                    style: AppTextStyles.leagueSpartan(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDisparandoEmergencia = false);
      }
    }
  }

  Future<void> _ligarParaFamiliar() async {
    if (_telefoneCuidador == null || _telefoneCuidador!.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Número não disponível',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Nenhum número de emergência cadastrado. Peça para seu familiar configurar o telefone no aplicativo.',
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: AppTextStyles.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Formatar telefone para URL (remover caracteres não numéricos)
    final telefoneLimpo = _telefoneCuidador!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$telefoneLimpo');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Dispositivo não suportado',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Este dispositivo não possui capacidade de fazer chamadas telefônicas.',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: AppTextStyles.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AppException
            ? e.message
            : 'Erro ao iniciar chamada: $e';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      '🚨 Emergência',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Precisa de ajuda imediata?',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // BOTÃO DE PÂNICO GIGANTE (Principal)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: AnimatedCard(
                  index: 0,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingXLarge,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'BOTÃO DE PÂNICO',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Envia alerta para TODOS os familiares via SMS e notificações',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 100, // Botão GIGANTE para acessibilidade
                          child: ElevatedButton(
                            onPressed: _isDisparandoEmergencia ? null : _acionarPanico,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 8,
                              shadowColor: Colors.red.withValues(alpha: 0.5),
                            ),
                            child: _isDisparandoEmergencia
                                ? const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 4,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning, size: 36),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'ACIONAR EMERGÊNCIA',
                                            style: AppTextStyles.leagueSpartan(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.5,
                                            ),
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
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Botão de ligação direta (secundário)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                child: AnimatedCard(
                  index: 1,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingLarge,
                    child: Column(
                      children: [
                        Text(
                          'Ou ligue diretamente',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: ElevatedButton.icon(
                            onPressed: _ligarParaFamiliar,
                            icon: const Icon(Icons.phone, size: 28),
                            label: Text(
                              'LIGAR PARA FAMILIAR',
                              style: AppTextStyles.leagueSpartan(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Informações de contato
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                child: AnimatedCard(
                  index: 2,
                  child: CareMindCard(
                    variant: CardVariant.glass,
                    padding: AppSpacing.paddingLarge,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informações de Contato',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                        else if (_nomeCuidador != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Familiar: $_nomeCuidador',
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (_telefoneCuidador != null && _telefoneCuidador!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Telefone: $_telefoneCuidador',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '⚠️ Telefone não cadastrado',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color: Colors.orange.shade300,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          Text(
                            'Nenhum familiar vinculado encontrado.',
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '💡 Dica: O botão de pânico envia alertas para TODOS os seus familiares cadastrados, mesmo que você não tenha o telefone deles.',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.bottomNavBarPadding)),
          ],
        ),
      ),
    );
  }
}



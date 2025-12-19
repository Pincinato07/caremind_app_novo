import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/persistent_bottom_nav_bar.dart';
import '../../widgets/premium/premium_guard.dart';
import '../../services/supabase_service.dart';
import '../../services/settings_service.dart';
import '../../services/alexa_auth_service.dart';
import '../../services/accessibility_service.dart';
import '../../services/subscription_service.dart';
import '../../core/injection/injection.dart';
import '../../core/accessibility/accessibility_helper.dart';
import '../organizacao/organizacao_lista_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../services/notification_service.dart';
import 'dart:io' show Platform;

/// Tela de Configurações
/// Centraliza configurações do app
class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final SupabaseService _supabaseService = getIt<SupabaseService>();
  final SettingsService _settingsService = getIt<SettingsService>();
  final AlexaAuthService _alexaAuthService = getIt<AlexaAuthService>();
  bool _isLoading = true;
  bool _wavesEnabled = true; // Default on
  bool _isSaving = false;
  bool _isAlexaLinked = false;
  bool _isLinkingAlexa = false;
  final _telefoneController = TextEditingController();
  String? _perfilTipo;

  @override
  void initState() {
    super.initState();
    // Inicializar SettingsService ANTES de tudo
    _settingsService.initialize().then((_) {
      _loadPerfilTipo();
      _loadTelefoneEmergencia();
      _checkAlexaStatus();
      _wavesEnabled = _settingsService.wavesEnabled;
    });
    // Inicializa o serviço de acessibilidade
    AccessibilityService.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Leitura automática do título da tela se habilitada
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AccessibilityHelper.autoReadIfEnabled('Configurações. Ajuste as preferências do aplicativo.');
    });
  }

  Future<void> _loadPerfilTipo() async {
    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        final perfil = await _supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _perfilTipo = perfil.tipo?.toLowerCase();
          });
        }
      }
    } catch (e) {
      // Se não conseguir carregar, continua sem o campo de telefone
    }
  }

  Future<void> _checkAlexaStatus() async {
    final isLinked = await _alexaAuthService.isLinked();
    if (mounted) {
      setState(() => _isAlexaLinked = isLinked);
    }
  }

  Future<void> _linkAlexa() async {
    if (_isLinkingAlexa) return;
    
    setState(() => _isLinkingAlexa = true);
    
    try {
      await _alexaAuthService.startLinking();
      // O resultado será processado quando o app receber o deep link
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar Alexa: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLinkingAlexa = false);
      }
    }
  }

  Future<void> _unlinkAlexa() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular Alexa'),
        content: const Text('Deseja realmente desvincular sua conta Alexa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _alexaAuthService.unlink();
      if (mounted) {
        setState(() => _isAlexaLinked = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alexa desvinculada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desvincular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTelefoneEmergencia() async {
    // Só carrega telefone se não for familiar
    if (_perfilTipo == 'familiar') {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        final perfil = await _supabaseService.getProfile(user.id);
        if (perfil != null && mounted) {
          setState(() {
            _telefoneController.text = perfil.telefone ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTelefoneEmergencia() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final user = _supabaseService.currentUser;
      if (user == null) return;

      await _supabaseService.updateProfile(
        userId: user.id,
        telefone: _telefoneController.text.trim().isEmpty 
            ? null 
            : _telefoneController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Telefone de emergência salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar telefone: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Configurações',
        showBackButton: true,
      ),
      bottomNavigationBar: PersistentBottomNavBar(
        currentIndex: -1, // No tab selected for settings
        onTap: (index) {
          // Navigate back to main screen and select tab
          Navigator.of(context).pop();
          // The navigation shell will handle the tab selection
        },
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                    // Seção: Emergência (apenas para Idoso e Individual)
                    if (_perfilTipo != 'familiar')
                      _buildSection(
                        context,
                        title: '🚨 Emergência',
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                            child: AnimatedCard(
                              index: 0,
                              child: CareMindCard(
                                variant: CardVariant.glass,
                                padding: AppSpacing.paddingLarge,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Telefone de Emergência',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Este número será usado para enviar SMS quando o botão de pânico for acionado.',
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.8),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _telefoneController,
                                    keyboardType: TextInputType.phone,
                                    style: AppTextStyles.leagueSpartan(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '+55 11 99999-9999',
                                      hintStyle: AppTextStyles.leagueSpartan(
                                        color: Colors.white.withValues(alpha: 0.5),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.1),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Semantics(
                                      label: 'Botão salvar telefone',
                                      hint: 'Toque para salvar o número de telefone de emergência',
                                      button: true,
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _saveTelefoneEmergencia,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Color(0xFF0400BA),
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                'Salvar Telefone',
                                                style: AppTextStyles.leagueSpartan(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Seção: Aparência
                    _buildSection(
                      context,
                      title: '🎨 Aparência',
                      children: [
                        _buildThemeModeTile(context),
                      ],
                    ),

                    // Seção: Notificações
                    ListenableBuilder(
                      listenable: _settingsService,
                      builder: (context, _) {
                        return _buildSection(
                          context,
                          title: '🔔 Notificações',
                          children: [
                            _buildSwitchTile(
                              context,
                              icon: Icons.notifications_outlined,
                              title: 'Notificações de Medicamentos',
                              subtitle: 'Receber lembretes de horários',
                              value: _settingsService.notificationsMedicamentos,
                              onChanged: (value) async {
                                await _settingsService.setNotificationsMedicamentos(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Notificações de medicamentos ativadas' 
                                          : 'Notificações de medicamentos desativadas',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.calendar_today_rounded,
                              title: 'Notificações de Compromissos',
                              subtitle: 'Receber lembretes de compromissos',
                              value: _settingsService.notificationsCompromissos,
                              onChanged: (value) async {
                                await _settingsService.setNotificationsCompromissos(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Notificações de compromissos ativadas' 
                                          : 'Notificações de compromissos desativadas',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            // Botão para configurar bypass de DND (apenas Android)
                            if (Platform.isAndroid)
                              _buildDndBypassTile(context),
                          ],
                        );
                      },
                    ),

                    // Seção: Organizações
                    _buildSection(
                      context,
                      title: '🏢 Organizações',
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          child: AnimatedCard(
                            index: 1,
                            child: CareMindCard(
                              variant: CardVariant.glass,
                              padding: AppSpacing.paddingLarge,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProviderScope(
                                      child: const OrganizacaoListaScreen(),
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(AppSpacing.small + 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.business,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gerenciar Organizações',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Criar e gerenciar organizações (casas de repouso, clínicas)',
                                          style: AppTextStyles.leagueSpartan(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha: 0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Seção: Integrações
                    _buildSection(
                      context,
                      title: '🔗 Integrações',
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          child: AnimatedCard(
                            index: 1,
                            child: CareMindCard(
                              variant: CardVariant.glass,
                              padding: AppSpacing.paddingLarge,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Image.asset(
                                        'assets/images/alexa-logo.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Amazon Alexa',
                                            style: AppTextStyles.leagueSpartan(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _isAlexaLinked 
                                                ? 'Conta vinculada' 
                                                : 'Não vinculada',
                                            style: AppTextStyles.leagueSpartan(
                                              fontSize: 14,
                                              color: _isAlexaLinked 
                                                  ? Colors.greenAccent 
                                                  : Colors.white.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_isAlexaLinked)
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.greenAccent,
                                        size: 28,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Vincule sua conta Amazon para receber lembretes de medicamentos pela Alexa.',
                                  style: AppTextStyles.leagueSpartan(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: PremiumGuard(
                                    isEnabled: getIt<SubscriptionService>().canUseAlexa,
                                    mode: PremiumGuardMode.blockTouch,
                                    child: ElevatedButton.icon(
                                      onPressed: _isLinkingAlexa 
                                          ? null 
                                          : (_isAlexaLinked ? _unlinkAlexa : () async {
                                              final subscriptionService = getIt<SubscriptionService>();
                                              await subscriptionService.getPermissions();
                                              if (subscriptionService.canUseAlexa && mounted) {
                                                _linkAlexa();
                                              }
                                            }),
                                      icon: _isLinkingAlexa
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF0400BA),
                                                ),
                                              ),
                                            )
                                          : Icon(_isAlexaLinked 
                                              ? Icons.link_off 
                                              : Icons.link),
                                      label: Text(
                                        _isAlexaLinked 
                                            ? 'Desvincular Alexa' 
                                            : 'Vincular Alexa',
                                        style: AppTextStyles.leagueSpartan(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isAlexaLinked 
                                            ? Colors.red.shade400 
                                            : Colors.white,
                                        foregroundColor: _isAlexaLinked 
                                            ? Colors.white 
                                            : AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Seção: Acessibilidade
                    ListenableBuilder(
                      listenable: _settingsService,
                      builder: (context, _) {
                        return _buildSection(
                          context,
                          title: '♿ Acessibilidade',
                          children: [
                            _buildSwitchTile(
                              context,
                              icon: Icons.volume_up_outlined,
                              title: 'Falar Textos',
                              subtitle: 'Text-to-Speech para leitura',
                              value: _settingsService.accessibilityTtsEnabled,
                              onChanged: (value) async {
                                await _settingsService.setAccessibilityTtsEnabled(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Fala de textos ativada' 
                                          : 'Fala de textos desativada',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.vibration_rounded,
                              title: 'Vibração',
                              subtitle: 'Feedback háptico nas ações',
                              value: _settingsService.accessibilityVibrationEnabled,
                              onChanged: (value) async {
                                await _settingsService.setAccessibilityVibrationEnabled(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Vibração ativada' 
                                          : 'Vibração desativada',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.contrast_rounded,
                              title: 'Alto Contraste',
                              subtitle: 'Melhor visibilidade para leitura',
                              value: _settingsService.accessibilityHighContrast,
                              onChanged: (value) async {
                                await _settingsService.setAccessibilityHighContrast(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Alto contraste ativado' 
                                          : 'Alto contraste desativado',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.record_voice_over_outlined,
                              title: 'Leitura Automática',
                              subtitle: 'Ler textos automaticamente',
                              value: _settingsService.accessibilityAutoRead,
                              onChanged: (value) async {
                                await _settingsService.setAccessibilityAutoRead(value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Leitura automática ativada' 
                                          : 'Leitura automática desativada',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.waves_rounded,
                              title: 'Animações de Ondas',
                              subtitle: 'Fundo animado das ondas',
                              value: _wavesEnabled,
                              onChanged: (value) async {
                                await _settingsService.setWavesEnabled(value);
                                setState(() => _wavesEnabled = value);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value 
                                          ? 'Ondas ativadas' 
                                          : 'Ondas desativadas',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                            // Slider para tamanho de fonte
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.25),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.text_fields_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Tamanho da Fonte',
                                          style: AppTextStyles.leagueSpartan(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(_settingsService.accessibilityFontScale * 100).toInt()}%',
                                        style: AppTextStyles.leagueSpartan(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Slider(
                                    value: _settingsService.accessibilityFontScale,
                                    min: 0.8,
                                    max: 2.0,
                                    divisions: 12,
                                    label: '${(_settingsService.accessibilityFontScale * 100).toInt()}%',
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white.withValues(alpha: 0.3),
                                    onChanged: (value) async {
                                      await _settingsService.setAccessibilityFontScale(value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Slider para velocidade de voz
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.white.withValues(alpha: 0.25),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.speed_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Velocidade de Fala',
                                          style: AppTextStyles.leagueSpartan(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(_settingsService.accessibilityVoiceSpeed * 100).toInt()}%',
                                        style: AppTextStyles.leagueSpartan(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Slider(
                                    value: _settingsService.accessibilityVoiceSpeed,
                                    min: 0.3,
                                    max: 1.0,
                                    divisions: 7,
                                    label: '${(_settingsService.accessibilityVoiceSpeed * 100).toInt()}%',
                                    activeColor: Colors.white,
                                    inactiveColor: Colors.white.withValues(alpha: 0.3),
                                    onChanged: (value) async {
                                      await _settingsService.setAccessibilityVoiceSpeed(value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),


              const SizedBox(height: 24),
              // Espaço para navbar inferior
              const SizedBox(height: AppSpacing.bottomNavBarPadding),
            ],
          ),
        ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Text(
            title,
            style: AppTextStyles.leagueSpartan(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        secondary: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: AppTextStyles.leagueSpartan(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }

  Future<void> _saveThemePreference(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final modeString = mode.toString().split('.').last;
      if (modeString.isEmpty) {
        throw Exception('String de tema vazia');
      }
      
      final success = await prefs.setString('theme_mode', modeString);
      if (!success) {
        throw Exception('Falha ao salvar preferência');
      }
      
      // Atualizar o tema usando o método estático do CareMindApp
      try {
        CareMindApp.changeThemeMode(mode);
      } catch (e) {
        debugPrint('⚠️ Erro ao atualizar tema imediatamente: $e');
        // Continuar mesmo se falhar, o tema será aplicado na próxima inicialização
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mode == ThemeMode.dark 
                ? 'Modo escuro ativado'
                : 'Modo claro ativado',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Erro ao salvar preferência de tema: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = 'Erro ao salvar preferência';
        if (e.toString().contains('SharedPreferences')) {
          errorMessage = 'Erro de armazenamento. Tente novamente.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Erro de conexão. Verifique sua internet.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Colors.white,
              onPressed: () => _saveThemePreference(mode),
            ),
          ),
        );
      }
    }
  }

  Widget _buildThemeModeTile(BuildContext context) {
    final currentTheme = Theme.of(context).brightness;
    final isDark = currentTheme == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        secondary: Icon(
          isDark ? Icons.dark_mode : Icons.light_mode,
          color: Colors.white,
        ),
        title: Text(
          'Modo Escuro',
          style: AppTextStyles.leagueSpartan(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          isDark ? 'Tema escuro ativado' : 'Tema claro ativado',
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        value: isDark,
        onChanged: (value) {
          // Salvar preferência e recarregar app
          _saveThemePreference(value ? ThemeMode.dark : ThemeMode.light);
        },
        activeColor: Colors.white,
        activeTrackColor: Colors.white.withValues(alpha: 0.5),
        inactiveThumbColor: Colors.grey[300],
        inactiveTrackColor: Colors.grey[400]?.withValues(alpha: 0.5),
      ),
    );
  }

  /// Widget para configurar bypass de DND
  Widget _buildDndBypassTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.3),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(
          Icons.do_not_disturb_off,
          color: Colors.white,
        ),
        title: Text(
          'Modo Não Perturbe',
          style: AppTextStyles.leagueSpartan(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          'Permitir alertas mesmo em modo Não Perturbe',
          style: AppTextStyles.leagueSpartan(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: () async {
          await NotificationService.showDndBypassDialog(context);
        },
      ),
    );
  }
}

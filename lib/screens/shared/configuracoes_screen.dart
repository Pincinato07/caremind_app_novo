import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../../services/supabase_service.dart';
import '../../services/settings_service.dart';
import '../../core/injection/injection.dart';

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
  bool _isLoading = true;
  bool _isSaving = false;
  final _telefoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTelefoneEmergencia();
  }

  @override
  void dispose() {
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTelefoneEmergencia() async {
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
      appBar: const CareMindAppBar(
        title: 'Configurações',
        showBackButton: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Seção: Emergência
                    _buildSection(
                      context,
                      title: '🚨 Emergência',
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                          child: GlassCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.phone_outlined,
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
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _saveTelefoneEmergencia,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0400BA),
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
                              ],
                            ),
                          ),
                        ),
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
                              icon: Icons.notifications_active,
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
                              icon: Icons.event_available,
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
                          ],
                        );
                      },
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
                              icon: Icons.volume_up,
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
                              icon: Icons.vibration,
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
                              icon: Icons.contrast,
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
                              icon: Icons.record_voice_over,
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
                                        Icons.text_fields,
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
                                        Icons.speed,
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
            ],
          ),
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
        activeColor: const Color(0xFF0400BA),
      ),
    );
  }
}


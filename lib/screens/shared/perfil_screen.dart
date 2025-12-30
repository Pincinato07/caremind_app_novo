// lib/screens/perfil_screen.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../../models/perfil.dart';
import '../../services/supabase_service.dart';
import '../../services/lgpd_service.dart';
import '../../services/medicamento_service.dart';
import '../../services/compromisso_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/state/familiar_state.dart';
import '../../services/account_manager_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/nav_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'trocar_conta_screen.dart';
import '../../utils/timezone_utils.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  bool _isLoggingOut = false;
  bool _isExporting = false;
  bool _isDeleting = false;
  bool _isLoading = true;
  bool _isSaving = false;

  final SupabaseService _supabaseService = getIt<SupabaseService>();
  Perfil? _perfil;
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  String? _fotoUrl;
  File? _fotoLocal;
  String? _selectedTimezone;

  // Lista de timezones brasileiros principais
  static const List<Map<String, String>> _timezones = [
    {'value': 'America/Sao_Paulo', 'label': 'Brasília (UTC-3)'},
    {'value': 'America/Manaus', 'label': 'Manaus (UTC-4)'},
    {'value': 'America/Campo_Grande', 'label': 'Campo Grande (UTC-4)'},
    {'value': 'America/Rio_Branco', 'label': 'Rio Branco (UTC-5)'},
    {'value': 'America/Fortaleza', 'label': 'Fortaleza (UTC-3)'},
    {'value': 'America/Recife', 'label': 'Recife (UTC-3)'},
    {'value': 'America/Bahia', 'label': 'Bahia (UTC-3)'},
    {'value': 'America/Belem', 'label': 'Belém (UTC-3)'},
    {'value': 'America/Araguaina', 'label': 'Araguaína (UTC-3)'},
    {'value': 'America/Maceio', 'label': 'Maceió (UTC-3)'},
    {'value': 'America/Noronha', 'label': 'Fernando de Noronha (UTC-2)'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabaseService.currentUser;

      if (user == null) {
        if (mounted) {
          _showError('Usuário não encontrado');
        }
        return;
      }

      final perfil = await _supabaseService.getProfile(user.id);

      if (perfil != null && mounted) {
        setState(() {
          _perfil = perfil;
          _nomeController.text = perfil.nome ?? '';
          _emailController.text = user.email ?? '';
          _telefoneController.text = perfil.telefone ?? '';
          _selectedTimezone = perfil.timezone ?? 'America/Sao_Paulo';

          // Obter URL da foto se existir
          if (perfil.fotoUsuario != null && perfil.fotoUsuario!.isNotEmpty) {
            // Se já é uma URL completa, usar diretamente
            if (perfil.fotoUsuario!.startsWith('http')) {
              _fotoUrl = perfil.fotoUsuario;
            } else {
              // Se é um caminho no bucket, obter URL pública
              // Assumindo bucket 'avatars' ou similar
              try {
                final supabaseClient = _supabaseService.client;
                _fotoUrl = supabaseClient.storage
                    .from('avatars')
                    .getPublicUrl(perfil.fotoUsuario!);
              } catch (e) {
                debugPrint('Erro ao obter URL da foto: $e');
              }
            }
          }

          _isLoading = false;
        });

        // Verificar se o timezone do dispositivo mudou e atualizar automaticamente
        _checkAndUpdateTimezone(perfil);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Erro ao carregar perfil: $e');
      }
    }
  }

  /// Verifica se o timezone do dispositivo é diferente do perfil
  /// Se for diferente, atualiza automaticamente
  Future<void> _checkAndUpdateTimezone(Perfil perfil) async {
    try {
      final deviceTimezone = TimezoneUtils.getCurrentTimezone();
      final profileTimezone = perfil.timezone ?? 'America/Sao_Paulo';

      if (deviceTimezone != profileTimezone) {
        debugPrint('⏳ Timezone do dispositivo ($deviceTimezone) diferente do perfil ($profileTimezone). Atualizando...');

        final user = _supabaseService.currentUser;
        if (user == null) return;

        await _supabaseService.updateProfile(
          userId: user.id,
          timezone: deviceTimezone,
        );

        if (mounted) {
          setState(() {
            _selectedTimezone = deviceTimezone;
          });
          _showSuccess('Fuso horário atualizado automaticamente para: ${TimezoneUtils.formatTimezoneLabel(deviceTimezone)}');
        }

        debugPrint('✅ Timezone atualizado com sucesso!');
      }
    } catch (e) {
      debugPrint('⚠️ Falha ao atualizar timezone automaticamente: $e');
      // Não mostra erro ao usuário, apenas loga
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _fotoLocal = File(pickedFile.path);
        _fotoUrl = null; // Limpar URL antiga ao selecionar nova foto
      });
      await _savePhoto();
    }
  }

  Future<void> _savePhoto() async {
    if (_fotoLocal == null) return;

    try {
      setState(() {
        _isSaving = true;
      });

      final user = _supabaseService.currentUser;

      if (user == null) return;

      final supabaseClient = _supabaseService.client;

      // Upload da foto para o bucket
      final fileName =
          '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageBytes = await _fotoLocal!.readAsBytes();

      await supabaseClient.storage.from('avatars').uploadBinary(
          fileName, imageBytes,
          fileOptions: const FileOptions(upsert: true));

      // Obter URL pública
      final publicUrl =
          supabaseClient.storage.from('avatars').getPublicUrl(fileName);

      // Atualizar perfil com o caminho da foto
      await _supabaseService.updateProfile(
        userId: user.id,
        fotoUsuario: fileName, // Salvar o caminho, não a URL completa
      );

      if (mounted) {
        setState(() {
          _fotoUrl = publicUrl;
          _fotoLocal = null;
          _isSaving = false;
        });

        // Recarregar perfil
        await _loadProfile();

        // Atualizar informações da conta salva
        final accountManager = AccountManagerService();
        final currentUser = _supabaseService.currentUser;
        if (currentUser != null && _perfil != null) {
          await accountManager.updateAccountInfo(
            userId: currentUser.id,
            fotoUrl: publicUrl,
          );
        }

        FeedbackService.showSuccess(context, 'Foto atualizada com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError('Erro ao salvar foto: $e');
      }
    }
  }

  Future<void> _saveField(String field, String value) async {
    try {
      // Validações de campos
      if (field == 'nome') {
        final trimmedValue = value.trim();
        if (trimmedValue.isEmpty) {
          _showError('O nome não pode estar vazio');
          return;
        }
        if (trimmedValue.length < 2) {
          _showError('O nome deve ter pelo menos 2 caracteres');
          return;
        }
        if (trimmedValue.length > 100) {
          _showError('O nome não pode ter mais de 100 caracteres');
          return;
        }
        value = trimmedValue;
      } else if (field == 'telefone') {
        final trimmedValue = value.trim();
        // Se não estiver vazio, validar formato
        if (trimmedValue.isNotEmpty) {
          // Remove caracteres não numéricos para validação
          final digitsOnly = trimmedValue.replaceAll(RegExp(r'[^\d]'), '');
          if (digitsOnly.length < 10 || digitsOnly.length > 11) {
            _showError(
                'Telefone inválido. Use o formato (XX) XXXXX-XXXX ou (XX) XXXX-XXXX');
            return;
          }
          // Formatar telefone (opcional, pode manter o formato original)
          value = trimmedValue;
        }
      } else if (field == 'timezone') {
        // Validar se o timezone está na lista permitida
        final isValidTimezone = _timezones.any((tz) => tz['value'] == value);
        if (!isValidTimezone) {
          _showError('Fuso horário inválido');
          return;
        }
      }

      setState(() {
        _isSaving = true;
      });

      final user = _supabaseService.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          _showError('Usuário não encontrado. Faça login novamente.');
        }
        return;
      }

      switch (field) {
        case 'nome':
          await _supabaseService.updateProfile(
            userId: user.id,
            nome: value,
          );
          break;
        case 'telefone':
          await _supabaseService.updateProfile(
            userId: user.id,
            telefone: value.isEmpty ? null : value,
          );
          break;
        case 'timezone':
          await _supabaseService.updateProfile(
            userId: user.id,
            timezone: value,
          );
          break;
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        // Recarregar perfil
        await _loadProfile();

        // Atualizar informações da conta salva
        final accountManager = AccountManagerService();
        final currentUser = _supabaseService.currentUser;
        if (currentUser != null && _perfil != null) {
          if (field == 'nome') {
            await accountManager.updateAccountInfo(
              userId: currentUser.id,
              nome: value,
            );
          }
        }

        FeedbackService.showSuccess(
            context, 'Informação atualizada com sucesso!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        // Mensagens de erro mais específicas
        String errorMessage = 'Erro ao salvar';

        if (e is AppException) {
          errorMessage = e.message;
        } else {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('network') ||
              errorString.contains('connection') ||
              errorString.contains('timeout')) {
            errorMessage =
                'Erro de conexão. Verifique sua internet e tente novamente.';
          } else if (errorString.contains('permission') ||
              errorString.contains('unauthorized')) {
            errorMessage = 'Você não tem permissão para realizar esta ação.';
          } else if (errorString.contains('constraint') ||
              errorString.contains('violates')) {
            errorMessage =
                'Dados inválidos. Verifique os campos e tente novamente.';
          } else {
            errorMessage = 'Erro ao salvar: ${e.toString()}';
          }
        }

        _showError(errorMessage);
      }
    }
  }

  Future<void> _handleTrocarConta() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TrocarContaScreen(),
      ),
    );
  }

  void _handleNavigationTap(int index) {
    // Fazer pop e voltar para a tela principal
    Navigator.of(context).pop();
    // A navegação principal já está ativa, então não precisamos fazer nada mais
  }

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos;

    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Meu Perfil',
        showBackButton: true,
        isFamiliar: isFamiliar,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.98),
              Colors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(
                icon: Icons.home_rounded,
                label: 'Início',
                isSelected: false,
                onTap: () => _handleNavigationTap(0),
              ),
              NavItem(
                icon: Icons.medication_liquid,
                label: 'Medicamentos',
                isSelected: false,
                onTap: () => _handleNavigationTap(1),
              ),
              NavItem(
                icon: Icons.schedule_rounded,
                label: 'Rotina',
                isSelected: false,
                onTap: () => _handleNavigationTap(2),
              ),
              NavItem(
                icon: Icons.settings_applications_rounded,
                label: 'Gestão',
                isSelected: true, // Perfil está dentro de Gestão
                onTap: () => _handleNavigationTap(3),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Foto do perfil
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Hero(
                                tag:
                                    'profile_image_${_perfil?.id ?? 'default'}',
                                child: Builder(
                                  builder: (context) {
                                    try {
                                      if (_fotoUrl != null &&
                                          _fotoUrl!.isNotEmpty) {
                                        return Image.network(
                                          _fotoUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            debugPrint(
                                                '⚠️ Erro ao carregar foto de perfil: $error');
                                            return Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.2),
                                              child: const Icon(
                                                Icons.person_rounded,
                                                size: 60,
                                                color: Colors.white,
                                              ),
                                            );
                                          },
                                        );
                                      } else if (_fotoLocal != null) {
                                        try {
                                          return Image.file(
                                            _fotoLocal!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              debugPrint(
                                                  '⚠️ Erro ao carregar foto local: $error');
                                              return Container(
                                                color: Colors.white
                                                    .withValues(alpha: 0.2),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  size: 60,
                                                  color: Colors.white,
                                                ),
                                              );
                                            },
                                          );
                                        } catch (e) {
                                          debugPrint(
                                              '⚠️ Erro ao processar foto local: $e');
                                          return Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          );
                                        }
                                      } else {
                                        return Container(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        );
                                      }
                                    } catch (e, stackTrace) {
                                      debugPrint(
                                          '❌ Erro ao construir imagem de perfil: $e');
                                      debugPrint('Stack trace: $stackTrace');
                                      return Container(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          size: 60,
                                          color: Colors.white,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0400BA),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Informações do usuário (editáveis)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        _buildEditableField(
                          label: 'Nome',
                          controller: _nomeController,
                          icon: Icons.person_outline,
                          onSave: () =>
                              _saveField('nome', _nomeController.text),
                        ),
                        const SizedBox(height: 16),
                        _buildReadOnlyField(
                          label: 'Email',
                          value: _emailController.text,
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildEditableField(
                          label: 'Telefone de Emergência',
                          controller: _telefoneController,
                          icon: Icons.phone_outlined,
                          onSave: () =>
                              _saveField('telefone', _telefoneController.text),
                        ),
                        const SizedBox(height: 16),
                        _buildTimezoneField(),
                        const SizedBox(height: 16),
                        _buildReadOnlyField(
                          label: 'Tipo de Conta',
                          value: _perfil?.tipo == 'individual'
                              ? 'Individual'
                              : _perfil?.tipo == 'familiar'
                                  ? 'Familiar'
                                  : _perfil?.tipo == 'idoso'
                                      ? 'Idoso'
                                      : 'Não definido',
                          icon: Icons.account_circle_outlined,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Seção LGPD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LGPD - Privacidade',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSmallButton(
                          icon: Icons.description_outlined,
                          text: 'Termos de Uso',
                          onTap: () async {
                            final uri =
                                Uri.parse('https://caremind.com.br/termos');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSmallButton(
                          icon: Icons.privacy_tip_outlined,
                          text: 'Política de Privacidade',
                          onTap: () async {
                            final uri = Uri.parse(
                                'https://caremind.com.br/politica-privacidade');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildSmallButton(
                          icon: Icons.download_outlined,
                          text: 'Exportar Meus Dados',
                          onTap: _isExporting ? null : _handleExportData,
                          isLoading: _isExporting,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botões de ação destrutiva (menores e mais visíveis)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        _buildDestructiveButton(
                          icon: Icons.delete_outline,
                          text: 'Excluir Conta',
                          onTap: _isDeleting ? null : _handleDeleteAccount,
                          isLoading: _isDeleting,
                        ),
                        const SizedBox(height: 12),
                        _buildDestructiveButton(
                          icon: Icons.swap_horiz,
                          text: 'Trocar de Conta',
                          onTap: _isLoggingOut ? null : _handleTrocarConta,
                          isLoading: _isLoggingOut,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Espaço para navbar inferior
                  const SizedBox(height: AppSpacing.bottomNavBarPadding),
                ],
              ),
            ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required VoidCallback onSave,
  }) {
    return AnimatedCard(
      index: 0,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingCard,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                style: AppTextStyles.leagueSpartan(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: AppTextStyles.leagueSpartan(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => onSave(),
              ),
            ),
            _isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade300,
                      size: 24,
                    ),
                    onPressed: onSave,
                    tooltip: 'Salvar',
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimezoneField() {
    return AnimatedCard(
      index: 0,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingCard,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.access_time, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fuso Horário',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: _selectedTimezone ?? 'America/Sao_Paulo',
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    underline: Container(),
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: _timezones.map((tz) {
                      return DropdownMenuItem<String>(
                        value: tz['value'],
                        child: Text(tz['label']!),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedTimezone = newValue;
                        });
                        _saveField('timezone', newValue);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return AnimatedCard(
      index: 0,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingCard,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return AnimatedCard(
      index: 3,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: EdgeInsets.symmetric(
            vertical: AppSpacing.small + 4, horizontal: AppSpacing.medium),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestructiveButton({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportData() async {
    setState(() => _isExporting = true);

    try {
      // Verificar se o usuário está autenticado
      final user = _supabaseService.currentUser;

      if (user == null) {
        if (mounted) {
          _showError('Usuário não encontrado. Faça login novamente.');
        }
        return;
      }

      // Verificar se os serviços estão disponíveis
      MedicamentoService? medicamentoService;
      CompromissoService? compromissoService;

      try {
        medicamentoService = getIt<MedicamentoService>();
        compromissoService = getIt<CompromissoService>();
      } catch (e) {
        if (mounted) {
          _showError(
              'Erro ao inicializar serviços. Tente novamente mais tarde.');
        }
        return;
      }

      // Criar serviço LGPD
      final lgpdService = LgpdService(
        _supabaseService,
        medicamentoService,
        compromissoService,
      );

      // Exportar dados
      String jsonData;
      try {
        jsonData = await lgpdService.exportUserDataAsJson(user.id);
      } catch (e) {
        String errorMessage = 'Erro ao gerar dados para exportação';

        if (e is Exception) {
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('network') ||
              errorString.contains('connection') ||
              errorString.contains('timeout')) {
            errorMessage =
                'Erro de conexão. Verifique sua internet e tente novamente.';
          } else if (errorString.contains('permission') ||
              errorString.contains('unauthorized')) {
            errorMessage = 'Você não tem permissão para exportar dados.';
          } else if (errorString.contains('nenhum dado')) {
            errorMessage = 'Nenhum dado encontrado para exportar.';
          } else {
            errorMessage = 'Erro ao gerar dados: ${e.toString()}';
          }
        }

        if (mounted) {
          _showError(errorMessage);
        }
        return;
      }

      // Validar se os dados foram gerados
      if (jsonData.isEmpty) {
        if (mounted) {
          _showError('Nenhum dado foi gerado para exportação.');
        }
        return;
      }

      // Compartilhar arquivo JSON
      try {
        await Share.share(
          jsonData,
          subject: 'Meus Dados - CareMind',
        );

        if (mounted) {
          FeedbackService.showSuccess(context, 'Dados exportados com sucesso!');
        }
      } catch (e) {
        if (mounted) {
          _showError('Erro ao compartilhar arquivo. Tente novamente.');
        }
      }
    } catch (e) {
      String errorMessage = 'Erro ao exportar dados';

      if (e is AppException) {
        errorMessage = e.message;
      } else {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('network') ||
            errorString.contains('connection') ||
            errorString.contains('timeout')) {
          errorMessage =
              'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (errorString.contains('permission') ||
            errorString.contains('unauthorized')) {
          errorMessage = 'Você não tem permissão para realizar esta ação.';
        } else {
          errorMessage = 'Erro ao exportar dados: ${e.toString()}';
        }
      }

      if (mounted) {
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await AppNavigation.showAppDialog<bool>(
      context: context,
      title: '⚠️ Excluir Conta Permanentemente',
      message:
          'Esta ação não pode ser desfeita. Todos os seus dados serão excluídos permanentemente:\n\n'
          '• Todos os medicamentos\n'
          '• Todos os compromissos\n'
          '• Dados do perfil\n\n'
          'Tem certeza absoluta?',
      confirmText: 'Sim, Excluir',
      cancelText: 'Cancelar',
      isDestructive: true,
    );

    if (confirm != true) return;

    final confirm2 = await AppNavigation.showAppDialog<bool>(
      context: context,
      title: 'Última Confirmação',
      message:
          'Para confirmar, digite "EXCLUIR" (sem aspas) na caixa abaixo.\n\n'
          'Esta é sua última chance de cancelar.',
      confirmText: 'Confirmar Exclusão',
      cancelText: 'Cancelar',
      isDestructive: true,
    );

    if (confirm2 != true) return;

    setState(() => _isDeleting = true);

    try {
      // Usando _supabaseService já definido
      final user = _supabaseService.currentUser;

      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      final lgpdService = LgpdService(
        _supabaseService,
        getIt<MedicamentoService>(),
        getIt<CompromissoService>(),
      );

      await lgpdService.deleteUserData(user.id);
      await _supabaseService.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );

      FeedbackService.showSuccess(
        context,
        'Conta excluída com sucesso',
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDeleting = false);

      final errorMessage =
          e is AppException ? e.message : 'Erro ao excluir conta: $e';
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    FeedbackService.showError(
        context, ErrorHandler.toAppException(Exception(message)));
  }

  void _showSuccess(String message) {
    FeedbackService.showSuccess(context, message);
  }
}

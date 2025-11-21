// lib/screens/perfil_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../core/navigation/app_navigation.dart';
import '../../core/state/familiar_state.dart';
import '../../services/account_manager_service.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/glass_card.dart';
import '../lgpd/termos_privacidade_screen.dart';
import 'trocar_conta_screen.dart';

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
          _telefoneController.text = ''; // Telefone não está no modelo Perfil atual
          
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
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageBytes = await _fotoLocal!.readAsBytes();
      
      await supabaseClient.storage
          .from('avatars')
          .uploadBinary(fileName, imageBytes, fileOptions: const FileOptions(upsert: true));

      // Obter URL pública
      final publicUrl = supabaseClient.storage
          .from('avatars')
          .getPublicUrl(fileName);

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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
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
      setState(() {
        _isSaving = true;
      });

      final user = _supabaseService.currentUser;
      
      if (user == null) return;

      switch (field) {
        case 'nome':
          await _supabaseService.updateProfile(
            userId: user.id,
            nome: value,
          );
          break;
        // Telefone e email podem precisar de tratamento diferente
        // Por enquanto, apenas nome é suportado no updateProfile
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
          await accountManager.updateAccountInfo(
            userId: currentUser.id,
            nome: value,
          );
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informação atualizada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError('Erro ao salvar: $e');
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

  @override
  Widget build(BuildContext context) {
    final familiarState = getIt<FamiliarState>();
    final isFamiliar = familiarState.hasIdosos;
    
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Meu Perfil',
        isFamiliar: isFamiliar,
      ),
      body: SafeArea(
        child: _isLoading
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
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _fotoUrl != null || _fotoLocal != null
                                    ? Image(
                                        image: _fotoLocal != null
                                            ? FileImage(_fotoLocal!)
                                            : NetworkImage(_fotoUrl!) as ImageProvider,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.white.withOpacity(0.2),
                                            child: const Icon(
                                              Icons.person_rounded,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.white.withOpacity(0.2),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          size: 60,
                                          color: Colors.white,
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
                            onSave: () => _saveField('nome', _nomeController.text),
                          ),
                          const SizedBox(height: 16),
                          _buildReadOnlyField(
                            label: 'Email',
                            value: _emailController.text,
                            icon: Icons.email_outlined,
                          ),
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
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildSmallButton(
                            icon: Icons.description_outlined,
                            text: 'Termos de Uso',
                            onTap: () {
                              Navigator.push(
                                context,
                                AppNavigation.smoothRoute(
                                  const TermosPrivacidadeScreen(showTerms: true),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildSmallButton(
                            icon: Icons.privacy_tip_outlined,
                            text: 'Política de Privacidade',
                            onTap: () {
                              Navigator.push(
                                context,
                                AppNavigation.smoothRoute(
                                  const TermosPrivacidadeScreen(showTerms: false),
                                ),
                              );
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
                  ],
                ),
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.leagueSpartan(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: GoogleFonts.leagueSpartan(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => onSave(),
            ),
          ),
          IconButton(
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
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
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
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.leagueSpartan(
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
    );
  }

  Widget _buildSmallButton({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  style: GoogleFonts.leagueSpartan(
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
                  color: Colors.white.withOpacity(0.6),
                ),
            ],
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
            color: Colors.red.withOpacity(0.3),
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
                  style: GoogleFonts.leagueSpartan(
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

      final jsonData = await lgpdService.exportUserDataAsJson(user.id);

      // Compartilhar arquivo JSON
      await Share.share(
        jsonData,
        subject: 'Meus Dados - CareMind',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados exportados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao exportar dados: $e';
      _showError(errorMessage);
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta excluída com sucesso'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isDeleting = false);

      final errorMessage = e is AppException
          ? e.message
          : 'Erro ao excluir conta: $e';
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

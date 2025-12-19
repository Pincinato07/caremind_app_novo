import 'package:flutter/material.dart';
import '../../services/organizacao_service.dart';
import '../../core/injection/injection.dart';
import '../../core/feedback/feedback_service.dart';
import '../../theme/app_theme.dart';

/// Tela para criar nova organização
class CriarOrganizacaoScreen extends StatefulWidget {
  const CriarOrganizacaoScreen({super.key});

  @override
  State<CriarOrganizacaoScreen> createState() => _CriarOrganizacaoScreenState();
}

class _CriarOrganizacaoScreenState extends State<CriarOrganizacaoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final OrganizacaoService _organizacaoService = getIt<OrganizacaoService>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _criarOrganizacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await _organizacaoService.criarOrganizacao(
      nome: _nomeController.text.trim(),
      cnpj: _cnpjController.text.trim().isEmpty
          ? null
          : _cnpjController.text.trim(),
      telefone: _telefoneController.text.trim().isEmpty
          ? null
          : _telefoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
    );

    if (!mounted) return;

    result.when(
      success: (_) {
        FeedbackService.showSuccess(context, 'Organização criada com sucesso!');
        Navigator.pop(context, true);
      },
      failure: (exception) {
        FeedbackService.showError(context, exception);
      },
    );

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Organização'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card explicativo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primaryLight.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.business_center,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'O que é uma Organização?',
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Para instituições de saúde',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Crie uma organização se você trabalha em ou gerencia:',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      icon: Icons.home,
                      text: 'Casas de repouso e ILPIs',
                    ),
                    _buildInfoItem(
                      icon: Icons.local_hospital,
                      text: 'Clínicas e hospitais',
                    ),
                    _buildInfoItem(
                      icon: Icons.medical_services,
                      text: 'Consultórios médicos',
                    ),
                    _buildInfoItem(
                      icon: Icons.people,
                      text: 'Equipes de cuidadores',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.info,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Você precisa ter uma conta no CareMind para criar uma organização.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Dados da Organização',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Preencha as informações básicas. Você poderá editar depois.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome da Organização *',
                  hintText: 'Ex: Casa de Repouso Vida Feliz',
                  prefixIcon: const Icon(Icons.business),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                style: AppTextStyles.bodyLarge,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cnpjController,
                decoration: InputDecoration(
                  labelText: 'CNPJ (opcional)',
                  hintText: '00.000.000/0000-00',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                style: AppTextStyles.bodyLarge,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefoneController,
                decoration: InputDecoration(
                  labelText: 'Telefone (opcional)',
                  hintText: '(11) 98765-4321',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                style: AppTextStyles.bodyLarge,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email (opcional)',
                  hintText: 'contato@organizacao.com.br',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                style: AppTextStyles.bodyLarge,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _criarOrganizacao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Criar Organização',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

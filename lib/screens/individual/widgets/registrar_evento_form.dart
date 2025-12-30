import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_scaffold_with_waves.dart';
import '../../../widgets/caremind_app_bar.dart';
import '../../../widgets/caremind_card.dart';
import '../../../services/historico_eventos_service.dart';
import '../../../services/supabase_service.dart';
import '../../../core/injection/injection.dart';
import '../../../core/feedback/feedback_service.dart';
import 'package:go_router/go_router.dart';

class RegistrarEventoForm extends StatefulWidget {
  final String? idosoId;

  const RegistrarEventoForm({super.key, this.idosoId});

  @override
  State<RegistrarEventoForm> createState() => _RegistrarEventoFormState();
}

class _RegistrarEventoFormState extends State<RegistrarEventoForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      // Se idosoId não foi passado, usamos o ID do usuário (perfil individual)
      final perfilId = widget.idosoId ?? user.id;

      await HistoricoEventosService.addEvento({
        'perfil_id': perfilId,
        'tipo_evento': 'ocorrencia',
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'data_prevista': DateTime.now().toIso8601String(),
        'status': 'confirmado', // Ocorrências manuais já nascem confirmadas
      });

      if (mounted) {
        FeedbackService.showSuccess(context, 'Ocorrência registrada com sucesso!');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        FeedbackService.showError(context, Exception('Erro ao registrar: $e'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: const CareMindAppBar(
        title: 'Registrar Ocorrência',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O que aconteceu?',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registre quedas, dores, mudanças de humor ou qualquer evento relevante.',
                style: AppTextStyles.leagueSpartan(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              CareMindCard(
                variant: CardVariant.glass,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: 'Título da Ocorrência',
                        hintText: 'Ex: Senti tontura, Queda no banheiro...',
                        filled: true,
                        fillColor: Colors.white12,
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Informe um título' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição (Opcional)',
                        hintText: 'Dê mais detalhes sobre o ocorrido...',
                        filled: true,
                        fillColor: Colors.white12,
                      ),
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Salvar Ocorrência',
                          style: AppTextStyles.leagueSpartan(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

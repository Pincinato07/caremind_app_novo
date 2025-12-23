import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../services/ocr_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/wave_background.dart';
import '../../models/ocr_medicamento.dart';

/// Tela de revisão e confirmação dos medicamentos extraídos via OCR
class OcrReviewScreen extends StatefulWidget {
  final String ocrId;
  final String userId;
  final List<OcrMedicamento> medicamentos;

  const OcrReviewScreen({
    super.key,
    required this.ocrId,
    required this.userId,
    required this.medicamentos,
  });

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  late List<OcrMedicamento> _medicamentos;
  // IMPORTANTE: Manter cópia dos dados originais do OCR para preservar informações
  late List<OcrMedicamento> _medicamentosOriginais;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Criar cópia editável para o usuário modificar
    _medicamentos = List.from(widget.medicamentos);
    // IMPORTANTE: Preservar dados originais do OCR (deep copy)
    _medicamentosOriginais = widget.medicamentos.map((m) => OcrMedicamento(
      nome: m.nome,
      dosagem: m.dosagem,
      frequencia: m.frequencia,
      quantidade: m.quantidade,
      via: m.via,
    )).toList();
  }

  void _adicionarMedicamento() {
    setState(() {
      _medicamentos.add(OcrMedicamento(
        nome: '',
        dosagem: '',
        frequencia: '1x ao dia',
        quantidade: 30,
      ));
    });
  }

  void _removerMedicamento(int index) {
    if (_medicamentos.length > 1) {
      setState(() {
        _medicamentos.removeAt(index);
      });
    } else {
      FeedbackService.showWarning(
        context,
        'Você precisa ter pelo menos um medicamento',
      );
    }
  }

  Future<void> _salvarMedicamentos() async {
    if (!_formKey.currentState!.validate()) return;

    // Filtrar medicamentos com nome vazio
    final medicamentosValidos =
        _medicamentos.where((m) => m.nome.trim().isNotEmpty).toList();

    if (medicamentosValidos.isEmpty) {
      FeedbackService.showError(
        context,
        ErrorHandler.toAppException(
            Exception('Adicione pelo menos um medicamento com nome')),
      );
      return;
    }

    // IMPORTANTE: Confirmar cada medicamento individualmente antes de salvar
    // Isso garante que o usuário revise e confirme cada remédio, evitando alucinações da IA
    // Usar os dados EDITADOS pelo usuário (se houver) ou os ORIGINAIS do OCR
    final medicamentosConfirmados = <OcrMedicamento>[];
    
    for (int i = 0; i < medicamentosValidos.length; i++) {
      if (!mounted) return;
      
      final medicamentoEditado = medicamentosValidos[i];
      // Buscar dados originais do OCR para comparação (se existir no mesmo índice)
      final temOriginal = i < _medicamentosOriginais.length;
      final medicamentoOriginal = temOriginal ? _medicamentosOriginais[i] : null;
      
      // Verificar se houve edição comparando com original
      bool foiEditado = false;
      if (temOriginal && medicamentoOriginal != null) {
        foiEditado = (
          medicamentoEditado.nome != medicamentoOriginal.nome ||
          medicamentoEditado.dosagem != medicamentoOriginal.dosagem ||
          medicamentoEditado.frequencia != medicamentoOriginal.frequencia ||
          medicamentoEditado.quantidade != medicamentoOriginal.quantidade
        );
      }
      
      final confirmado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Medicamento'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirma que este remédio é o "${medicamentoEditado.nome}"?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dosagem: ${medicamentoEditado.dosagem.isNotEmpty ? medicamentoEditado.dosagem : "Não informada"}',
                ),
                Text(
                  'Frequência: ${medicamentoEditado.frequencia}',
                ),
                Text(
                  'Quantidade: ${medicamentoEditado.quantidade}',
                ),
                if (foiEditado && temOriginal && medicamentoOriginal != null) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    '⚠️ Este medicamento foi editado. Dados originais do OCR:',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nome original: ${medicamentoOriginal.nome}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  if (medicamentoOriginal.dosagem.isNotEmpty)
                    Text(
                      'Dosagem original: ${medicamentoOriginal.dosagem}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não, corrigir'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim, confirmar'),
            ),
          ],
        ),
      );

      if (confirmado == true) {
        // Salvar os dados EDITADOS (se houver) ou os ORIGINAIS do OCR
        medicamentosConfirmados.add(medicamentoEditado);
      } else {
        // Usuário cancelou a confirmação deste medicamento
        // Continuar com os próximos, mas não salvar este
        continue;
      }
    }

    // Se nenhum medicamento foi confirmado, cancelar
    if (medicamentosConfirmados.isEmpty) {
      FeedbackService.showWarning(
        context,
        'Nenhum medicamento foi confirmado. Nenhum medicamento será salvo.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabaseService = GetIt.I<SupabaseService>();
      final ocrService = OcrService(supabaseService.client);

      // Buscar perfil_id do usuário
      final perfilResponse = await supabaseService.client
          .from('perfis')
          .select('id')
          .eq('user_id', widget.userId)
          .single();

      final perfilId = perfilResponse['id'] as String;

      // Salvar apenas medicamentos confirmados
      final salvos = await ocrService.salvarMedicamentosValidados(
        medicamentos: medicamentosConfirmados,
        perfilId: perfilId,
        userId: widget.userId,
      );

      // Marcar OCR como validado
      await ocrService.marcarComoValidado(widget.ocrId);

      if (!mounted) return;

      // Mostrar sucesso e voltar
      FeedbackService.showSuccess(
        context,
        '${salvos.length} medicamento(s) importado(s) com sucesso!',
      );

      // Voltar para a tela anterior (gestão de medicamentos)
      Navigator.of(context).popUntil((route) =>
          route.isFirst ||
          route.settings.name == '/medicamentos' ||
          route.settings.name == '/gestao');
    } catch (e) {
      if (!mounted) return;
      FeedbackService.showError(context, ErrorHandler.toAppException(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                // AppBar
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
                          'Revisar Medicamentos',
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

                // Cabeçalho
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedCard(
                    index: 0,
                    child: CareMindCard(
                      variant: CardVariant.glass,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_medicamentos.length} medicamento(s) encontrado(s)',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Revise e edite os dados antes de salvar',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.medium),

                // Lista de medicamentos
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount:
                          _medicamentos.length + 1, // +1 para botão adicionar
                      itemBuilder: (context, index) {
                        if (index == _medicamentos.length) {
                          return _buildBotaoAdicionar();
                        }
                        return _buildMedicamentoCard(index);
                      },
                    ),
                  ),
                ),

                // Botão salvar
                Container(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _salvarMedicamentos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.5),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Confirmar Importação',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Widget _buildMedicamentoCard(int index) {
    final medicamento = _medicamentos[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedCard(
        index: 1,
        child: CareMindCard(
          variant: CardVariant.glass,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com número e botão remover
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Medicamento ${index + 1}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.error.withValues(alpha: 0.8),
                    ),
                    onPressed: () => _removerMedicamento(index),
                    tooltip: 'Remover medicamento',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nome
              _buildCampo(
                label: 'Nome do Medicamento',
                value: medicamento.nome,
                onChanged: (value) {
                  setState(() {
                    _medicamentos[index] = medicamento.copyWith(nome: value);
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Dosagem e Quantidade
              Row(
                children: [
                  Expanded(
                    child: _buildCampo(
                      label: 'Dosagem',
                      value: medicamento.dosagem,
                      hint: 'Ex: 500mg',
                      onChanged: (value) {
                        setState(() {
                          _medicamentos[index] =
                              medicamento.copyWith(dosagem: value);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCampo(
                      label: 'Quantidade',
                      value: medicamento.quantidade.toString(),
                      hint: 'Ex: 30',
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _medicamentos[index] = medicamento.copyWith(
                            quantidade: int.tryParse(value) ?? 30,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Frequência
              _buildCampo(
                label: 'Frequência',
                value: medicamento.frequencia,
                hint: 'Ex: 2x ao dia, 8/8h',
                onChanged: (value) {
                  setState(() {
                    _medicamentos[index] =
                        medicamento.copyWith(frequencia: value);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampo({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: Colors.orangeAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildBotaoAdicionar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _adicionarMedicamento,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 12),
              Text(
                'Adicionar Medicamento',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

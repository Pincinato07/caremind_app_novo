import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/medicamento.dart';
import '../../services/medicamento_service.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../../core/errors/result.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_button.dart';

class AddEditMedicamentoForm extends StatefulWidget {
  final Medicamento? medicamento;
  final String? idosoId; // ID do idoso quando familiar está adicionando remédio

  const AddEditMedicamentoForm({super.key, this.medicamento, this.idosoId});

  @override
  State<AddEditMedicamentoForm> createState() => _AddEditMedicamentoFormState();
}

class _AddEditMedicamentoFormState extends State<AddEditMedicamentoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dosagemController = TextEditingController();
  final _quantidadeController = TextEditingController();

  String _tipoFrequencia = 'diario';
  int _vezesPorDia = 1;
  List<String> _diasSemana = [];
  String _descricaoPersonalizada = '';

  bool _isLoading = false;
  bool _isAnalyzing = false;
  bool get _isEditing => widget.medicamento != null;

  final List<String> _diasDaSemana = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadMedicamentoData();
    }
  }

  void _loadMedicamentoData() {
    final medicamento = widget.medicamento!;
    _nomeController.text = medicamento.nome;
    _dosagemController.text = medicamento.dosagem ?? '';
    _quantidadeController.text = medicamento.quantidade?.toString() ?? '';

    // Carrega dados da frequência
    final frequencia = medicamento.frequencia;
    if (frequencia != null && frequencia.containsKey('tipo')) {
      _tipoFrequencia = frequencia['tipo'];

      switch (_tipoFrequencia) {
        case 'diario':
          _vezesPorDia = frequencia['vezes_por_dia'] ?? 1;
          break;
        case 'semanal':
          _diasSemana = List<String>.from(frequencia['dias_semana'] ?? []);
          break;
        case 'personalizado':
          _descricaoPersonalizada = frequencia['descricao'] ?? '';
          break;
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _dosagemController.dispose();
    _quantidadeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFrequenciaJson() {
    switch (_tipoFrequencia) {
      case 'diario':
        return {
          'tipo': 'diario',
          'vezes_por_dia': _vezesPorDia,
        };
      case 'semanal':
        return {
          'tipo': 'semanal',
          'dias_semana': _diasSemana,
        };
      case 'personalizado':
        return {
          'tipo': 'personalizado',
          'descricao': _descricaoPersonalizada,
        };
      default:
        return {'tipo': 'diario', 'vezes_por_dia': 1};
    }
  }

  Future<Map<String, dynamic>> _checkSafety(String nome, String dosagem) async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      final user = supabaseService.currentUser;

      if (user == null) return {'status': 'safe', 'bypass': true};

      final targetUserId = widget.idosoId ?? user.id;

      // Get history
      final result = await medicamentoService.getMedicamentos(targetUserId);
      List<String> historico = [];
      
      // Handle Result type manually since generics might be tricky with `is`
      result.fold(
          (success) => historico = success.map((m) => m.nome).toList(),
          (failure) => historico = []
      );

      final response = await supabaseService.client.functions.invoke(
        'caremind-ai-analyst',
        body: {
          'medicamento': nome,
          'dosagem': dosagem.isNotEmpty ? dosagem : 'Não informada',
          'historico': historico,
        },
      );

      final data = response.data;
      if (data == null) return {'status': 'safe', 'bypass': true};

      return Map<String, dynamic>.from(data as Map);

    } catch (e) {
      debugPrint('AI Analysis failed: $e');
      return {'status': 'safe', 'bypass': true};
    }
  }

  Future<void> _saveMedicamento({bool forceSave = false}) async {
    if (!_formKey.currentState!.validate()) return;

    // Validação adicional para frequência
    if (_tipoFrequencia == 'semanal' && _diasSemana.isEmpty) {
      _showError('Selecione pelo menos um dia da semana');
      return;
    }

    if (_tipoFrequencia == 'personalizado' &&
        _descricaoPersonalizada.trim().isEmpty) {
      _showError('Descreva a frequência personalizada');
      return;
    }

    if (!forceSave) {
        setState(() => _isAnalyzing = true);
        
        // AI Check logic
        try {
            final safetyResult = await _checkSafety(
                _nomeController.text.trim(), 
                _dosagemController.text.trim()
            );
            
            setState(() => _isAnalyzing = false);

            if (safetyResult['status'] == 'danger') {
                HapticFeedback.vibrate(); // Vibrate on danger
                if (!mounted) return;
                
                final shouldSave = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                        title: Row(
                            children: const [
                                Icon(Icons.warning_amber_rounded, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Alerta de Segurança'),
                            ],
                        ),
                        content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(safetyResult['message'] ?? 'Risco detectado.', style: AppTextStyles.labelMedium),
                                const SizedBox(height: 8),
                                Text(safetyResult['details'] ?? 'Verifique as interações medicamentosas.', style: AppTextStyles.bodyMedium),
                            ],
                        ),
                        actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false), 
                                child: Text('Voltar e Corrigir', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))
                            ),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true), 
                                child: Text('Ignorar e Salvar', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error))
                            ),
                        ],
                    ),
                );

                if (shouldSave != true) {
                    return; // Stop if user chose to correct
                }
            } else if (safetyResult['status'] == 'warning') {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text("Nota de Segurança: ${safetyResult['message']}"),
                            backgroundColor: AppColors.warning,
                        )
                    );
                 }
            }
        } catch (e) {
             print("AI Check Error ignored: $e");
             setState(() => _isAnalyzing = false);
        }
    }

    setState(() => _isLoading = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final medicamentoService = getIt<MedicamentoService>();
      final user = supabaseService.currentUser;
      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      // Se idosoId foi fornecido (familiar adicionando para idoso), usar ele
      // Caso contrário, usar o userId do usuário logado
      final targetUserId = widget.idosoId ?? user.id;

      if (_isEditing) {
        // Atualizar medicamento existente
        final updates = {
          'nome': _nomeController.text.trim(),
          'dosagem': _dosagemController.text.trim(),
          'quantidade': int.parse(_quantidadeController.text),
          'frequencia': _buildFrequenciaJson(),
        };

        final medicamentoSalvo = await medicamentoService.updateMedicamento(
          widget.medicamento!.id!,
          updates,
        );

        // Cancelar notificações antigas e agendar novas
        await NotificationService.cancelMedicamentoNotifications(
          widget.medicamento!.id!,
        );
        // Agendar novas notificações baseadas na frequência atualizada
        await NotificationService.scheduleMedicationReminders(medicamentoSalvo);

        _showSuccess('Medicamento atualizado com sucesso');
      } else {
        // Criar novo medicamento
        final medicamento = Medicamento(
          createdAt: DateTime.now(),
          nome: _nomeController.text.trim(),
          perfilId: targetUserId, // Usa idosoId se fornecido
          dosagem: _dosagemController.text.trim(),
          frequencia: _buildFrequenciaJson(),
          quantidade: int.parse(_quantidadeController.text),
        );

        final medicamentoSalvo =
            await medicamentoService.addMedicamento(medicamento);

        // Agendar notificações diárias repetitivas baseadas na frequência
        await NotificationService.scheduleMedicationReminders(medicamentoSalvo);

        _showSuccess('Medicamento adicionado com sucesso');
      }

      Navigator.pop(context, true); // Retorna true para indicar sucesso
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao salvar medicamento: $error';
      _showError(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    FeedbackService.showError(
        context, ErrorHandler.toAppException(Exception(message)));
  }

  void _showSuccess(String message) {
    FeedbackService.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: _isEditing ? 'Editar Medicamento' : 'Novo Medicamento',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.large, vertical: AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header com ícone
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppBorderRadius.large),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.medium),
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing
                                  ? 'Editar Medicamento'
                                  : 'Novo Medicamento',
                              style: AppTextStyles.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.idosoId != null
                                  ? 'Adicionando remédio para o idoso vinculado'
                                  : (_isEditing
                                      ? 'Atualize as informações do medicamento'
                                      : 'Preencha os dados do medicamento'),
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.large),

                // Campo Nome
                _buildTextField(
                  controller: _nomeController,
                  label: 'Nome do Medicamento',
                  icon: Icons.medication,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o nome do medicamento';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.medium),

                // Campo Dosagem
                _buildTextField(
                  controller: _dosagemController,
                  label: 'Dosagem',
                  hint: 'ex: 500mg, 1 comprimido',
                  icon: Icons.local_pharmacy,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira a dosagem';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.medium),

                // Campo Quantidade
                _buildTextField(
                  controller: _quantidadeController,
                  label: 'Quantidade em estoque',
                  icon: Icons.inventory_2_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira a quantidade';
                    }
                    final quantidade = int.tryParse(value);
                    if (quantidade == null || quantidade <= 0) {
                      return 'Por favor, insira uma quantidade válida';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.xlarge),

                // Seção Frequência
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppBorderRadius.small),
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.medium),
                          Text(
                            'Frequência de Uso',
                            style: AppTextStyles.titleLarge,
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.medium),

                      // Seletor de tipo de frequência
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.medium),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _buildRadioTile('Diário', 'diario', Icons.today),
                            const Divider(height: 1),
                            _buildRadioTile(
                                'Semanal', 'semanal', Icons.calendar_view_week),
                            const Divider(height: 1),
                            _buildRadioTile('Personalizado', 'personalizado',
                                Icons.edit_calendar),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.medium),

                      // Configurações específicas da frequência
                      _buildFrequenciaConfig(),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xlarge),

                // Botão Salvar
                AppPrimaryButton(
                  onPressed: _isLoading ? null : _saveMedicamento,
                  isLoading: _isLoading || _isAnalyzing,
                  label: _isAnalyzing
                      ? 'Analisando...'
                      : (_isEditing
                          ? 'Atualizar Medicamento'
                          : 'Adicionar Medicamento'),
                ),

                const SizedBox(height: AppSpacing.large), // Espaço extra antes do botão
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        boxShadow: AppShadows.small,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildRadioTile(String title, String value, IconData icon) {
    final isSelected = _tipoFrequencia == value;
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: AppSpacing.medium),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        value: value,
        // ignore: deprecated_member_use
        groupValue: _tipoFrequencia,
        // ignore: deprecated_member_use
        onChanged: (newValue) {
          setState(() {
            _tipoFrequencia = newValue!;
          });
        },
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildFrequenciaConfig() {
    switch (_tipoFrequencia) {
      case 'diario':
        return Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantas vezes por dia?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Row(
                children: [
                  IconButton(
                    onPressed: _vezesPorDia > 1
                        ? () {
                            setState(() {
                              _vezesPorDia--;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_vezesPorDia vez${_vezesPorDia > 1 ? 'es' : ''}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: _vezesPorDia < 10
                        ? () {
                            setState(() {
                              _vezesPorDia++;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'semanal':
        return Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecione os dias da semana:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _diasDaSemana.map((dia) {
                  final isSelected = _diasSemana.contains(dia);
                  return FilterChip(
                    label: Text(dia),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _diasSemana.add(dia);
                        } else {
                          _diasSemana.remove(dia);
                        }
                      });
                    },
                    selectedColor:
                        AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
            ],
          ),
        );

      case 'personalizado':
        return Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppBorderRadius.medium),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descreva a frequência:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                initialValue: _descricaoPersonalizada,
                onChanged: (value) {
                  _descricaoPersonalizada = value;
                },
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Ex: A cada 8 horas, Apenas quando necessário, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.small),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppBorderRadius.small),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

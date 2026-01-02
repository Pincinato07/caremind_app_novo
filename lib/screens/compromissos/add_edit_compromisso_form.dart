import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_button.dart';

class AddEditCompromissoForm extends StatefulWidget {
  final Map<String, dynamic>? compromisso;
  final String? idosoId; // Para familiar adicionar compromisso para idoso

  const AddEditCompromissoForm({super.key, this.compromisso, this.idosoId});

  @override
  State<AddEditCompromissoForm> createState() => _AddEditCompromissoFormState();
}

class _AddEditCompromissoFormState extends State<AddEditCompromissoForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _localController = TextEditingController();
  DateTime _dataHora = DateTime.now();
  String? _tipoSelecionado;
  int? _lembreteMinutos;
  bool _isLoading = false;
  bool get _isEditing => widget.compromisso != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadCompromissoData();
    }
  }

  void _loadCompromissoData() {
    final compromisso = widget.compromisso!;
    _tituloController.text = compromisso['titulo'] as String? ?? '';
    _descricaoController.text = compromisso['descricao'] as String? ?? '';
    _localController.text = compromisso['local'] as String? ?? '';
    _tipoSelecionado = compromisso['tipo'] as String?;
    _lembreteMinutos = compromisso['lembrete_minutos'] as int?;
    _dataHora = DateTime.parse(compromisso['data_hora'] as String);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _localController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dataHora,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Selecione a data',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_dataHora),
        helpText: 'Selecione o horário',
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _dataHora =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _saveCompromisso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final compromissoService = getIt<CompromissoService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      // Obter perfil_id correto
      String? perfilId;
      if (widget.idosoId != null) {
        // Se idosoId foi passado, buscar o perfil correspondente
        final idosoPerfil = await supabaseService.getProfile(widget.idosoId!);
        perfilId = idosoPerfil?.id ?? widget.idosoId;
      } else {
        // Se não, usar o perfil do usuário logado
        final perfil = await supabaseService.getProfile(user.id);
        perfilId = perfil?.id ?? user.id;
      }

      final descricao = _descricaoController.text.trim();
      final data = <String, dynamic>{
        'titulo': _tituloController.text.trim(),
        'data_hora': _dataHora.toIso8601String(),
        'perfil_id': perfilId,
        'updated_at': DateTime.now().toIso8601String(),
        // Só incluir descrição se não estiver vazia
        if (descricao.isNotEmpty) 'descricao': descricao,
        // Só incluir local se não estiver vazio
        if (_localController.text.trim().isNotEmpty) 'local': _localController.text.trim(),
        // Só incluir tipo se selecionado
        if (_tipoSelecionado != null) 'tipo': _tipoSelecionado,
        // Lembrete padrão: 60 minutos (consistente com o site)
        'lembrete_minutos': _lembreteMinutos ?? 60,
      };

      if (_isEditing) {
        await compromissoService.updateCompromisso(
          widget.compromisso!['id'].toString(),
          data,
        );
        _showSuccess('Compromisso atualizado com sucesso');
      } else {
        await compromissoService.addCompromisso(data);
        _showSuccess('Compromisso adicionado com sucesso');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao salvar compromisso: $error';
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: _isEditing ? 'Editar Compromisso' : 'Novo Compromisso',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large, vertical: AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.1),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppBorderRadius.large),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                        ),
                        child: const Icon(Icons.calendar_today,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.idosoId != null
                                  ? 'Adicionando compromisso para idoso'
                                  : (_isEditing
                                      ? 'Editar Compromisso'
                                      : 'Novo Compromisso'),
                              style: AppTextStyles.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isEditing
                                  ? 'Atualize as informações do compromisso'
                                  : 'Preencha os dados do compromisso',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.large),
                TextFormField(
                  controller: _tituloController,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    hintText: 'ex: Consulta médica, Exame de sangue',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o título do compromisso';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _descricaoController,
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Detalhes adicionais sobre o compromisso',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.medium),
                InkWell(
                  onTap: _selectDateTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Data e Hora',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy às HH:mm')
                                    .format(_dataHora),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _localController,
                  decoration: InputDecoration(
                    labelText: 'Local (opcional)',
                    hintText: 'ex: Hospital, Clínica, Consultório',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                DropdownButtonFormField<String>(
                  value: _tipoSelecionado,
                  decoration: InputDecoration(
                    labelText: 'Tipo (opcional)',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'consulta', child: Text('Consulta')),
                    DropdownMenuItem(value: 'exame', child: Text('Exame')),
                    DropdownMenuItem(value: 'procedimento', child: Text('Procedimento')),
                    DropdownMenuItem(value: 'outros', child: Text('Outros')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _tipoSelecionado = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                DropdownButtonFormField<int>(
                  value: _lembreteMinutos ?? 60,
                  decoration: InputDecoration(
                    labelText: 'Lembrete (minutos antes)',
                    prefixIcon: const Icon(Icons.notifications),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5 minutos antes')),
                    DropdownMenuItem(value: 15, child: Text('15 minutos antes')),
                    DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
                    DropdownMenuItem(value: 60, child: Text('1 hora antes')),
                    DropdownMenuItem(value: 1440, child: Text('1 dia antes')),
                    DropdownMenuItem(value: 2880, child: Text('2 dias antes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _lembreteMinutos = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.large),
                // Botão Salvar
                AppPrimaryButton(
                    onPressed: _isLoading ? null : _saveCompromisso,
                    isLoading: _isLoading,
                    label: _isEditing ? 'Atualizar Compromisso' : 'Adicionar Compromisso',
                ),
                const SizedBox(height: AppSpacing.large), // Espaço extra no final
              ],
            ),
          ),
        ),
      ),
    );
  }
}

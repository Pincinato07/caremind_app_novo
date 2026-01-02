import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/rotina_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../core/feedback/feedback_service.dart';
import '../../core/errors/error_handler.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_button.dart';

// Tipos de frequência
enum TipoFrequencia { diario, intervalo, diasAlternados, semanal }

class AddEditRotinaForm extends StatefulWidget {
  final Map<String, dynamic>? rotina;
  final String? idosoId; // Para familiar adicionar rotina para idoso

  const AddEditRotinaForm({super.key, this.rotina, this.idosoId});

  @override
  State<AddEditRotinaForm> createState() => _AddEditRotinaFormState();
}

class _AddEditRotinaFormState extends State<AddEditRotinaForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  
  // Estados para frequência
  TipoFrequencia _tipoFrequencia = TipoFrequencia.diario;
  List<String> _horarios = [];
  final _novoHorarioController = TextEditingController();
  int _intervaloHoras = 8;
  TimeOfDay? _horaInicio;
  int _intervaloDias = 2;
  final Set<int> _diasSemana = {};
  
  bool _isLoading = false;
  bool get _isEditing => widget.rotina != null;

  final List<Map<String, dynamic>> _diasDaSemana = [
    {'id': 1, 'label': 'Seg'},
    {'id': 2, 'label': 'Ter'},
    {'id': 3, 'label': 'Qua'},
    {'id': 4, 'label': 'Qui'},
    {'id': 5, 'label': 'Sex'},
    {'id': 6, 'label': 'Sáb'},
    {'id': 7, 'label': 'Dom'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadRotinaData();
    }
  }

  void _loadRotinaData() {
    final rotina = widget.rotina!;
    _tituloController.text = rotina['titulo'] as String? ?? '';
    _descricaoController.text = rotina['descricao'] as String? ?? '';
    
    // Carregar frequência
    final frequencia = rotina['frequencia'] as Map<String, dynamic>?;
    if (frequencia != null) {
      final tipo = frequencia['tipo'] as String?;
      
      switch (tipo) {
        case 'diario':
          _tipoFrequencia = TipoFrequencia.diario;
          final horarios = frequencia['horarios'] as List?;
          if (horarios != null) {
            _horarios = horarios.map((h) => h.toString()).toList();
          }
          break;
        case 'intervalo':
          _tipoFrequencia = TipoFrequencia.intervalo;
          _intervaloHoras = frequencia['intervalo_horas'] as int? ?? 8;
          final inicio = frequencia['inicio'] as String?;
          if (inicio != null) {
            _horaInicio = _parseTimeFromString(inicio);
          }
          break;
        case 'dias_alternados':
          _tipoFrequencia = TipoFrequencia.diasAlternados;
          _intervaloDias = frequencia['intervalo_dias'] as int? ?? 2;
          final horario = frequencia['horario'] as String?;
          if (horario != null) {
            _horaInicio = _parseTimeFromString(horario);
          }
          break;
        case 'semanal':
          _tipoFrequencia = TipoFrequencia.semanal;
          final dias = frequencia['dias_da_semana'] as List?;
          if (dias != null) {
            _diasSemana.addAll(dias.map((d) => d as int));
          }
          final horario = frequencia['horario'] as String?;
          if (horario != null) {
            _horaInicio = _parseTimeFromString(horario);
          }
          break;
        default:
          // Fallback para campo horario legado
          final horarioLegado = rotina['horario'] as String?;
          if (horarioLegado != null && horarioLegado.isNotEmpty) {
            _tipoFrequencia = TipoFrequencia.diario;
            _horarios = [horarioLegado];
          }
      }
    } else {
      // Fallback para campo horario legado
      final horarioLegado = rotina['horario'] as String?;
      if (horarioLegado != null && horarioLegado.isNotEmpty) {
        _tipoFrequencia = TipoFrequencia.diario;
        _horarios = [horarioLegado];
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _novoHorarioController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildFrequencia() {
    switch (_tipoFrequencia) {
      case TipoFrequencia.diario:
        if (_horarios.isEmpty) {
          throw Exception('Adicione pelo menos um horário');
        }
        return {
          'tipo': 'diario',
          'horarios': _horarios,
        };
      case TipoFrequencia.intervalo:
        if (_horaInicio == null) {
          throw Exception('Selecione o horário de início');
        }
        return {
          'tipo': 'intervalo',
          'intervalo_horas': _intervaloHoras,
          'inicio': _formatTimeOfDay(_horaInicio!),
        };
      case TipoFrequencia.diasAlternados:
        if (_horaInicio == null) {
          throw Exception('Selecione o horário');
        }
        return {
          'tipo': 'dias_alternados',
          'intervalo_dias': _intervaloDias,
          'horario': _formatTimeOfDay(_horaInicio!),
        };
      case TipoFrequencia.semanal:
        if (_diasSemana.isEmpty) {
          throw Exception('Selecione pelo menos um dia da semana');
        }
        if (_horaInicio == null) {
          throw Exception('Selecione o horário');
        }
        return {
          'tipo': 'semanal',
          'dias_da_semana': _diasSemana.toList()..sort(),
          'horario': _formatTimeOfDay(_horaInicio!),
        };
    }
  }

  Future<void> _saveRotina() async {
    if (!_formKey.currentState!.validate()) return;

    // Validações específicas de frequência
    try {
      if (_tipoFrequencia == TipoFrequencia.diario && _horarios.isEmpty) {
        _showError('Adicione pelo menos um horário');
        return;
      }
      if (_tipoFrequencia == TipoFrequencia.semanal && _diasSemana.isEmpty) {
        _showError('Selecione pelo menos um dia da semana');
        return;
      }
      if ((_tipoFrequencia == TipoFrequencia.intervalo ||
              _tipoFrequencia == TipoFrequencia.diasAlternados ||
              _tipoFrequencia == TipoFrequencia.semanal) &&
          _horaInicio == null) {
        _showError('Selecione o horário');
        return;
      }
    } catch (e) {
      _showError(e.toString());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabaseService = getIt<SupabaseService>();
      final rotinaService = getIt<RotinaService>();
      final user = supabaseService.currentUser;

      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      final targetId = widget.idosoId ?? user.id;
      final descricao = _descricaoController.text.trim();
      
      final frequencia = _buildFrequencia();
      
      final data = {
        'titulo': _tituloController.text.trim(),
        'perfil_id': targetId,
        'created_at': DateTime.now().toIso8601String(),
        'concluido': false,
        'frequencia': frequencia,
        // Só incluir descrição se não estiver vazia
        if (descricao.isNotEmpty) 'descricao': descricao,
      };

      if (_isEditing) {
        await rotinaService.updateRotina(
          widget.rotina!['id'] as int,
          data,
        );
        _showSuccess('Rotina atualizada com sucesso');
      } else {
        await rotinaService.addRotina(data);
        _showSuccess('Rotina adicionada com sucesso');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao salvar rotina: $error';
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

  Future<void> _selectTime(TimeOfDay? initialTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
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

    if (picked != null) {
      setState(() {
        _horaInicio = picked;
      });
    }
  }

  Future<void> _addHorario() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

    if (picked != null) {
      final horarioStr = _formatTimeOfDay(picked);
      if (!_horarios.contains(horarioStr)) {
        setState(() {
          _horarios.add(horarioStr);
          _horarios.sort();
        });
      }
    }
  }

  void _removeHorario(String horario) {
    setState(() {
      _horarios.remove(horario);
    });
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTimeFromString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Ignora erro
    }
    return TimeOfDay.now();
  }

  String _formatTimeOfDayDisplay(TimeOfDay time) {
    return _formatTimeOfDay(time);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: _isEditing ? 'Editar Rotina' : 'Nova Rotina',
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
                        Colors.white.withValues(alpha: 0.1),
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
                        child: const Icon(Icons.schedule,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.idosoId != null
                                  ? 'Adicionando rotina para idoso'
                                  : (_isEditing
                                      ? 'Editar Rotina'
                                      : 'Nova Rotina'),
                              style: AppTextStyles.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isEditing
                                  ? 'Atualize as informações da rotina'
                                  : 'Preencha os dados da rotina',
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
                    hintText: 'ex: Exercícios matinais, Hidratação',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o título da rotina';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _descricaoController,
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Detalhes adicionais sobre a rotina',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: AppSpacing.large),
                // Seletor de tipo de frequência
                DropdownButtonFormField<TipoFrequencia>(
                  value: _tipoFrequencia,
                  decoration: InputDecoration(
                    labelText: 'Frequência',
                    prefixIcon: const Icon(Icons.repeat),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: TipoFrequencia.diario,
                      child: Text('Diariamente'),
                    ),
                    DropdownMenuItem(
                      value: TipoFrequencia.intervalo,
                      child: Text('Intervalo de Horas'),
                    ),
                    DropdownMenuItem(
                      value: TipoFrequencia.diasAlternados,
                      child: Text('Dias Alternados'),
                    ),
                    DropdownMenuItem(
                      value: TipoFrequencia.semanal,
                      child: Text('Dias da Semana'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _tipoFrequencia = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.large),
                // Campos condicionais baseados no tipo de frequência
                _buildFrequenciaFields(),
                const SizedBox(height: AppSpacing.large),
                // Botão Salvar
                AppPrimaryButton(
                    onPressed: _isLoading ? null : _saveRotina,
                    isLoading: _isLoading,
                    label: _isEditing ? 'Atualizar Rotina' : 'Adicionar Rotina',
                ),
                const SizedBox(height: AppSpacing.large),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequenciaFields() {
    switch (_tipoFrequencia) {
      case TipoFrequencia.diario:
        return _buildFrequenciaDiaria();
      case TipoFrequencia.intervalo:
        return _buildFrequenciaIntervalo();
      case TipoFrequencia.diasAlternados:
        return _buildFrequenciaDiasAlternados();
      case TipoFrequencia.semanal:
        return _buildFrequenciaSemanal();
    }
  }

  Widget _buildFrequenciaDiaria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Horários',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_horarios.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Nenhum horário adicionado',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          ...(_horarios.map((horario) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        horario,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.error),
                      onPressed: () => _removeHorario(horario),
                    ),
                  ],
                ),
              ))),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _addHorario,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar Horário'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFrequenciaIntervalo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _intervaloHoras.toString(),
                decoration: InputDecoration(
                  labelText: 'A cada quantas horas?',
                  prefixIcon: const Icon(Icons.timer),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final intValue = int.tryParse(value);
                  if (intValue != null && intValue > 0) {
                    setState(() {
                      _intervaloHoras = intValue;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectTime(_horaInicio),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A partir das',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _horaInicio == null
                            ? 'Toque para selecionar'
                            : _formatTimeOfDayDisplay(_horaInicio!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _horaInicio == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
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
      ],
    );
  }

  Widget _buildFrequenciaDiasAlternados() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _intervaloDias.toString(),
                decoration: InputDecoration(
                  labelText: 'A cada quantos dias?',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppBorderRadius.medium)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final intValue = int.tryParse(value);
                  if (intValue != null && intValue > 0) {
                    setState(() {
                      _intervaloDias = intValue;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectTime(_horaInicio),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No horário',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _horaInicio == null
                            ? 'Toque para selecionar'
                            : _formatTimeOfDayDisplay(_horaInicio!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _horaInicio == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
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
      ],
    );
  }

  Widget _buildFrequenciaSemanal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dias da semana',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _diasDaSemana.map((dia) {
            final isSelected = _diasSemana.contains(dia['id']);
            return FilterChip(
              label: Text(dia['label']),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _diasSemana.add(dia['id'] as int);
                  } else {
                    _diasSemana.remove(dia['id'] as int);
                  }
                });
              },
              selectedColor: AppColors.primary.withValues(alpha: 0.2),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _selectTime(_horaInicio),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppBorderRadius.medium),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'No horário',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _horaInicio == null
                            ? 'Toque para selecionar'
                            : _formatTimeOfDayDisplay(_horaInicio!),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _horaInicio == null
                              ? Colors.grey.shade600
                              : Colors.black87,
                        ),
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
      ],
    );
  }
}

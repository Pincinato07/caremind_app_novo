import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';

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
  DateTime _dataHora = DateTime.now();
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
    _dataHora = DateTime.parse(compromisso['data_hora'] as String);
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
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
              primary: const Color(0xFF0400B9),
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
                primary: const Color(0xFF0400B9),
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
          _dataHora = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

      final targetId = widget.idosoId ?? user.id;
      final descricao = _descricaoController.text.trim();
      final data = {
        'titulo': _tituloController.text.trim(),
        'data_hora': _dataHora.toIso8601String(),
        'user_id': targetId,
        'created_at': DateTime.now().toIso8601String(),
        'concluido': false,
        // Só incluir descrição se não estiver vazia
        if (descricao.isNotEmpty) 'descricao': descricao,
      };

      if (_isEditing) {
        await compromissoService.updateCompromisso(
          widget.compromisso!['id'] as int,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Editar Compromisso' : 'Novo Compromisso',
          style: AppTextStyles.leagueSpartan(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveCompromisso,
            child: Text(
              'Salvar',
              style: AppTextStyles.leagueSpartan(
                color: _isLoading ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0400B9).withOpacity(0.1),
                      const Color(0xFF0400B9).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0400B9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_today, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.idosoId != null
                                ? 'Adicionando compromisso para idoso'
                                : (_isEditing ? 'Editar Compromisso' : 'Novo Compromisso'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEditing ? 'Atualize as informações do compromisso' : 'Preencha os dados do compromisso',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  labelText: 'Título',
                  hintText: 'ex: Consulta médica, Exame de sangue',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Detalhes adicionais sobre o compromisso',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDateTime,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF0400B9)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Data e Hora', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM/yyyy às HH:mm').format(_dataHora),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Botão Salvar
              Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0400B9), Color(0xFF0600E0)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0400B9).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCompromisso,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isEditing ? Icons.update : Icons.add,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'Atualizar Compromisso' : 'Adicionar Compromisso',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24), // Espaço extra no final
            ],
          ),
        ),
        ),
      ),
    );
  }
}


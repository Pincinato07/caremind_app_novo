import 'package:flutter/material.dart';
import '../../models/medicamento.dart';
import '../../services/medicamento_service.dart';
import '../../services/supabase_service.dart';

class AddEditMedicamentoForm extends StatefulWidget {
  final Medicamento? medicamento;

  const AddEditMedicamentoForm({super.key, this.medicamento});

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
    _dosagemController.text = medicamento.dosagem;
    _quantidadeController.text = medicamento.quantidade.toString();
    
    // Carrega dados da frequência
    final frequencia = medicamento.frequencia;
    if (frequencia.containsKey('tipo')) {
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

  Future<void> _saveMedicamento() async {
    if (!_formKey.currentState!.validate()) return;

    // Validação adicional para frequência
    if (_tipoFrequencia == 'semanal' && _diasSemana.isEmpty) {
      _showError('Selecione pelo menos um dia da semana');
      return;
    }
    
    if (_tipoFrequencia == 'personalizado' && _descricaoPersonalizada.trim().isEmpty) {
      _showError('Descreva a frequência personalizada');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        _showError('Usuário não encontrado');
        return;
      }

      if (_isEditing) {
        // Atualizar medicamento existente
        final updates = {
          'nome': _nomeController.text.trim(),
          'dosagem': _dosagemController.text.trim(),
          'quantidade': int.parse(_quantidadeController.text),
          'frequencia': _buildFrequenciaJson(),
        };
        
        await MedicamentoService.updateMedicamento(
          widget.medicamento!.id!,
          updates,
        );
        
        _showSuccess('Medicamento atualizado com sucesso');
      } else {
        // Criar novo medicamento
        final medicamento = Medicamento(
          createdAt: DateTime.now(),
          nome: _nomeController.text.trim(),
          userId: user.id,
          dosagem: _dosagemController.text.trim(),
          frequencia: _buildFrequenciaJson(),
          quantidade: int.parse(_quantidadeController.text),
        );
        
        await MedicamentoService.addMedicamento(medicamento);
        _showSuccess('Medicamento adicionado com sucesso');
      }
      
      Navigator.pop(context, true); // Retorna true para indicar sucesso
    } catch (error) {
      _showError('Erro ao salvar medicamento: $error');
    } finally {
      setState(() => _isLoading = false);
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Editar Medicamento' : 'Novo Medicamento',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveMedicamento,
            child: Text(
              'Salvar',
              style: TextStyle(
                color: _isLoading ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header com ícone
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
                      child: const Icon(
                        Icons.medication,
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
                            _isEditing ? 'Editar Medicamento' : 'Novo Medicamento',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEditing ? 'Atualize as informações do medicamento' : 'Preencha os dados do medicamento',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
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
              
              const SizedBox(height: 16),
              
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
              
              const SizedBox(height: 16),
              
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
              
              const SizedBox(height: 32),
              
              // Seção Frequência
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
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
                            color: const Color(0xFF0400B9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Frequência de Uso',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Seletor de tipo de frequência
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          _buildRadioTile('Diário', 'diario', Icons.today),
                          const Divider(height: 1),
                          _buildRadioTile('Semanal', 'semanal', Icons.calendar_view_week),
                          const Divider(height: 1),
                          _buildRadioTile('Personalizado', 'personalizado', Icons.edit_calendar),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Configurações específicas da frequência
                    _buildFrequenciaConfig(),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
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
                  onPressed: _isLoading ? null : _saveMedicamento,
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
                              _isEditing ? 'Atualizar Medicamento' : 'Adicionar Medicamento',
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
            ],
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
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
              color: const Color(0xFF0400B9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0400B9),
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0400B9), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
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
        color: isSelected ? const Color(0xFF0400B9).withOpacity(0.05) : Colors.transparent,
      ),
      child: RadioListTile<String>(
        title: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF0400B9) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF0400B9) : Colors.black87,
              ),
            ),
          ],
        ),
        value: value,
        groupValue: _tipoFrequencia,
        onChanged: (newValue) {
          setState(() {
            _tipoFrequencia = newValue!;
          });
        },
        activeColor: const Color(0xFF0400B9),
      ),
    );
  }

  Widget _buildFrequenciaConfig() {
    switch (_tipoFrequencia) {
      case 'diario':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0400B9).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _vezesPorDia > 1 ? () {
                      setState(() {
                        _vezesPorDia--;
                      });
                    } : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    onPressed: _vezesPorDia < 10 ? () {
                      setState(() {
                        _vezesPorDia++;
                      });
                    } : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        );
        
      case 'semanal':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0400B9).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
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
                    selectedColor: const Color(0xFF0400B9).withOpacity(0.2),
                    checkmarkColor: const Color(0xFF0400B9),
                  );
                }).toList(),
              ),
            ],
          ),
        );
        
      case 'personalizado':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0400B9).withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _descricaoPersonalizada,
                onChanged: (value) {
                  _descricaoPersonalizada = value;
                },
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Ex: A cada 8 horas, Apenas quando necessário, etc.',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF0400B9)),
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
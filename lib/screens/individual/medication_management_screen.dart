import 'package:flutter/material.dart';
import '../../core/injection/injection.dart';
import '../../models/medicamento.dart';
import '../../services/medication_crud_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../theme/app_theme.dart';

/// Tela de Gestão de Medicamentos do Usuário Individual
/// CRUD completo com TTS 100% funcional
class MedicamentoManagementScreen extends StatefulWidget {
  const MedicamentoManagementScreen({super.key});

  @override
  State<MedicamentoManagementScreen> createState() => _MedicamentoManagementScreenState();
}

class _MedicamentoManagementScreenState extends State<MedicamentoManagementScreen> 
    with TickerProviderStateMixin {
  final MedicationCRUDService _medicationService = getIt<MedicationCRUDService>();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dosagemController = TextEditingController();
  final _frequenciaController = TextEditingController();
  final _horariosController = TextEditingController();
  final _observacoesController = TextEditingController();
  
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _showForm = false;
  String _searchTerm = '';
  Medicamento? _editingMedicamento;
  List<Medicamento> _filteredMedicamentos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    AccessibilityService.initialize();
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Anuncia entrada na tela
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TTSEnhancer.announceScreenChange(context, 'Gestão de Medicamentos');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nomeController.dispose();
    _dosagemController.dispose();
    _frequenciaController.dispose();
    _horariosController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      await _medicationService.loadMedications();
      _updateFilteredMedicamentos();
    } catch (e) {
      debugPrint('Erro ao carregar medicamentos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text;
      _updateFilteredMedicamentos();
    });
  }

  void _updateFilteredMedicamentos() {
    if (_searchTerm.isEmpty) {
      _filteredMedicamentos = _medicationService.medications;
    } else {
      _filteredMedicamentos = _medicationService.searchMedications(_searchTerm);
    }
  }

  void _showAddForm() {
    _clearForm();
    setState(() {
      _showForm = true;
      _isEditing = false;
    });
    
    TTSEnhancer.announceNavigation('Formulário para adicionar medicamento', 'Medicamentos');
  }

  void _showEditForm(Medicamento medication) {
    _populateForm(medication);
    setState(() {
      _showForm = true;
      _isEditing = true;
      _editingMedicamento = medication;
    });
    
    TTSEnhancer.announceNavigation('Editando medicamento: ${medication.nome}', 'Medicamentos');
  }

  void _hideForm() {
    setState(() {
      _showForm = false;
      _isEditing = false;
      _editingMedicamento = null;
    });
    
    _clearForm();
    TTSEnhancer.announceNavigation('Voltando para lista de medicamentos', 'Medicamentos');
  }

  void _clearForm() {
    _nomeController.clear();
    _dosagemController.clear();
    _frequenciaController.clear();
    _horariosController.clear();
    _observacoesController.clear();
    _formKey.currentState?.reset();
  }

  void _populateForm(Medicamento medication) {
    _nomeController.text = medication.nome;
    _dosagemController.text = medication.dosagem;
    _frequenciaController.text = medication.frequencia['descricao']?.toString() ?? '';
    _horariosController.text = medication.horarios ?? '';
    _observacoesController.text = medication.observacoes ?? '';
  }

  Future<void> _saveMedicamento() async {
    if (!_formKey.currentState!.validate()) {
      await TTSEnhancer.announceValidationError('Por favor, corrija os erros no formulário');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await TTSEnhancer.announceAction('Salvando medicamento...');

      final success = _isEditing
          ? await _medicationService.updateMedication(
              id: _editingMedicamento!.id.toString(),
              nome: _nomeController.text.trim(),
              dosagem: _dosagemController.text.trim(),
              frequencia: _frequenciaController.text.trim(),
              horarios: _horariosController.text.trim(),
              observacoes: _observacoesController.text.trim().isEmpty 
                  ? null 
                  : _observacoesController.text.trim(),
            )
          : await _medicationService.createMedication(
              nome: _nomeController.text.trim(),
              dosagem: _dosagemController.text.trim(),
              frequencia: _frequenciaController.text.trim(),
              horarios: _horariosController.text.trim(),
              observacoes: _observacoesController.text.trim().isEmpty 
                  ? null 
                  : _observacoesController.text.trim(),
            );

      if (success != null) {
        _hideForm();
        _updateFilteredMedicamentos();
        
        await TTSEnhancer.announceCriticalSuccess('Medicamento salvo com sucesso!');
      }
    } catch (e) {
      await TTSEnhancer.announceError('Erro ao salvar medicamento: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteMedicamento(Medicamento medication) async {
    final confirmed = await _showDeleteConfirmation(medication);
    if (!confirmed) return;

    try {
      await TTSEnhancer.announceAction('Excluindo medicamento: ${medication.nome}...');
      
      final success = await _medicationService.deleteMedication(medication.id.toString());
      
      if (success) {
        _updateFilteredMedicamentos();
        await TTSEnhancer.announceCriticalSuccess('Medicamento excluído com sucesso!');
      }
    } catch (e) {
      await TTSEnhancer.announceError('Erro ao excluir medicamento: ${e.toString()}');
    }
  }

  Future<bool> _showDeleteConfirmation(Medicamento medication) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Semantics(
          label: 'Confirmar exclusão',
          child: const Text('Confirmar Exclusão'),
        ),
        content: Semantics(
          label: 'Tem certeza que deseja excluir o medicamento ${medication.nome}? Esta ação não pode ser desfeita.',
          child: Text('Tem certeza que deseja excluir o medicamento ${medication.nome}? Esta ação não pode ser desfeita.'),
        ),
        actions: [
          Semantics(
            label: 'Botão cancelar',
            hint: 'Cancela a exclusão do medicamento',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
          ),
          Semantics(
            label: 'Botão excluir',
            hint: 'Confirma a exclusão do medicamento',
            button: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _toggleMedicamentoStatus(Medicamento medication) async {
    try {
      await _medicationService.toggleMedicationStatus(medication.id.toString());
      _updateFilteredMedicamentos();
    } catch (e) {
      await TTSEnhancer.announceError('Erro ao alterar status: ${e.toString()}');
    }
  }

  Future<void> _announceMedicamentoDetails(Medicamento medication) async {
    await _medicationService.announceMedicationDetails(medication);
  }

  Future<void> _announceMedicamentoList() async {
    await _medicationService.announceMedicationList(_filteredMedicamentos);
  }

  Widget _buildSearchBar() {
    return Semantics(
      label: 'Barra de busca',
      hint: 'Digite para buscar medicamentos',
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: AppTextField(
          controller: _searchController,
          label: 'Buscar medicamentos',
          prefixIcon: Icon(Icons.search),
          onChanged: (value) {
            if (value.isNotEmpty) {
              TTSEnhancer.announceFormChange('Busca');
            }
          },
        ),
      ),
    );
  }

  Widget _buildMedicamentoCard(Medicamento medication) {
    return Semantics(
      label: 'Medicamento ${medication.nome}',
      hint: 'Dosagem: ${medication.dosagem}, Horários: ${medication.horarios}',
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.nome,
                        style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        medication.dosagem,
                        style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                      ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (medication.ativo ?? true) 
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (medication.ativo ?? true) 
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    (medication.ativo ?? true) ? 'Ativo' : 'Inativo',
                    style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Details
            Row(
              children: [
                Icon(Icons.access_time, 
                     size: 16, 
                     color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    medication.horarios ?? '',
                    style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            
            if (medication.frequencia.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.repeat, 
                       size: 16, 
                       color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      medication.frequencia['descricao']?.toString() ?? '',
                      style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    ),
                  ),
                ],
              ),
            ],
            
            if (medication.observacoes != null && medication.observacoes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                medication.observacoes!,
                style: TextStyle(
                  fontFamily: 'LeagueSpartan',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                // Ouvir detalhes
                Semantics(
                  label: 'Botão ouvir detalhes',
                  hint: 'Lê em voz alta os detalhes do medicamento',
                  button: true,
                  child: IconButton(
                    onPressed: () => _announceMedicamentoDetails(medication),
                    icon: Icon(Icons.volume_up, 
                         color: Colors.white.withValues(alpha: 0.8)),
                    iconSize: 20,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Editar
                Semantics(
                  label: 'Botão editar',
                  hint: 'Edita este medicamento',
                  button: true,
                  child: IconButton(
                    onPressed: () => _showEditForm(medication),
                    icon: Icon(Icons.edit, 
                         color: Colors.white.withValues(alpha: 0.8)),
                    iconSize: 20,
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Toggle status
                Semantics(
                  label: 'Botão ${(medication.ativo ?? true) ? 'desativar' : 'ativar'}',
                  hint: '${(medication.ativo ?? true) ? 'Desativa' : 'Ativa'} este medicamento',
                  button: true,
                  child: IconButton(
                    onPressed: () => _toggleMedicamentoStatus(medication),
                    icon: Icon(
                      (medication.ativo ?? true) ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    iconSize: 20,
                  ),
                ),
                
                const Spacer(),
                
                // Excluir
                Semantics(
                  label: 'Botão excluir',
                  hint: 'Exclui este medicamento',
                  button: true,
                  child: IconButton(
                    onPressed: () => _deleteMedicamento(medication),
                    icon: Icon(Icons.delete, 
                         color: Colors.red.withValues(alpha: 0.8)),
                    iconSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicamentoList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_filteredMedicamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_liquid,
              size: 64,
              color: Colors.white.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchTerm.isEmpty 
                  ? 'Nenhum medicamento cadastrado'
                  : 'Nenhum medicamento encontrado para "$_searchTerm"',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchTerm.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    const SizedBox(width: 8),
                    Text('Adicionar Medicamento'),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Result counter
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text(
                '${_filteredMedicamentos.length} medicamento${_filteredMedicamentos.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              if (_medicationService.medications.isNotEmpty)
                Semantics(
                  label: 'Botão ouvir lista',
                  hint: 'Lê em voz alta todos os medicamentos',
                  button: true,
                  child: IconButton(
                    onPressed: _announceMedicamentoList,
                    icon: Icon(Icons.volume_up, 
                             color: Colors.white.withValues(alpha: 0.8)),
                    iconSize: 20,
                  ),
                ),
            ],
          ),
        ),
        
        // List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredMedicamentos.length,
          itemBuilder: (context, index) {
            final medication = _filteredMedicamentos[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index < _filteredMedicamentos.length - 1 ? 12 : 0),
              child: _buildMedicamentoCard(medication),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicamentoForm() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  _isEditing ? 'Editar Medicamento' : 'Novo Medicamento',
                  style: TextStyle(
                    fontFamily: 'LeagueSpartan',
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Semantics(
                  label: 'Botão fechar formulário',
                  hint: 'Fecha o formulário sem salvar',
                  button: true,
                  child: IconButton(
                    onPressed: _hideForm,
                    icon: Icon(Icons.close, 
                         color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Nome
            Semantics(
              label: 'Campo nome do medicamento',
              hint: 'Digite o nome do medicamento',
              textField: true,
              child: AppTextField(
                controller: _nomeController,
                label: 'Nome do Medicamento *',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  return null;
                },
                onChanged: (value) {
                  TTSEnhancer.announceFormChange('Nome');
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dosagem
            Semantics(
              label: 'Campo dosagem',
              hint: 'Digite a dosagem do medicamento',
              textField: true,
              child: AppTextField(
                controller: _dosagemController,
                label: 'Dosagem *',
                hint: 'Ex: 500mg, 1 comprimido',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Dosagem é obrigatória';
                  }
                  return null;
                },
                onChanged: (value) {
                  TTSEnhancer.announceFormChange('Dosagem');
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Frequência
            Semantics(
              label: 'Campo frequência',
              hint: 'Digite a frequência de uso',
              textField: true,
              child: AppTextField(
                controller: _frequenciaController,
                label: 'Frequência *',
                hint: 'Ex: 8 em 8 horas, 1 vez ao dia',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Frequência é obrigatória';
                  }
                  return null;
                },
                onChanged: (value) {
                  TTSEnhancer.announceFormChange('Frequência');
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Horários
            Semantics(
              label: 'Campo horários',
              hint: 'Digite os horários separados por vírgula',
              textField: true,
              child: AppTextField(
                controller: _horariosController,
                label: 'Horários *',
                hint: 'Ex: 08:00, 14:00, 20:00',
                keyboardType: TextInputType.text,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Horários são obrigatórios';
                  }
                  
                  // Validação básica de horários
                  final horariosList = value.split(',');
                  for (final horario in horariosList) {
                    final trimmedHorario = horario.trim();
                    if (!RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$').hasMatch(trimmedHorario)) {
                      return 'Horário inválido: $trimmedHorario. Use formato HH:MM.';
                    }
                  }
                  
                  return null;
                },
                onChanged: (value) {
                  TTSEnhancer.announceFormChange('Horários');
                },
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Observações
            Semantics(
              label: 'Campo observações',
              hint: 'Digite observações adicionais (opcional)',
              textField: true,
              child: AppTextField(
                controller: _observacoesController,
                label: 'Observações (opcional)',
                hint: 'Ex: Tomar após as refeições',
                maxLines: 3,
                onChanged: (value) {
                  TTSEnhancer.announceFormChange('Observações');
                },
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Botão salvar medicamento',
                    hint: 'Salva o medicamento',
                    button: true,
                    child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMedicamento,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(_isEditing ? 'Atualizar' : 'Adicionar'),
                  ),
                  ),
                ),
                
                if (_isEditing) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Semantics(
                      label: 'Botão cancelar',
                      hint: 'Cancela a edição',
                      button: true,
                      child: OutlinedButton(
                      onPressed: _isSaving ? null : _hideForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldWithWaves(
      appBar: CareMindAppBar(
        title: 'Meus Medicamentos',
        leading: !_showForm ? null : IconButton(
          onPressed: _hideForm,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, AppSpacing.bottomNavBarPadding),
        child: Column(
          children: [
            if (!_showForm) ...[
              _buildSearchBar(),
              const SizedBox(height: 24),
              _buildMedicamentoList(),
            ] else ...[
              _buildMedicamentoForm(),
            ],
          ],
        ),
      ),
    );
  }
}


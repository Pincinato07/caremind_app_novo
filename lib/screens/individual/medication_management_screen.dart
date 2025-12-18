import 'package:flutter/material.dart';
import '../../core/injection/injection.dart';
import '../../models/medicamento.dart';
import '../../services/medication_crud_service.dart';
import '../../services/accessibility_service.dart';
import '../../core/accessibility/tts_enhancer.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/caremind_app_bar.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../theme/app_theme.dart';

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
  final _quantidadeController = TextEditingController();
  final _viaController = TextEditingController();
  
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
    _quantidadeController.dispose();
    _viaController.dispose();
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
    _quantidadeController.clear();
    _viaController.clear();
    _formKey.currentState?.reset();
  }

  void _populateForm(Medicamento medication) {
    _nomeController.text = medication.nome;
    _dosagemController.text = medication.dosagem ?? '';
    _quantidadeController.text = medication.quantidade?.toString() ?? '';
    _viaController.text = medication.via ?? '';
  }

  Future<void> _saveMedicamento() async {
    if (!_formKey.currentState!.validate()) {
      await TTSEnhancer.announceValidationError('Por favor, corrija os erros no formulário');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await TTSEnhancer.announceAction('Salvando medicamento...');

      final quantidade = int.tryParse(_quantidadeController.text.trim());

      if (_isEditing) {
        final success = await _medicationService.updateMedication(
          id: _editingMedicamento!.id!,
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim().isEmpty ? null : _dosagemController.text.trim(),
          quantidade: quantidade,
          via: _viaController.text.trim().isEmpty ? null : _viaController.text.trim(),
        );
        
        if (success) {
          _hideForm();
          _updateFilteredMedicamentos();
          await TTSEnhancer.announceCriticalSuccess('Medicamento atualizado com sucesso!');
        }
      } else {
        final result = await _medicationService.createMedication(
          nome: _nomeController.text.trim(),
          dosagem: _dosagemController.text.trim().isEmpty ? null : _dosagemController.text.trim(),
          quantidade: quantidade,
          via: _viaController.text.trim().isEmpty ? null : _viaController.text.trim(),
        );
        
        if (result != null) {
          _hideForm();
          _updateFilteredMedicamentos();
          await TTSEnhancer.announceCriticalSuccess('Medicamento salvo com sucesso!');
        }
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
      
      final success = await _medicationService.deleteMedication(medication.id!);
      
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
          label: 'Tem certeza que deseja excluir o medicamento ${medication.nome}?',
          child: Text('Tem certeza que deseja excluir o medicamento ${medication.nome}?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    ) ?? false;
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
      child: AnimatedCard(
        index: 0,
        child: CareMindCard(
          variant: CardVariant.glass,
          padding: AppSpacing.paddingCard,
        child: AppTextField(
          controller: _searchController,
          label: 'Buscar medicamentos',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    ),
    );
  }

  Widget _buildMedicamentoCard(Medicamento medication) {
    return Semantics(
      label: 'Medicamento ${medication.nome}',
      hint: 'Dosagem: ${medication.dosagem ?? 'Não informada'}',
      child: AnimatedCard(
        index: 1,
        child: CareMindCard(
          variant: CardVariant.glass,
          padding: AppSpacing.paddingCard,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      if (medication.dosagem != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          medication.dosagem!,
                          style: TextStyle(
                            fontFamily: 'LeagueSpartan',
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (medication.via != null) ...[
              Row(
                children: [
                  Icon(Icons.medication, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Via: ${medication.via}',
                    style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
            
            if (medication.quantidade != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.inventory, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(
                    'Quantidade: ${medication.quantidade}',
                    style: TextStyle(
                      fontFamily: 'LeagueSpartan',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                IconButton(
                  onPressed: () => _announceMedicamentoDetails(medication),
                  icon: Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.8)),
                  iconSize: 20,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showEditForm(medication),
                  icon: Icon(Icons.edit, color: Colors.white.withValues(alpha: 0.8)),
                  iconSize: 20,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _deleteMedicamento(medication),
                  icon: Icon(Icons.delete, color: Colors.red.withValues(alpha: 0.8)),
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildMedicamentoList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_filteredMedicamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_liquid, size: 64, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              _searchTerm.isEmpty ? 'Nenhum medicamento cadastrado' : 'Nenhum medicamento encontrado',
              style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (_searchTerm.isEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showAddForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.add, size: 18), const SizedBox(width: 8), Text('Adicionar')],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text('${_filteredMedicamentos.length} medicamento(s)', 
                   style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
              const Spacer(),
              IconButton(
                onPressed: _announceMedicamentoList,
                icon: Icon(Icons.volume_up, color: Colors.white.withValues(alpha: 0.8)),
                iconSize: 20,
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredMedicamentos.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(bottom: index < _filteredMedicamentos.length - 1 ? 12 : 0),
              child: _buildMedicamentoCard(_filteredMedicamentos[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMedicamentoForm() {
    return AnimatedCard(
      index: 2,
      child: CareMindCard(
        variant: CardVariant.glass,
        padding: AppSpacing.paddingLarge,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isEditing ? 'Editar Medicamento' : 'Novo Medicamento',
                  style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _hideForm,
                  icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _nomeController,
              label: 'Nome do Medicamento *',
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Nome é obrigatório' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _dosagemController,
              label: 'Dosagem',
              hint: 'Ex: 500mg, 1 comprimido',
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _quantidadeController,
              label: 'Quantidade',
              hint: 'Ex: 30',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _viaController,
              label: 'Via de Administração',
              hint: 'Ex: oral, intravenosa, tópica',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMedicamento,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : Text(_isEditing ? 'Atualizar' : 'Adicionar'),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 16),
                  Expanded(
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
                ],
              ],
            ),
          ],
        ),
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
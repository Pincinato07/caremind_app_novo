import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/consolidado_organizacao_service.dart';
import '../../../services/medicamento_service.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/injection/injection.dart';

/// Tela de Visão Consolidada da Organização
class ConsolidadoOrganizacaoScreen extends StatefulWidget {
  final String organizacaoId;

  const ConsolidadoOrganizacaoScreen({
    super.key,
    required this.organizacaoId,
  });

  @override
  State<ConsolidadoOrganizacaoScreen> createState() =>
      _ConsolidadoOrganizacaoScreenState();
}

class _ConsolidadoOrganizacaoScreenState
    extends State<ConsolidadoOrganizacaoScreen>
    with SingleTickerProviderStateMixin {
  final ConsolidadoOrganizacaoService _consolidadoService =
      ConsolidadoOrganizacaoService();
  final MedicamentoService _medicamentoService = getIt<MedicamentoService>();
  late TabController _tabController;

  List<MedicamentoConsolidado> _medicamentos = [];
  Map<int, bool> _statusMedicamentos = {};
  List<RotinaConsolidada> _rotinas = [];
  List<CompromissoConsolidado> _compromissos = [];

  bool _loading = true;
  String? _error;
  String? _filtroIdoso;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _consolidadoService.obterMedicamentosConsolidados(widget.organizacaoId),
        _consolidadoService.obterRotinasConsolidadas(widget.organizacaoId),
        _consolidadoService.obterCompromissosConsolidadas(widget.organizacaoId),
      ]);

      setState(() {
        _medicamentos = results[0] as List<MedicamentoConsolidado>;
        _rotinas = results[1] as List<RotinaConsolidada>;
        _compromissos = results[2] as List<CompromissoConsolidado>;
        _loading = false;
      });

      // Carregar status dos medicamentos para hoje
      _carregarStatusMedicamentos();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      if (mounted) {
        FeedbackService.showError(
            context, ErrorHandler.toAppException(e));
      }
    }
  }

  Future<void> _carregarStatusMedicamentos() async {
    if (_medicamentos.isEmpty) return;

    try {
      // Agrupar IDs por perfil para verificar status
      final perfilIds = _medicamentos.map((m) => m.idosoId).toSet();
      final Map<int, bool> novoStatus = {};

      for (final perfilId in perfilIds) {
        final medIdsDoPerfil = _medicamentos
            .where((m) => m.idosoId == perfilId)
            .map((m) => m.medicamento.id!)
            .toList();

        if (medIdsDoPerfil.isNotEmpty) {
          final statusMap = await _consolidadoService.checkMedicamentosConcluidosHoje(
            perfilId,
            medIdsDoPerfil,
          );
          novoStatus.addAll(statusMap);
        }
      }

      if (mounted) {
        setState(() {
          _statusMedicamentos = novoStatus;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar status dos medicamentos: $e');
    }
  }

  Future<void> _toggleMedicamento(MedicamentoConsolidado item) async {
    final med = item.medicamento;
    if (med.id == null) return;

    final bool atual = _statusMedicamentos[med.id!] ?? false;
    final bool novo = !atual;

    // Feedback tátil
    HapticFeedback.mediumImpact();

    // Feedback visual otimista
    setState(() {
      _statusMedicamentos[med.id!] = novo;
    });

    try {
      await _medicamentoService.toggleConcluido(
        med.id!,
        novo,
        DateTime.now(),
      );
      
      if (mounted) {
        // Remover SnackBars anteriores para evitar empilhamento
        ScaffoldMessenger.of(context).clearSnackBars();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${med.nome} marcado como ${novo ? 'tomado' : 'pendente'}',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () {
                _toggleMedicamento(item); // Reverte a ação recursivamente
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Reverter em caso de erro
      setState(() {
        _statusMedicamentos[med.id!] = atual;
      });
      if (mounted) {
        FeedbackService.showError(context, ErrorHandler.toAppException(e));
      }
    }
  }

  List<String> _obterIdososUnicos() {
    final idosos = <String>{};
    _medicamentos.forEach((m) => idosos.add(m.idosoNome));
    _rotinas.forEach((r) => idosos.add(r.idosoNome));
    _compromissos.forEach((c) => idosos.add(c.idosoNome));
    return idosos.toList()..sort();
  }

  List<MedicamentoConsolidado> _getMedicamentosFiltrados() {
    var medicamentos = _medicamentos;
    if (_filtroIdoso != null) {
      medicamentos = medicamentos
          .where((m) => m.idosoNome == _filtroIdoso)
          .toList();
    }
    return medicamentos;
  }

  List<RotinaConsolidada> _getRotinasFiltradas() {
    var rotinas = _rotinas;
    if (_filtroIdoso != null) {
      rotinas = rotinas.where((r) => r.idosoNome == _filtroIdoso).toList();
    }
    return rotinas;
  }

  List<CompromissoConsolidado> _getCompromissosFiltrados() {
    var compromissos = _compromissos;
    if (_filtroIdoso != null) {
      compromissos = compromissos
          .where((c) => c.idosoNome == _filtroIdoso)
          .toList();
    }
    return compromissos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visão Consolidada'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.medication), text: 'Medicamentos'),
            Tab(icon: Icon(Icons.repeat), text: 'Rotinas'),
            Tab(icon: Icon(Icons.event), text: 'Compromissos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _mostrarFiltros,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Erro ao carregar dados: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _carregarDados,
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMedicamentosTab(),
                    _buildRotinasTab(),
                    _buildCompromissosTab(),
                  ],
                ),
    );
  }

  Widget _buildMedicamentosTab() {
    final medicamentos = _getMedicamentosFiltrados();

    if (medicamentos.isEmpty) {
      return const Center(child: Text('Nenhum medicamento encontrado'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicamentos.length,
      itemBuilder: (context, index) {
        final item = medicamentos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.medication, color: Colors.blue),
            title: Text(item.medicamento.nome),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Idoso: ${item.idosoNome}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (item.quarto != null) Text('Quarto: ${item.quarto}'),
                if (item.setor != null) Text('Setor: ${item.setor}'),
                if (item.medicamento.dosagem != null)
                  Text('Dosagem: ${item.medicamento.dosagem}'),
              ],
            ),
            trailing: _buildQuickActionButton(item),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton(MedicamentoConsolidado item) {
    final concluido = _statusMedicamentos[item.medicamento.id] ?? false;
    
    return IconButton(
      icon: Icon(
        concluido ? Icons.check_circle : Icons.circle_outlined,
        color: concluido ? Colors.green : Colors.grey,
        size: 32,
      ),
      onPressed: () => _toggleMedicamento(item),
      tooltip: concluido ? 'Marcar como pendente' : 'Marcar como tomado',
    );
  }

  Widget _buildRotinasTab() {
    final rotinas = _getRotinasFiltradas();

    if (rotinas.isEmpty) {
      return const Center(child: Text('Nenhuma rotina encontrada'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rotinas.length,
      itemBuilder: (context, index) {
        final item = rotinas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.repeat, color: Colors.green),
            title: Text(item.rotina['nome'] as String? ?? 'Sem nome'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Idoso: ${item.idosoNome}'),
                if (item.quarto != null) Text('Quarto: ${item.quarto}'),
                if (item.setor != null) Text('Setor: ${item.setor}'),
                if (item.rotina['descricao'] != null)
                  Text('Descrição: ${item.rotina['descricao']}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildCompromissosTab() {
    final compromissos = _getCompromissosFiltrados();

    if (compromissos.isEmpty) {
      return const Center(child: Text('Nenhum compromisso encontrado'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: compromissos.length,
      itemBuilder: (context, index) {
        final item = compromissos[index];
        final dataStr = item.compromisso['data_compromisso'] as String?;
        DateTime? data;
        if (dataStr != null) {
          try {
            data = DateTime.parse(dataStr);
          } catch (_) {}
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.event, color: Colors.purple),
            title: Text(item.compromisso['titulo'] as String? ?? 'Sem título'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Idoso: ${item.idosoNome}'),
                if (item.quarto != null) Text('Quarto: ${item.quarto}'),
                if (item.setor != null) Text('Setor: ${item.setor}'),
                if (data != null)
                  Text('Data: ${data.day}/${data.month}/${data.year}'),
                if (item.compromisso['descricao'] != null)
                  Text('Descrição: ${item.compromisso['descricao']}'),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  void _mostrarFiltros() {
    final idosos = _obterIdososUnicos();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtros'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _filtroIdoso,
              decoration: const InputDecoration(
                labelText: 'Filtrar por Idoso',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos'),
                ),
                ...idosos.map((idoso) => DropdownMenuItem<String>(
                      value: idoso,
                      child: Text(idoso),
                    )),
              ],
              onChanged: (value) {
                setState(() => _filtroIdoso = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filtroIdoso = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Limpar Filtros'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}


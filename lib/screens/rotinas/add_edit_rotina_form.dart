import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../services/rotina_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';

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
  final _horarioController = TextEditingController();
  bool _isLoading = false;
  bool get _isEditing => widget.rotina != null;

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
    _horarioController.text = rotina['horario'] as String? ?? '';
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _horarioController.dispose();
    super.dispose();
  }

  Future<void> _saveRotina() async {
    if (!_formKey.currentState!.validate()) return;

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
      final data = {
        'titulo': _tituloController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'horario': _horarioController.text.trim(),
        'perfil_id': targetId,
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
          _isEditing ? 'Editar Rotina' : 'Nova Rotina',
          style: GoogleFonts.leagueSpartan(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRotina,
            child: Text(
              'Salvar',
              style: GoogleFonts.leagueSpartan(
                color: _isLoading ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w700,
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
                      child: const Icon(Icons.schedule, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.idosoId != null
                                ? 'Adicionando rotina para idoso'
                                : (_isEditing ? 'Editar Rotina' : 'Nova Rotina'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isEditing ? 'Atualize as informações da rotina' : 'Preencha os dados da rotina',
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
                  hintText: 'ex: Exercícios matinais, Hidratação',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, insira o título da rotina';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _horarioController,
                decoration: InputDecoration(
                  labelText: 'Horário',
                  hintText: 'ex: 08:00, Manhã, Tarde',
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoController,
                decoration: InputDecoration(
                  labelText: 'Descrição (opcional)',
                  hintText: 'Detalhes adicionais sobre a rotina',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


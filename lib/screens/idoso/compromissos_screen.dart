import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/voice_interface_widget.dart';
import '../../services/accessibility_service.dart';

/// Tela de Compromissos para IDOSO - Visual simples com agenda
/// Foco em acessibilidade: fontes grandes, cards simples, fácil leitura
class CompromissosIdosoScreen extends StatefulWidget {
  const CompromissosIdosoScreen({super.key});

  @override
  State<CompromissosIdosoScreen> createState() => _CompromissosIdosoScreenState();
}

class _CompromissosIdosoScreenState extends State<CompromissosIdosoScreen> {
  List<Map<String, dynamic>> _compromissos = [];
  List<Map<String, dynamic>> _proximosCompromissos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCompromissos();
  }

  Future<void> _loadCompromissos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabaseService = getIt<SupabaseService>();
      final compromissoService = getIt<CompromissoService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        // Buscar próximos compromissos (futuros)
        final proximos = await compromissoService.getProximosCompromissos(user.id);
        
        setState(() {
          _proximosCompromissos = proximos;
          _compromissos = proximos; // Mostra apenas os futuros para idoso
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Usuário não encontrado';
          _isLoading = false;
        });
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao carregar compromissos: $error';
      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  Future<void> _marcarComoConcluido(Map<String, dynamic> compromisso) async {
    try {
      final compromissoService = getIt<CompromissoService>();
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) return;
      
      final compromissoId = compromisso['id'] as int;
      final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
      
      await compromissoService.toggleConcluido(compromissoId, true);
      
      // Registrar evento no histórico
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': user.id,
          'tipo_evento': 'compromisso_realizado',
          'data_hora': DateTime.now().toIso8601String(),
          'descricao': 'Compromisso "$titulo" marcado como realizado',
          'referencia_id': compromissoId.toString(),
          'tipo_referencia': 'compromisso',
        });
      } catch (e) {
        // Log erro mas não interrompe o fluxo
        debugPrint('⚠️ Erro ao registrar evento no histórico: $e');
      }
      
      // Feedback multissensorial
      await AccessibilityService.feedbackSucesso();
      
      // Recarregar
      await _loadCompromissos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compromisso marcado como realizado!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      final errorMessage = error is AppException
          ? error.message
          : 'Erro ao atualizar compromisso: $error';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = getIt<SupabaseService>();
    final user = supabaseService.currentUser;
    final userId = user?.id ?? '';

    return AppScaffoldWithWaves(
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Minha Agenda',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Consultas e Compromissos',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 20,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Erro
                  if (_error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Erro ao carregar agenda',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCompromissos,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0400BA),
                                ),
                                child: Text(
                                  'Tentar Novamente',
                                  style: GoogleFonts.leagueSpartan(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Lista vazia
                  if (_error == null && _compromissos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 64,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Nenhum compromisso agendado',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Suas consultas e compromissos aparecerão aqui',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 18,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Lista de compromissos
                  if (_error == null && _compromissos.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final compromisso = _compromissos[index];
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              24.0,
                              index == 0 ? 0 : 12.0,
                              24.0,
                              12.0,
                            ),
                            child: _buildCompromissoCard(compromisso),
                          );
                        },
                        childCount: _compromissos.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
            // Interface de voz para idosos
            if (userId.isNotEmpty && !_isLoading)
              VoiceInterfaceWidget(
                userId: userId,
                showAsFloatingButton: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompromissoCard(Map<String, dynamic> compromisso) {
    final dataHora = DateTime.parse(compromisso['data_hora'] as String);
    final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
    final descricao = compromisso['descricao'] as String?;
    final concluido = compromisso['concluido'] as bool? ?? false;
    final isHoje = dataHora.year == DateTime.now().year &&
        dataHora.month == DateTime.now().month &&
        dataHora.day == DateTime.now().day;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return GlassCard(
      onTap: concluido
          ? null
          : () {
              AccessibilityService.vibrar();
              _marcarComoConcluido(compromisso);
            },
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com data e status
          Row(
            children: [
              // Ícone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: concluido
                      ? Colors.green.withValues(alpha: 0.2)
                      : isHoje
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  concluido
                      ? Icons.check_circle
                      : isHoje
                          ? Icons.today
                          : Icons.calendar_today,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              
              // Data e hora
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHoje ? 'Hoje' : dateFormat.format(dataHora),
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(dataHora),
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge de status
              if (concluido)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Feito',
                    style: GoogleFonts.leagueSpartan(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Título (FONTE GIGANTE)
          GestureDetector(
            onTap: () {
              AccessibilityService.speak(titulo);
            },
            child: Text(
              titulo,
              style: GoogleFonts.leagueSpartan(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
                decoration: concluido ? TextDecoration.lineThrough : null,
              ),
            ),
          ),

          // Descrição
          if (descricao != null && descricao.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              descricao,
              style: GoogleFonts.leagueSpartan(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ],

          // Botão de ação (se não concluído)
          if (!concluido) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _marcarComoConcluido(compromisso),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0400BA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'JÁ FIZ',
                  style: GoogleFonts.leagueSpartan(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


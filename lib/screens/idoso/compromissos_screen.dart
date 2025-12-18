import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/compromisso_service.dart';
import '../../services/historico_eventos_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';
import '../../widgets/app_scaffold_with_waves.dart';
import '../../widgets/caremind_card.dart';
import '../../widgets/animated_card.dart';
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
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user == null) return;
      
      // final compromissoId = compromisso['id'] as String; // Não utilizado
      final titulo = compromisso['titulo'] as String? ?? 'Compromisso';
      
      // Registrar evento no histórico (tabela compromissos não tem campo concluido)
      try {
        await HistoricoEventosService.addEvento({
          'perfil_id': user.id,
          'tipo_evento': 'compromisso_realizado',
          'evento_id': 1,
          'data_prevista': DateTime.now().toIso8601String(),
          'status': 'concluido',
          'descricao': 'Compromisso "$titulo" marcado como realizado',
          'titulo': titulo,
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
                            style: AppTextStyles.leagueSpartan(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Consultas e Compromissos',
                            style: AppTextStyles.leagueSpartan(
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
                        child: AnimatedCard(
                          index: 0,
                          child: CareMindCard(
                            variant: CardVariant.glass,
                            padding: AppSpacing.paddingLarge,
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
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCompromissos,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary,
                                ),
                                child: Text(
                                  'Tentar Novamente',
                                  style: AppTextStyles.leagueSpartan(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),

                  // Lista vazia
                  if (_error == null && _compromissos.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.large),
                        child: AnimatedCard(
                          index: 1,
                          child: CareMindCard(
                            variant: CardVariant.glass,
                            padding: AppSpacing.paddingXLarge,
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
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Suas consultas e compromissos aparecerão aqui',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.leagueSpartan(
                                  fontSize: 18,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              ],
                            ),
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

                  SliverToBoxAdapter(child: SizedBox(height: AppSpacing.bottomNavBarPadding)),
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
    final isHoje = dataHora.year == DateTime.now().year &&
        dataHora.month == DateTime.now().month &&
        dataHora.day == DateTime.now().day;
    final isPassado = dataHora.isBefore(DateTime.now());

    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return AnimatedCard(
      index: 2,
      child: CareMindCard(
        variant: CardVariant.glass,
        onTap: isPassado
            ? null
            : () {
              AccessibilityService.vibrar();
              _marcarComoConcluido(compromisso);
            },
        padding: AppSpacing.paddingLarge,
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
                  color: isPassado
                      ? Colors.grey.withValues(alpha: 0.2)
                      : isHoje
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPassado
                      ? Icons.event_busy
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
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeFormat.format(dataHora),
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Badge de status
              if (isPassado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Passado',
                    style: AppTextStyles.leagueSpartan(
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
              style: AppTextStyles.leagueSpartan(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Descrição
          if (descricao != null && descricao.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              descricao,
              style: AppTextStyles.leagueSpartan(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
          ],

          // Botão de ação (se não passou)
          if (!isPassado) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _marcarComoConcluido(compromisso),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'JÁ FIZ',
                  style: AppTextStyles.leagueSpartan(
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
      ),
    );
  }
}

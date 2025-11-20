import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../core/injection/injection.dart';
import '../../core/errors/app_exception.dart';

/// Tela de Ajuda/Emergência para o perfil IDOSO
class AjudaScreen extends StatefulWidget {
  const AjudaScreen({super.key});

  @override
  State<AjudaScreen> createState() => _AjudaScreenState();
}

class _AjudaScreenState extends State<AjudaScreen> {
  String? _telefoneCuidador;
  String? _nomeCuidador;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarTelefoneCuidador();
  }

  Future<void> _carregarTelefoneCuidador() async {
    try {
      final supabaseService = getIt<SupabaseService>();
      final user = supabaseService.currentUser;
      
      if (user != null) {
        final cuidador = await supabaseService.getCuidadorPrincipal(user.id);
        
        if (mounted) {
          setState(() {
            _telefoneCuidador = cuidador?['telefone'] as String?;
            _nomeCuidador = cuidador?['nome'] as String?;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _ligarParaFamiliar() async {
    if (_telefoneCuidador == null || _telefoneCuidador!.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Número não disponível',
              style: GoogleFonts.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              'Nenhum número de emergência cadastrado. Peça para seu familiar configurar o telefone no aplicativo.',
              style: GoogleFonts.leagueSpartan(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: GoogleFonts.leagueSpartan(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0400BA),
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Formatar telefone para URL (remover caracteres não numéricos)
    final telefoneLimpo = _telefoneCuidador!.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$telefoneLimpo');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Dispositivo não suportado',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Text(
                'Este dispositivo não possui capacidade de fazer chamadas telefônicas.',
                style: GoogleFonts.leagueSpartan(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.leagueSpartan(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0400BA),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e is AppException
            ? e.message
            : 'Erro ao iniciar chamada: $e';
        
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0400B9),
                      const Color(0xFF0600E0),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0400B9).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Precisa de Ajuda?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botão de Emergência
              SizedBox(
                height: 80,
                child: ElevatedButton.icon(
                  onPressed: _ligarParaFamiliar,
                  icon: const Icon(Icons.phone, size: 32),
                  label: const Text(
                    'LIGAR PARA FAMILIAR',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Informações de contato
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF0400B9).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações de Contato',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (_nomeCuidador != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Familiar: $_nomeCuidador',
                            style: GoogleFonts.leagueSpartan(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (_telefoneCuidador != null && _telefoneCuidador!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Telefone: $_telefoneCuidador',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Telefone não cadastrado',
                                style: GoogleFonts.leagueSpartan(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Text(
                        'Nenhum familiar vinculado encontrado.',
                        style: GoogleFonts.leagueSpartan(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Em caso de emergência, use o botão acima para ligar diretamente para seu familiar cadastrado.',
                      style: GoogleFonts.leagueSpartan(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


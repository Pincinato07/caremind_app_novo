import 'package:flutter/material.dart';
import 'auth_screen.dart';

class FamilyRoleSelectionScreen extends StatelessWidget {
  const FamilyRoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA), // Branco Neve
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0400B9),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              
              // Título e pergunta
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Plano Família',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0400B9),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Como você usará o CareMind?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Selecione a opção que melhor descreve seu perfil',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Botões de seleção de papel
              Column(
                children: [
                  // Botão Familiar/Cuidador
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AuthScreen(tipo: 'familiar'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0400B9),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.family_restroom,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sou o Familiar / Cuidador',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Botão Idoso
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/link-account');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0400B9),
                        side: const BorderSide(
                          color: Color(0xFF0400B9),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.elderly,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sou o Idoso',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

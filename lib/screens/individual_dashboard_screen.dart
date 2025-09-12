import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class IndividualDashboardScreen extends StatelessWidget {
  const IndividualDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
        title: const Text(
          'CareMind - Individual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0400B9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0400B9),
                    width: 2,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.person,
                      size: 80,
                      color: Color(0xFF0400B9),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '🎉 Sucesso!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0400B9),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Redirecionamento Individual realizado com sucesso!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Você está logado como usuário Individual no CareMind.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Esta é uma tela placeholder. As funcionalidades específicas do usuário individual serão implementadas nas próximas fases do projeto.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class FamiliarDashboardScreen extends StatelessWidget {
  const FamiliarDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
        title: const Text(
          'CareMind - Família',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header de boas-vindas
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0400B9).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 48,
                      color: Color(0xFF0400B9),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Bem-vindo ao CareMind!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0400B9),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Cuidando com amor e dedicação',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Menu de funcionalidades
              const Text(
                'Funcionalidades',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 16),

              // Card Gerenciar Familiares
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0400B9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Gerenciar Familiares',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: const Text(
                    'Visualize e gerencie os membros da família',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () {
                    // Temporariamente placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gerenciamento de familiares em desenvolvimento'),
                        backgroundColor: Color(0xFF0400B9),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Card Medicamentos dos Familiares
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Container(
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
                  title: const Text(
                    'Medicamentos dos Familiares',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: const Text(
                    'Acompanhe os medicamentos de quem você cuida',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () {
                    // Temporariamente placeholder
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Medicamentos dos familiares em desenvolvimento'),
                        backgroundColor: Color(0xFF0400B9),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Placeholder para futuras funcionalidades
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.more_horiz,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mais funcionalidades',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Em breve...',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

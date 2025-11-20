import 'package:flutter/material.dart';
import '../rotinas/gestao_rotinas_screen.dart';

class RotinaIdosoScreen extends StatelessWidget {
  const RotinaIdosoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GestaoRotinasScreen();
  }
}

// Código antigo mantido para referência (pode ser removido)
class _OldRotinaIdosoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFAFA),
      appBar: AppBar(
        title: const Text(
          'Minha Rotina',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card de Hoje
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.today,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Hoje',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildScheduleItem(
                    context,
                    time: '08:00',
                    title: 'Tomar Café da Manhã',
                    subtitle: 'Pão integral, suco de laranja e café com leite',
                    icon: Icons.breakfast_dining,
                    color: Colors.orange,
                  ),
                  _buildDivider(),
                  _buildScheduleItem(
                    context,
                    time: '09:00',
                    title: 'Tomar Remédio',
                    subtitle: 'Paracetamol 500mg',
                    icon: Icons.medication,
                    color: Colors.red,
                  ),
                  _buildDivider(),
                  _buildScheduleItem(
                    context,
                    time: '10:00',
                    title: 'Caminhada',
                    subtitle: '30 minutos no parque',
                    icon: Icons.directions_walk,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Próximos Dias
          Text(
            'Próximos Dias',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          _buildDaySchedule(
            context,
            day: 'Amanhã',
            date: '13/11/2023',
            items: [
              _buildScheduleItem(
                context,
                time: '14:00',
                title: 'Consulta Médica',
                subtitle: 'Dr. Carlos - Cardiologista',
                icon: Icons.medical_services,
                color: Colors.blue,
                showDivider: false,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          _buildDaySchedule(
            context,
            day: 'Quarta-feira',
            date: '14/11/2023',
            items: [
              _buildScheduleItem(
                context,
                time: '10:00',
                title: 'Fisioterapia',
                subtitle: 'Clínica Bem Estar',
                icon: Icons.accessible_forward,
                color: Colors.purple,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDaySchedule(
    BuildContext context, {
    required String day,
    required String date,
    required List<Widget> items,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  day,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }
  
  Widget _buildScheduleItem(
    BuildContext context, {
    required String time,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              alignment: Alignment.topLeft,
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, top: 4),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) _buildDivider(),
      ],
    );
  }
  
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12.0),
      child: Divider(height: 1, thickness: 1),
    );
  }
}

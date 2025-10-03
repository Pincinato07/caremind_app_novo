// lib/screens/metricas_screen.dart

import 'package:flutter/material.dart';

class MetricasScreen extends StatelessWidget {
  const MetricasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Métricas de Saúde'),
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_heart,
              size: 80,
              color: Color(0xFF0400B9),
            ),
            SizedBox(height: 16),
            Text(
              'Tela de Métricas',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0400B9),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Registre suas métricas de saúde\n(pressão, glicemia, peso, etc.)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

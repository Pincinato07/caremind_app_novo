// lib/screens/familiares_screen.dart

import 'package:flutter/material.dart';

class FamiliaresScreen extends StatelessWidget {
  const FamiliaresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familiares'),
        backgroundColor: const Color(0xFF0400B9),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_rounded,
              size: 80,
              color: Color(0xFF0400B9),
            ),
            SizedBox(height: 16),
            Text(
              'Tela de Familiares',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0400B9),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Visualize e gerencie os idosos\nvinculados à sua conta',
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

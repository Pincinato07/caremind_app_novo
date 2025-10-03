import 'package:flutter/material.dart';

class RotinaScreen extends StatelessWidget {
  const RotinaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Rotina'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Sua rotina de cuidados será exibida aqui',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}

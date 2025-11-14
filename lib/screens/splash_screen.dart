import 'package:flutter/material.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Adicione aqui qualquer inicialização necessária
    // Por exemplo: carregar configurações, autenticação, etc.
    
    // Tempo mínimo de exibição da splash screen (2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Navega para a tela de onboarding após o tempo de exibição
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/caremind.png',
          width: 200, // Ajuste o tamanho conforme necessário
          height: 200, // Ajuste o tamanho conforme necessário
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

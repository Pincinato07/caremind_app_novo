import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:qr_flutter/qr_flutter.dart'; // TODO: Adicionar dependência qr_flutter no pubspec.yaml

class ExibirConviteScreen extends StatelessWidget {
  final String codigoConvite;
  final String deepLink;

  const ExibirConviteScreen({
    Key? key,
    required this.codigoConvite,
    required this.deepLink
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convite de Vínculo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Compartilhe este código com o familiar para vincular à conta:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),

            // QR Code com o deep link
            // TODO: Descomentar quando qr_flutter for adicionado ao pubspec.yaml
            // Container(
            //   padding: const EdgeInsets.all(16),
            //   decoration: BoxDecoration(
            //     border: Border.all(color: Colors.blue, width: 2),
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: QrImageView(
            //     data: deepLink,
            //     version: QrVersions.auto,
            //     size: 200.0,
            //   ),
            // ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.qr_code,
                size: 200.0,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Código: $codigoConvite',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Ou compartilhe o link de convite:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: () async {
                await Share.share(
                  'Use este link para se conectar à nossa família no CareMind: $deepLink\n\nCódigo alternativo: $codigoConvite',
                  subject: 'Convite para o CareMind',
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar Link'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              'Instruções:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '1. Compartilhe este código ou link com o familiar que deseja vincular\n'
                '2. Peça para a pessoa abrir o aplicativo e selecionar "Sou um familiar"\n'
                '3. Na tela de login, selecione "Já tenho um código de convite"\n'
                '4. Insira o código ou use o link para concluir o vínculo',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

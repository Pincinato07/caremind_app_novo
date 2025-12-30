import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/caremind_card.dart';
import '../../../core/injection/injection.dart';
import '../medication/gestao_medicamentos_screen.dart';
import '../medication/add_edit_medicamento_form.dart';

class EmptyStateContextual extends StatelessWidget {
  final String userId;

  const EmptyStateContextual({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingService.hasFirstMedicamento(userId),
      builder: (context, snapshot) {
        final hasFirstMedicamento = snapshot.data ?? false;

        if (hasFirstMedicamento) {
          return CareMindEmptyState(
            icon: Icons.medication_liquid,
            title: 'Nenhum medicamento cadastrado',
            message: 'Você não tem medicamentos cadastrados no momento.\nQue tal adicionar um novo?',
            actionLabel: 'Adicionar Medicamento',
            onAction: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEditMedicamentoForm()),
              );
            },
          );
        }

        return CareMindEmptyState(
          icon: Icons.auto_awesome,
          title: 'Bem-vindo ao CareMind!',
          message: 'Para começar a cuidar da sua saúde, vamos cadastrar seu primeiro medicamento?',
          actionLabel: 'Começar Agora',
          onAction: () {
             Navigator.of(context).pushNamed('/gestao-medicamentos');
          },
        );
      },
    );
  }
}

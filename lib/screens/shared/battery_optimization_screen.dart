import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

/// Tela de instruções para desabilitar otimização de bateria
/// 
/// Esta tela instrui o usuário a desabilitar a otimização de bateria
/// para garantir que os alarmes de medicamentos funcionem corretamente.
class BatteryOptimizationScreen extends StatefulWidget {
  const BatteryOptimizationScreen({super.key});

  @override
  State<BatteryOptimizationScreen> createState() => _BatteryOptimizationScreenState();
}

class _BatteryOptimizationScreenState extends State<BatteryOptimizationScreen> {
  bool _isChecking = true;
  bool _isOptimized = true;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
  }

  /// Verificar status de otimização de bateria
  Future<void> _checkBatteryOptimization() async {
    setState(() => _isChecking = true);

    try {
      final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;
      setState(() {
        _isOptimized = !isIgnoring;
        _isChecking = false;
      });
    } catch (e) {
      setState(() {
        _isOptimized = true; // Assumir otimizado em caso de erro
        _isChecking = false;
      });
    }
  }

  /// Solicitar desabilitar otimização de bateria
  Future<void> _requestDisableOptimization() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      
      if (status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Otimização de bateria desabilitada com sucesso!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        await _checkBatteryOptimization();
      } else if (status.isPermanentlyDenied) {
        // Abrir configurações do sistema
        await _openBatterySettings();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Permissão negada. Abra as configurações manualmente.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Abrir configurações de bateria do sistema
  Future<void> _openBatterySettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Não foi possível abrir as configurações: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Otimização de Bateria'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ícone e título
            const Icon(
              Icons.battery_charging_full,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Otimização de Bateria',
              style: AppTextStyles.leagueSpartan(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Para garantir que os alarmes de medicamentos funcionem corretamente, é necessário desabilitar a otimização de bateria para o CareMind.',
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Status atual
            if (_isChecking)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (!_isOptimized)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Otimização de bateria está desabilitada. Os alarmes funcionarão corretamente!',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppColors.warning,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Otimização de bateria está ativa. Os alarmes podem não funcionar corretamente.',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Instruções passo a passo
            Text(
              'Como desabilitar:',
              style: AppTextStyles.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              number: 1,
              text: 'Toque no botão abaixo para abrir as configurações',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: 2,
              text: 'Procure por "Otimização de Bateria" ou "Battery Optimization"',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: 3,
              text: 'Encontre "CareMind" na lista de apps',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: 4,
              text: 'Selecione "Não otimizar" ou "Don\'t optimize"',
            ),
            const SizedBox(height: 12),
            _buildInstructionStep(
              number: 5,
              text: 'Volte ao app e toque em "Verificar novamente"',
            ),

            const SizedBox(height: 32),

            // Botões de ação
            ElevatedButton.icon(
              onPressed: _requestDisableOptimization,
              icon: const Icon(Icons.settings),
              label: const Text('Desabilitar Otimização'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _openBatterySettings,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir Configurações do Sistema'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _checkBatteryOptimization,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar Novamente'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 24),

            // Informação adicional
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Por que isso é importante?',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O Android pode "matar" apps em segundo plano para economizar bateria. '
                    'Ao desabilitar a otimização para o CareMind, garantimos que os alarmes '
                    'de medicamentos sempre funcionem, mesmo quando o app está fechado.',
                    style: AppTextStyles.leagueSpartan(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep({required int number, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: AppTextStyles.leagueSpartan(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.leagueSpartan(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}


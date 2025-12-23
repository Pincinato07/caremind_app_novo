import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget reutilizável para exibir frequência de rotinas de forma legível
///
/// Suporta todos os tipos de frequência:
/// - Diário (múltiplos horários)
/// - Intervalo de horas
/// - Dias alternados
/// - Semanal
class RotinaFrequenciaWidget extends StatelessWidget {
  final Map<String, dynamic>? frequencia;
  final TextStyle? textStyle;
  final Color? iconColor;
  final bool showIcon;

  const RotinaFrequenciaWidget({
    super.key,
    required this.frequencia,
    this.textStyle,
    this.iconColor,
    this.showIcon = true,
  });

  /// Formatar frequência como string
  static String formatarFrequencia(Map<String, dynamic>? frequencia) {
    if (frequencia == null) return 'Sem frequência definida';

    final tipo = frequencia['tipo'] as String?;
    if (tipo == null) return 'Frequência inválida';

    switch (tipo) {
      case 'diario':
        final horarios = frequencia['horarios'] as List?;
        if (horarios != null && horarios.isNotEmpty) {
          final horariosStr = horarios.map((h) => h.toString()).join(', ');
          return 'Diário - $horariosStr';
        }
        return 'Diário';
      case 'intervalo':
        final intervaloHoras = frequencia['intervalo_horas'] as int? ?? 8;
        final inicio = frequencia['inicio'] as String? ?? '';
        return 'A cada ${intervaloHoras}h (início: $inicio)';
      case 'dias_alternados':
        final intervaloDias = frequencia['intervalo_dias'] as int? ?? 2;
        final horario = frequencia['horario'] as String? ?? '';
        return 'A cada $intervaloDias dias ($horario)';
      case 'semanal':
        final diasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
        final dias = frequencia['dias_da_semana'] as List?;
        final horario = frequencia['horario'] as String? ?? '';
        if (dias != null && dias.isNotEmpty) {
          final diasStr = dias
              .map((d) => diasSemana[(d as int) - 1])
              .join(', ');
          return 'Toda $diasStr ($horario)';
        }
        return 'Semanal ($horario)';
      default:
        return 'Frequência personalizada';
    }
  }

  /// Obter ícone baseado no tipo de frequência
  static IconData _getIcon(String? tipo) {
    switch (tipo) {
      case 'diario':
        return Icons.today;
      case 'intervalo':
        return Icons.schedule;
      case 'dias_alternados':
        return Icons.calendar_today;
      case 'semanal':
        return Icons.calendar_view_week;
      default:
        return Icons.repeat;
    }
  }

  /// Obter cor baseada no tipo de frequência
  static Color _getColor(String? tipo) {
    switch (tipo) {
      case 'diario':
        return AppColors.primary;
      case 'intervalo':
        return Colors.orange;
      case 'dias_alternados':
        return Colors.purple;
      case 'semanal':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (frequencia == null) {
      return Text(
        'Sem frequência definida',
        style: textStyle ??
            TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
      );
    }

    final tipo = frequencia!['tipo'] as String?;
    final texto = formatarFrequencia(frequencia);
    final cor = iconColor ?? _getColor(tipo);

    if (!showIcon) {
      return Text(
        texto,
        style: textStyle ??
            TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getIcon(tipo),
          size: 16,
          color: cor,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: textStyle ??
                TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Widget compacto para exibir frequência em cards pequenos
class RotinaFrequenciaCompact extends StatelessWidget {
  final Map<String, dynamic>? frequencia;

  const RotinaFrequenciaCompact({
    super.key,
    required this.frequencia,
  });

  @override
  Widget build(BuildContext context) {
    return RotinaFrequenciaWidget(
      frequencia: frequencia,
      showIcon: false,
      textStyle: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade600,
      ),
    );
  }
}


import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'adherence_bar_chart.dart';

/// Gráfico de linha para visualizar tendência de adesão
/// Mostra porcentagem de adesão ao longo do tempo
class AdherenceLineChart extends StatelessWidget {
  final List<DailyAdherence> data;
  final String title;

  const AdherenceLineChart({
    super.key,
    required this.data,
    this.title = 'Tendência de Adesão',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppBorderRadius.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          SizedBox(
            height: 180,
            child: data.isEmpty
                ? _buildEmptyState()
                : LineChart(
                    _buildLineChartData(),
                  ),
          ),
          const SizedBox(height: AppSpacing.small),
          _buildAverageInfo(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 48,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            'Sem dados de tendência',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageInfo() {
    if (data.isEmpty) return const SizedBox.shrink();

    final average = data
            .map((d) => d.adherencePercentage)
            .reduce((a, b) => a + b) /
        data.length;

    Color averageColor;
    String averageLabel;

    if (average >= 80) {
      averageColor = AppColors.success;
      averageLabel = 'Excelente';
    } else if (average >= 60) {
      averageColor = AppColors.warning;
      averageLabel = 'Regular';
    } else {
      averageColor = AppColors.error;
      averageLabel = 'Precisa melhorar';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.small),
      decoration: BoxDecoration(
        color: averageColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(
          color: averageColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up_rounded,
            size: 16,
            color: averageColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Média: ${average.toStringAsFixed(1)}%',
            style: AppTextStyles.bodySmall.copyWith(
              color: averageColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Text(
            ' • $averageLabel',
            style: AppTextStyles.bodySmall.copyWith(
              color: averageColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < data.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[value.toInt()].dayLabel,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 20,
            getTitlesWidget: (value, meta) {
              return Text(
                '${value.toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: _buildSpots(),
          isCurved: true,
          color: AppColors.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: AppColors.primary,
                strokeWidth: 2,
                strokeColor: AppColors.surface,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withOpacity(0.1),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => AppColors.primary.withOpacity(0.9),
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final dayData = data[spot.x.toInt()];
              return LineTooltipItem(
                '${dayData.dayLabel}\n${spot.y.toStringAsFixed(1)}%\n${dayData.taken}/${dayData.taken + dayData.missed}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    return List.generate(
      data.length,
      (index) => FlSpot(
        index.toDouble(),
        data[index].adherencePercentage,
      ),
    );
  }
}

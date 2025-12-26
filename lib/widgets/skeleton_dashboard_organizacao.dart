import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Skeleton Loader para Dashboard de Organização
/// Simula o layout de gráficos e cards com animação de shimmer
class SkeletonDashboardOrganizacao extends StatelessWidget {
  const SkeletonDashboardOrganizacao({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeaderSkeleton(),
          const SizedBox(height: 24),

          // Card de Métrica Principal
          _buildMetricCardSkeleton(),
          const SizedBox(height: 16),

          // Gráfico de Barras
          _buildBarChartSkeleton(),
          const SizedBox(height: 16),

          // Gráfico de Linha
          _buildLineChartSkeleton(),
          const SizedBox(height: 16),

          // Lista de Pacientes (3 itens)
          _buildPatientListSkeleton(),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ).animate(
          onPlay: (controller) => controller.repeat(),
        ).shimmer(
          duration: const Duration(seconds: 2),
          color: Colors.grey[300]!,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
                  ),
              const SizedBox(height: 6),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ).animate().shimmer(
                duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
              ),
          const SizedBox(height: 16),
          
          // Métrica
          Row(
            children: [
              // Círculo progressivo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
                  ),
              const SizedBox(width: 16),
              
              // Textos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animate().shimmer(
                          duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
                        ),
                    const SizedBox(height: 6),
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animate().shimmer(
                          duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
                        ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ).animate().shimmer(
                duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
              ),
          const SizedBox(height: 16),
          
          // Barras
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final height = 40.0 + (index * 8.0);
              return Container(
                width: 12,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
                    delay: Duration(milliseconds: index * 100),
            color: Colors.grey[300]!,
                  );
            }),
          ),
          
          const SizedBox(height: 8),
          
          // Dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              return Container(
                width: 10,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
                    delay: Duration(milliseconds: index * 100),
            color: Colors.grey[300]!,
                  );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChartSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ).animate().shimmer(
                duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
              ),
          const SizedBox(height: 16),
          
          // Linha simulada
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ).animate().shimmer(
                duration: const Duration(seconds: 2),
            color: Colors.grey[300]!,
              ),
        ],
      ),
    );
  }

  Widget _buildPatientListSkeleton() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
                    delay: Duration(milliseconds: index * 200),
            color: Colors.grey[300]!,
                  ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100 + (index * 20.0),
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animate().shimmer(
                          duration: const Duration(seconds: 2),
                          delay: Duration(milliseconds: index * 200),
            color: Colors.grey[300]!,
                        ),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animate().shimmer(
                          duration: const Duration(seconds: 2),
                          delay: Duration(milliseconds: index * 200),
            color: Colors.grey[300]!,
                        ),
                  ],
                ),
              ),
              
              // Botão simulado
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animate().shimmer(
                    duration: const Duration(seconds: 2),
                    delay: Duration(milliseconds: index * 200),
            color: Colors.grey[300]!,
                  ),
            ],
          ),
        );
      }),
    );
  }
}


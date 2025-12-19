import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'premium_sales_modal.dart';

enum PremiumGuardMode {
  blur,
  blockTouch,
}

class PremiumGuard extends StatelessWidget {
  final Widget child;
  final bool isEnabled;
  final PremiumGuardMode mode;
  final VoidCallback? onPremiumRequired;

  const PremiumGuard({
    super.key,
    required this.child,
    required this.isEnabled,
    this.mode = PremiumGuardMode.blockTouch,
    this.onPremiumRequired,
  });

  @override
  Widget build(BuildContext context) {
    if (isEnabled) {
      return child;
    }

    switch (mode) {
      case PremiumGuardMode.blur:
        return _buildBlurMode(context);
      case PremiumGuardMode.blockTouch:
        return _buildBlockTouchMode(context);
    }
  }

  Widget _buildBlurMode(BuildContext context) {
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: child,
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _showPremiumModal(context),
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: _buildLockBadge(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockTouchMode(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPremiumModal(context),
      child: Stack(
        children: [
          // ✅ Melhorado: Opacidade menos agressiva (0.6 ao invés de 0.4)
          // Evita parecer que a tela está "quebrada"
          Opacity(
            opacity: 0.6,
            child: IgnorePointer(
              child: child,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Center(
                child: _buildLockBadge(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.amber.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recurso Premium',
                style: AppTextStyles.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Toque para ver e desbloquear',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPremiumModal(BuildContext context) {
    if (onPremiumRequired != null) {
      onPremiumRequired!();
    }
    PremiumSalesModal.show(context);
  }
}


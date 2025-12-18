import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class ConfirmMedicationButton extends StatefulWidget {
  final bool isConfirmed;
  final bool isLoading;
  final VoidCallback onConfirm;
  final VoidCallback? onUndo;
  final String? medicationName;

  const ConfirmMedicationButton({
    super.key,
    required this.isConfirmed,
    required this.isLoading,
    required this.onConfirm,
    this.onUndo,
    this.medicationName,
  });

  @override
  State<ConfirmMedicationButton> createState() => _ConfirmMedicationButtonState();
}

class _ConfirmMedicationButtonState extends State<ConfirmMedicationButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading) return;

    HapticFeedback.mediumImpact();
    _controller.forward().then((_) {
      _controller.reverse();
    });

    if (widget.isConfirmed && widget.onUndo != null) {
      widget.onUndo!();
    } else if (!widget.isConfirmed) {
      widget.onConfirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.isConfirmed
          ? 'Medicamento ${widget.medicationName ?? ''} já tomado. Toque para desfazer'
          : 'Confirmar que tomou ${widget.medicationName ?? 'medicamento'}',
      button: true,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isConfirmed
                  ? AppColors.success.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isConfirmed
                    ? AppColors.success.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.isConfirmed
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          key: ValueKey(widget.isConfirmed),
                          color: widget.isConfirmed
                              ? AppColors.success
                              : Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isConfirmed ? 'Tomado' : 'Marcar como tomado',
                        style: AppTextStyles.leagueSpartan(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isConfirmed
                              ? AppColors.success
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class CompactConfirmButton extends StatefulWidget {
  final bool isConfirmed;
  final bool isLoading;
  final VoidCallback onTap;

  const CompactConfirmButton({
    super.key,
    required this.isConfirmed,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<CompactConfirmButton> createState() => _CompactConfirmButtonState();
}

class _CompactConfirmButtonState extends State<CompactConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isLoading) return;
    
    HapticFeedback.lightImpact();
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isConfirmed
                ? AppColors.success
                : Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isConfirmed
                  ? AppColors.success
                  : Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  widget.isConfirmed
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }
}


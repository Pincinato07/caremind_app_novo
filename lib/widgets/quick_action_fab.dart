import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Menu de ações rápidas com FAB expandido
class QuickActionFAB extends StatefulWidget {
  final VoidCallback? onMedicationTap;
  final VoidCallback? onVitalSignTap;
  final VoidCallback? onEventTap;
  final VoidCallback? onEmergencyTap;

  const QuickActionFAB({
    super.key,
    this.onMedicationTap,
    this.onVitalSignTap,
    this.onEventTap,
    this.onEmergencyTap,
  });

  @override
  State<QuickActionFAB> createState() => _QuickActionFABState();
}

class _QuickActionFABState extends State<QuickActionFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    try {
      setState(() {
        _isExpanded = !_isExpanded;
        if (_isExpanded) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      });
    } catch (e) {
      debugPrint('❌ QuickActionFAB: Erro ao alternar expansão - $e');
      // Tentar resetar estado em caso de erro
      try {
        if (_isExpanded) {
          _animationController.reverse();
        }
      } catch (_) {
        // Ignorar erro ao resetar
      }
    }
  }

  void _handleAction(VoidCallback? callback) {
    try {
      if (callback != null) {
        _toggleExpanded();
        callback();
      } else {
        debugPrint('⚠️ QuickActionFAB: Callback não fornecido');
      }
    } catch (e) {
      debugPrint('❌ QuickActionFAB: Erro ao executar ação - $e');
      // Fechar menu em caso de erro
      if (_isExpanded) {
        _toggleExpanded();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Botões de ação rápida
        if (_isExpanded) ...[
          _buildActionButton(
            icon: Icons.medication_liquid,
            label: 'Medicamento',
            color: AppColors.primary,
            offset: const Offset(0, -80),
            onTap: () => _handleAction(widget.onMedicationTap),
            index: 0,
          ),
          _buildActionButton(
            icon: Icons.favorite,
            label: 'Sinal Vital',
            color: AppColors.error,
            offset: const Offset(0, -140),
            onTap: () => _handleAction(widget.onVitalSignTap),
            index: 1,
          ),
          _buildActionButton(
            icon: Icons.event_note,
            label: 'Evento',
            color: AppColors.accent,
            offset: const Offset(0, -200),
            onTap: () => _handleAction(widget.onEventTap),
            index: 2,
          ),
          if (widget.onEmergencyTap != null)
            _buildActionButton(
              icon: Icons.warning,
              label: 'Emergência',
              color: Colors.red,
              offset: const Offset(0, -260),
              onTap: () => _handleAction(widget.onEmergencyTap),
              index: 3,
            ),
        ],
        
        // FAB principal
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _toggleExpanded,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _rotationAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnimation.value * 2 * 3.14159,
                    child: Icon(
                      _isExpanded ? Icons.close : Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Offset offset,
    required VoidCallback onTap,
    required int index,
  }) {
    return Positioned(
      bottom: offset.dy + 56,
      right: offset.dx,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.leagueSpartan(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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


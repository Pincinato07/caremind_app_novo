import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'glass_card.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final int index;
  final bool enableHover;

  const AnimatedCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.index = 0,
    this.enableHover = true,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _isPressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: GlassCard(
          padding: widget.padding ?? const EdgeInsets.all(16),
          child: widget.child,
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 50 * widget.index),
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 400.ms,
          delay: Duration(milliseconds: 50 * widget.index),
          curve: Curves.easeOutCubic,
        );
  }
}

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AnimatedListItem({
    super.key,
    required this.child,
    this.index = 0,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: child
          .animate()
          .fadeIn(
            duration: 300.ms,
            delay: Duration(milliseconds: 30 * index),
          )
          .slideX(
            begin: 0.05,
            end: 0,
            duration: 300.ms,
            delay: Duration(milliseconds: 30 * index),
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class ScaleOnTapCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const ScaleOnTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<ScaleOnTapCard> createState() => _ScaleOnTapCardState();
}

class _ScaleOnTapCardState extends State<ScaleOnTapCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class ShimmerOnLoad extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerOnLoad({
    super.key,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return child.animate(onPlay: (controller) => controller.repeat()).shimmer(
            duration: 1500.ms,
            color: Colors.white.withValues(alpha: 0.3),
          );
    }
    return child;
  }
}

class SuccessCheckAnimation extends StatelessWidget {
  final bool show;
  final VoidCallback? onComplete;

  const SuccessCheckAnimation({
    super.key,
    this.show = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade400,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 36,
      ),
    )
        .animate(onComplete: (_) => onComplete?.call())
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.elasticOut,
        )
        .then()
        .shake(hz: 2, duration: 300.ms)
        .then(delay: 500.ms)
        .fadeOut(duration: 200.ms);
  }
}

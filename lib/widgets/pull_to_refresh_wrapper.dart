import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PullToRefreshWrapper extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? backgroundColor;
  final Color? color;
  
  const PullToRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.backgroundColor,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      backgroundColor: backgroundColor ?? AppColors.primary,
      color: color ?? Colors.white,
      strokeWidth: 2.5,
      displacement: 40,
      edgeOffset: 0,
      child: child,
    );
  }
}

class AnimatedPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshingText;
  final String? pullText;
  
  const AnimatedPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.refreshingText,
    this.pullText,
  });
  
  @override
  State<AnimatedPullToRefresh> createState() => _AnimatedPullToRefreshState();
}

class _AnimatedPullToRefreshState extends State<AnimatedPullToRefresh> with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  late AnimationController _rotationController;
  
  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }
  
  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }
  
  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    _rotationController.repeat();
    
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        _rotationController.stop();
        _rotationController.reset();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      backgroundColor: AppColors.primary,
      color: Colors.white,
      strokeWidth: 2.5,
      displacement: 40,
      child: Stack(
        children: [
          widget.child,
          if (_isRefreshing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: AppColors.primary.withValues(alpha: 0.9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationController,
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.refreshingText ?? 'Atualizando...',
                      style: AppTextStyles.leagueSpartan(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

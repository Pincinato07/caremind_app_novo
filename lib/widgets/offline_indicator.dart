import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_cache_service.dart';
import '../theme/app_theme.dart';

class OfflineIndicator extends StatefulWidget {
  final Widget child;
  
  const OfflineIndicator({super.key, required this.child});
  
  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> with SingleTickerProviderStateMixin {
  bool _isOnline = true;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkConnectivity() async {
    final isOnline = await OfflineCacheService.isOnline();
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
      });
      if (!isOnline) {
        _animationController.forward();
      }
    }
  }
  
  void _listenToConnectivity() {
    OfflineCacheService.connectivityStream.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (!isOnline) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isOnline)
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Positioned(
                top: _slideAnimation.value,
                left: 0,
                right: 0,
                child: child!,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Você está offline. Usando dados salvos.',
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
          ),
      ],
    );
  }
}

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            'Offline',
            style: AppTextStyles.leagueSpartan(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class LastSyncInfo extends StatelessWidget {
  final DateTime? lastSync;
  
  const LastSyncInfo({super.key, this.lastSync});
  
  @override
  Widget build(BuildContext context) {
    if (lastSync == null) return const SizedBox.shrink();
    
    final difference = DateTime.now().difference(lastSync!);
    String timeAgo;
    
    if (difference.inMinutes < 1) {
      timeAgo = 'agora';
    } else if (difference.inMinutes < 60) {
      timeAgo = 'há ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      timeAgo = 'há ${difference.inHours}h';
    } else {
      timeAgo = 'há ${difference.inDays} dia(s)';
    }
    
    return Text(
      'Última atualização: $timeAgo',
      style: AppTextStyles.leagueSpartan(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
}


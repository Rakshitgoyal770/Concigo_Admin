import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerPosition = Tween<double>(
      begin: -0.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerPosition,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceVariant,
                AppTheme.outline.withAlpha(80),
                AppTheme.surfaceVariant,
              ],
              stops: [
                (_shimmerPosition.value - 0.3).clamp(0.0, 1.0),
                _shimmerPosition.value.clamp(0.0, 1.0),
                (_shimmerPosition.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        );
      },
    );
  }
}

class CardSkeletonWidget extends StatelessWidget {
  const CardSkeletonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LoadingSkeletonWidget(
                width: 40,
                height: 40,
                borderRadius: 12,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LoadingSkeletonWidget(
                    width: 120,
                    height: 14,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 6),
                  LoadingSkeletonWidget(width: 80, height: 11, borderRadius: 4),
                ],
              ),
              const Spacer(),
              const LoadingSkeletonWidget(
                width: 60,
                height: 24,
                borderRadius: 100,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const LoadingSkeletonWidget(
            width: double.infinity,
            height: 11,
            borderRadius: 4,
          ),
          const SizedBox(height: 6),
          const LoadingSkeletonWidget(width: 200, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

class ListSkeletonWidget extends StatelessWidget {
  final int itemCount;
  const ListSkeletonWidget({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (_) => const CardSkeletonWidget()),
    );
  }
}

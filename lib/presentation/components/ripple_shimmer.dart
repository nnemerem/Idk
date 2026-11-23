import 'package:flutter/material.dart';

/// A skeleton shimmer that sweeps a soft light across the child.
///
/// Wrap a static-colored skeleton container with this and it gains an
/// Instagram-style light sweep while content loads.
class RippleShimmer extends StatefulWidget {
  final Widget child;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  const RippleShimmer({
    super.key,
    required this.child,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  @override
  State<RippleShimmer> createState() => _RippleShimmerState();
}

class _RippleShimmerState extends State<RippleShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final x = -1.7 + 3.4 * _controller.value;
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.rectangle
                        ? widget.borderRadius
                        : null,
                    gradient: LinearGradient(
                      begin: Alignment(x, -0.45),
                      end: Alignment(x + 0.75, 0.45),
                      colors: const [
                        Color(0x00000000),
                        Color(0x2EFFFFFF),
                        Color(0x00000000),
                      ],
                      stops: const [0.30, 0.5, 0.70],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

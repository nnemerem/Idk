import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A tappable icon button with a small pop animation (Instagram-style
/// micro-interaction). The icon scales up momentarily and eases back.
class AnimatedActionButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onTap;

  const AnimatedActionButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  State<AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final scale = 1.0 + 0.38 * math.sin(_controller.value * math.pi);
            return Transform.scale(
              scale: scale,
              child: widget.icon,
            );
          },
        ),
      ),
    );
  }
}

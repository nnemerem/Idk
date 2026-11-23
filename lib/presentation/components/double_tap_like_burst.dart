import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ripple/config/theme.dart';

/// A gesture wrapper for post media: single-tap forwards to [onTap],
/// double-tap triggers the Instagram-style animated heart burst and calls
/// [onDoubleTap].
class DoubleTapLikeBurst extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const DoubleTapLikeBurst({
    super.key,
    required this.child,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  State<DoubleTapLikeBurst> createState() => _DoubleTapLikeBurstState();
}

class _DoubleTapLikeBurstState extends State<DoubleTapLikeBurst>
    with SingleTickerProviderStateMixin {
  bool _showBurst = false;
  late final AnimationController _controller;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    widget.onDoubleTap();
    _hideTimer?.cancel();
    setState(() => _showBurst = true);
    _controller.forward(from: 0);
    _hideTimer = Timer(const Duration(milliseconds: 680), () {
      if (mounted) setState(() => _showBurst = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: _onDoubleTap,
          behavior: HitTestBehavior.opaque,
          child: widget.child,
        ),
        if (_showBurst)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  final scaleIn = Curves.easeOutBack.transform(
                    (progress / 0.32).clamp(0.0, 1.0),
                  );
                  final scale = 0.4 + 0.7 * scaleIn;
                  final opacity = progress < 0.62
                      ? 1.0
                      : (1 - (progress - 0.62) / 0.38).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: SvgPicture.asset(
                        'assets/icons/heart_filled.svg',
                        width: 110,
                        height: 110,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

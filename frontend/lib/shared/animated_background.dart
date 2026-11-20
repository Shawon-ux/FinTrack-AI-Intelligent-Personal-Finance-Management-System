import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Slowly drifting gradient orbs behind the auth / landing screens.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(double size, Color color, Offset base, double phase, Size screen, double t) {
    final dx = math.sin(t * 2 * math.pi + phase) * 40, dy = math.cos(t * 2 * math.pi * .8 + phase) * 50;
    return Positioned(
      left: base.dx * screen.width - size / 2 + dx,
      top: base.dy * screen.height - size / 2 + dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: C.dark ? .55 : .28), color.withValues(alpha: 0)])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: C.dark ? const [Color(0xFF0B0F1E), Color(0xFF111736), Color(0xFF0B0F1E)] : const [Color(0xFFF4F5FB), Color(0xFFEAEBFA), Color(0xFFF4F5FB)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: LayoutBuilder(builder: (context, box) {
        final s = Size(box.maxWidth, box.maxHeight);
        return Stack(children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Stack(children: [
              _orb(360, C.p, const Offset(.1, .12), 0, s, _c.value),
              _orb(320, C.p2, const Offset(.95, .35), 2, s, _c.value),
              _orb(300, const Color(0xFFB86BFF), const Offset(.2, .9), 4, s, _c.value),
            ]),
          ),
          widget.child,
        ]);
      }),
    );
  }
}

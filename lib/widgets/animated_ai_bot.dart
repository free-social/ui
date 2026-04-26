import 'package:flutter/material.dart';

/// A floating AI bot avatar with three looping animations:
///   • Vertical bob  (1800 ms) — gentle up/down float
///   • 3-D Y-axis tilt (2600 ms) — perspective depth illusion
///   • Z-axis rock   (1400 ms) — body sway / arm-swing effect
///
/// Drop-in replacement wherever the static ai_bot.png is used.
class AnimatedAiBot extends StatefulWidget {
  final double height;

  const AnimatedAiBot({super.key, this.height = 75});

  @override
  State<AnimatedAiBot> createState() => _AnimatedAiBotState();
}

class _AnimatedAiBotState extends State<AnimatedAiBot>
    with TickerProviderStateMixin {
  late final AnimationController _bobCtrl;
  late final AnimationController _tiltCtrl;
  late final AnimationController _rockCtrl;

  late final Animation<double> _bob;   // vertical float
  late final Animation<double> _tilt;  // 3-D Y-axis spin
  late final Animation<double> _rock;  // Z-axis sway (arm swing)

  @override
  void initState() {
    super.initState();

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _tiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _rockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _bob = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _bobCtrl, curve: Curves.easeInOut),
    );

    // ±10° tilt → simulates 3-D perspective spin
    _tilt = Tween<double>(begin: -0.17, end: 0.17).animate(
      CurvedAnimation(parent: _tiltCtrl, curve: Curves.easeInOut),
    );

    // ±5° rock → simulates arms swinging
    _rock = Tween<double>(begin: -0.09, end: 0.09).animate(
      CurvedAnimation(parent: _rockCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _tiltCtrl.dispose();
    _rockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bob, _tilt, _rock]),
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)    // perspective depth
            ..rotateY(_tilt.value)     // 3-D left-right tilt
            ..rotateZ(_rock.value)     // sway (arm swing)
            ..translate(0.0, _bob.value), // vertical float
          child: child,
        );
      },
      child: Image.asset(
        'assets/images/ai_bot.png',
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const CircleAvatar(child: Icon(Icons.auto_awesome)),
      ),
    );
  }
}

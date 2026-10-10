import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'auth/auth_gate.dart';
import 'theme/app_theme.dart';

/// Animated EventEase splash:
///  1. The ribbon bow scales in with a small "tying" twist
///  2. The sparkle pops in, spins, then twinkles
///  3. "EventEase" rises in letter by letter
///  4. The tagline fades in, then the app fades to AuthGate
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _bowAsset = 'assets/branding/eventease_bow.png';
  static const String _sparkleAsset = 'assets/branding/eventease_sparkle.png';

  // Sparkle centre inside the logo canvas (from the exported layers).
  static const Alignment _sparkleCenter = Alignment(0.0, -0.63);

  // Bow canvas is 900 x 587.
  static const double _logoAspect = 900 / 587;

  static const String _name = 'EventEase';
  static const int _splitAt = 5; // "Event" | "Ease"

  late final AnimationController _controller;

  late final Animation<double> _bowFade;
  late final Animation<double> _bowScale;
  late final Animation<double> _bowTwist;
  late final Animation<double> _sparkleScale;
  late final Animation<double> _sparkleSpin;
  late final Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _bowFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );
    _bowScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.34, curve: Curves.easeOutBack),
      ),
    );
    _bowTwist = Tween<double>(begin: -0.18, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutCubic),
      ),
    );
    _sparkleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.48, curve: Curves.easeOutBack),
      ),
    );
    _sparkleSpin = Tween<double>(begin: -math.pi / 2, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.52, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.78, 1.0, curve: Curves.easeOut),
    );

    // Make sure the images are decoded before the animation starts,
    // so the logo never pops in half-way.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        precacheImage(const AssetImage(_bowAsset), context),
        precacheImage(const AssetImage(_sparkleAsset), context),
      ]);
      if (!mounted) return;
      await _controller.forward();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _goNext();
    });
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = math.min(screenWidth * 0.55, 260.0);
    final logoHeight = logoWidth / _logoAspect;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // Twinkle after the sparkle has landed (progress 0.52 -> 1.0).
            final t = _controller.value;
            final twinkle = t > 0.52
                ? 1.0 + 0.16 * math.sin((t - 0.52) * math.pi * 6)
                : 1.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: logoWidth,
                  height: logoHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Bow
                      Opacity(
                        opacity: _bowFade.value,
                        child: Transform.scale(
                          scale: _bowScale.value,
                          child: Transform.rotate(
                            angle: _bowTwist.value,
                            child: Image.asset(_bowAsset, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      // Sparkle
                      Transform.scale(
                        scale: _sparkleScale.value * twinkle,
                        alignment: _sparkleCenter,
                        child: Transform.rotate(
                          angle: _sparkleSpin.value,
                          alignment: _sparkleCenter,
                          child: Image.asset(
                            _sparkleAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildName(t),
                const SizedBox(height: 10),
                Opacity(
                  opacity: _taglineFade.value,
                  child: Text(
                    'Plan. Manage. Celebrate.',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0.4,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// "EventEase", one letter at a time. "Event" is dark, "Ease" is indigo.
  Widget _buildName(double t) {
    final letters = <Widget>[];
    for (var i = 0; i < _name.length; i++) {
      final start = 0.44 + i * 0.035;
      final end = start + 0.2;
      final p = ((t - start) / (end - start)).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(p);

      letters.add(
        Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 16),
            child: Text(
              _name[i],
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1.1,
                color: i < _splitAt ? AppTheme.textPrimary : AppTheme.primary,
              ),
            ),
          ),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: letters);
  }
}

import 'package:flutter/material.dart';

/// Animated splash. The router's auth redirect moves the user on as soon as
/// the Firebase auth state resolves — no manual navigation needed here.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeIn),
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(Icons.sensors, size: 72, color: scheme.primary),
                ),
                const SizedBox(height: 20),
                Text('SpaceSense AI',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 8),
                Text('Loading AI services…',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                const SizedBox(
                    width: 120, child: LinearProgressIndicator(minHeight: 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/responsive/responsive.dart';
import '../core/notifications/notification_router.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/auth/presentation/providers/auth_token_provider.dart';
import '../features/auth/presentation/screens/sign_in_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/altrix_logo.dart';
import 'main_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2800),
    this.skipAnimation = false,
  });

  final Duration duration;
  final bool skipAnimation;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _loaderOpacity;
  late final Animation<double> _ringRotation;

  bool _navigated = false;
  // No separate boolean flags needed — Future.wait handles sequencing.

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.55, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.35, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
    );
    _loaderOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.9, curve: Curves.easeOut),
      ),
    );
    _ringRotation = Tween<double>(
      begin: 0,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!widget.skipAnimation) _controller.forward();

    final startTime = DateTime.now();

    try {
      await ref
          .read(authProvider.notifier)
          .restoreSession()
          .timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (_) {}

    if (!widget.skipAnimation) {
      final elapsed = DateTime.now().difference(startTime);
      final remaining = widget.duration - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }

    if (!mounted) return;
    _goNext();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final token = ref.read(authTokenProvider);
    final nextScreen = token != null ? const MainShell() : const SignInScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationRouter.markReady(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final logoSize = responsive.rz(88).clamp(72.0, 120.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navy,
                    AppColors.navyMid,
                    Color(0xFF1C1654),
                    Color(0xFF2A1B6A),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: Listenable.merge([_controller, _pulseController]),
              builder: (context, _) {
                return CustomPaint(
                  painter: _SplashGlowPainter(
                    progress: _controller.value,
                    pulse: _pulseController.value,
                    rotation: _ringRotation.value,
                  ),
                );
              },
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1 + (_pulseController.value * 0.04),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25 + (_pulseController.value * 0.2),
                                ),
                                blurRadius: 28 + (_pulseController.value * 12),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: AltrixLogo(size: logoSize),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      'Altrixs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: responsive.rz(40),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.rz(14)),
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Your care, in one place',
                      style: TextStyle(
                        color: AppColors.textOnDark,
                        fontSize: responsive.rz(17),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _loaderOpacity,
                    child: const _AnimatedLoader(),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLoader extends StatelessWidget {
  const _AnimatedLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

class _SplashGlowPainter extends CustomPainter {
  _SplashGlowPainter({
    required this.progress,
    required this.pulse,
    required this.rotation,
  });

  final double progress;
  final double pulse;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.38);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * math.pi);
    canvas.translate(-center.dx, -center.dy);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 1; i <= 6; i++) {
      final expand = 1 + (progress * 0.15) + (pulse * 0.05);
      ringPaint.color = const Color(0xFF6B63F0)
          .withValues(alpha: (0.06 + (i * 0.015)) * (0.7 + pulse * 0.3));
      canvas.drawCircle(center, 55.0 * i * expand, ringPaint);
    }

    canvas.restore();

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.22 + pulse * 0.12),
          AppColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 180 + pulse * 30));
    canvas.drawCircle(center, 180 + pulse * 30, glow);

    for (var i = 0; i < 8; i++) {
      final angle = (i / 8) * math.pi * 2 + progress * 0.8;
      final radius = 120 + pulse * 20;
      final dotCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(
        dotCenter,
        2 + pulse,
        Paint()
          ..color = AppColors.primarySoft.withValues(
            alpha: 0.15 + (progress * 0.35),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGlowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.rotation != rotation;
  }
}

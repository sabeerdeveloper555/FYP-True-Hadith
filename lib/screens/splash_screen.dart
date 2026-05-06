import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

// ignore_for_file: library_private_types_in_public_api

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bgCtrl;
  late final AnimationController _titleCtrl;
  late final AnimationController _taglineCtrl;

  late final Animation<double> _bgAnim;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineAnim;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _taglineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeOut);
    _titleOpacity = CurvedAnimation(parent: _titleCtrl, curve: Curves.easeIn);
    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut),
    );
    _taglineAnim =
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn);

    _playSequence();
  }

  Future<void> _playSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _bgCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _titleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 700));
    _taglineCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 700),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgAnim, _titleOpacity, _taglineAnim]),
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Forest-green watercolor background ─────────────────────────
              CustomPaint(
                painter: _WatercolorPainter(progress: _bgAnim.value),
                size: size,
              ),

              // ── Islamic geometric tile overlay ─────────────────────────────
              Opacity(
                opacity: (_bgAnim.value * 0.09).clamp(0.0, 0.09),
                child: CustomPaint(
                  painter: _GeometricTilePainter(),
                  size: size,
                ),
              ),

              // ── Radial vignette ────────────────────────────────────────────
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Gold ornament divider
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: const _GoldOrnament(),
                    ),

                    const SizedBox(height: 24),

                    // App title
                    FadeTransition(
                      opacity: _titleOpacity,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: Text(
                          'True Hadith',
                          style: AppTextStyles.translation(
                            fontSize: 38,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    Opacity(
                      opacity: _taglineAnim.value,
                      child: Text(
                        'VERIFY  ·  AUTHENTICATE  ·  TRUST',
                        style: AppTextStyles.ui(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Bottom caption
                    Opacity(
                      opacity: _taglineAnim.value,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Column(
                          children: [
                            Container(
                              width: 1,
                              height: 28,
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'AI-Powered Hadith Authentication',
                              style: AppTextStyles.ui(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.45),
                                letterSpacing: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Gold ornament divider ──────────────────────────────────────────────────────

class _GoldOrnament extends StatelessWidget {
  const _GoldOrnament();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _hairline(),
        const SizedBox(width: 10),
        const Text('✦',
            style: TextStyle(color: AppColors.accentGold, fontSize: 10)),
        const SizedBox(width: 6),
        const Text('❖',
            style: TextStyle(color: AppColors.accentGold, fontSize: 14)),
        const SizedBox(width: 6),
        const Text('✦',
            style: TextStyle(color: AppColors.accentGold, fontSize: 10)),
        const SizedBox(width: 10),
        _hairline(reversed: true),
      ],
    );
  }

  Widget _hairline({bool reversed = false}) => Container(
        width: 60,
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: reversed
                ? [AppColors.accentGold.withValues(alpha: 0.8), Colors.transparent]
                : [Colors.transparent, AppColors.accentGold.withValues(alpha: 0.8)],
          ),
        ),
      );
}

// ── Watercolor background painter ─────────────────────────────────────────────

class _WatercolorPainter extends CustomPainter {
  final double progress;
  _WatercolorPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep forest-green base gradient
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primaryDark,
          const Color(0xFF0B2218),
          const Color(0xFF0D1F14),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    if (progress <= 0) return;

    // Primary green bloom — top-right
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.82, size.height * 0.18),
      radius: size.width * 0.65 * progress,
      color: AppColors.primary.withValues(alpha: 0.25 * progress),
    );

    // Lighter green — top-left
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.10),
      radius: size.width * 0.4 * progress,
      color: AppColors.primaryLight.withValues(alpha: 0.18 * progress),
    );

    // Gold shimmer — center
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.42),
      radius: size.width * 0.25 * progress,
      color: AppColors.accentGold.withValues(alpha: 0.10 * progress),
    );

    // Dark accent — bottom-left
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.18, size.height * 0.85),
      radius: size.width * 0.55 * progress,
      color: AppColors.primaryDark.withValues(alpha: 0.40 * progress),
    );

    // Dark accent — bottom-right
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.88, size.height * 0.78),
      radius: size.width * 0.38 * progress,
      color: const Color(0xFF0B2218).withValues(alpha: 0.35 * progress),
    );

    // Soft tide marks
    _drawTideMark(canvas, size,
        yFraction: 0.30, progress: progress, color: AppColors.primary);
    _drawTideMark(canvas, size,
        yFraction: 0.68, progress: progress, color: AppColors.accentGold);
  }

  void _drawBloom(Canvas canvas,
      {required Offset center,
      required double radius,
      required Color color}) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.38);
    canvas.drawCircle(center, radius, paint);

    final innerPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12);
    canvas.drawCircle(center, radius * 0.45, innerPaint);
  }

  void _drawTideMark(Canvas canvas, Size size,
      {required double yFraction,
      required double progress,
      required Color color}) {
    final y = size.height * yFraction;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.06 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    path.moveTo(0, y);
    for (double x = 0; x <= size.width; x += 12) {
      final wave = math.sin((x / size.width) * math.pi * 3) * 6 * progress;
      path.lineTo(x, y + wave);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WatercolorPainter old) => old.progress != progress;
}

// ── Islamic geometric tile painter ────────────────────────────────────────────

class _GeometricTilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const tileSize = 72.0;
    const starRadius = 18.0;

    for (double x = -tileSize; x < size.width + tileSize; x += tileSize) {
      for (double y = -tileSize; y < size.height + tileSize; y += tileSize) {
        _drawOctagram(canvas, Offset(x, y), starRadius, paint);
      }
    }
  }

  void _drawOctagram(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    const points = 8;
    const inner = 0.42;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final radius = i.isEven ? r : r * inner;
      final pt = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    canvas.drawPath(path, paint);

    final sq = r * 0.28;
    final squarePath = Path()
      ..moveTo(center.dx, center.dy - sq)
      ..lineTo(center.dx + sq, center.dy)
      ..lineTo(center.dx, center.dy + sq)
      ..lineTo(center.dx - sq, center.dy)
      ..close();
    canvas.drawPath(squarePath, paint);
  }

  @override
  bool shouldRepaint(_GeometricTilePainter old) => false;
}

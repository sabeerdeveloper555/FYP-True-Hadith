import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../services/onboarding_service.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({
    super.key,
    this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Verify Hadith Authenticity',
      description:
          'Upload images or type text to verify hadiths instantly with AI-powered technology',
      icon: Icons.upload_file,
      gradient: const [Color(0xFF2E8B57), Color(0xFF006A60)],
      illustrationColor: const Color(0xFFD4AF37),
    ),
    OnboardingData(
      title: 'Instant Results from Trusted Sources',
      description:
          'Get accurate classifications with references from authenticated Islamic scholars',
      icon: Icons.verified_user,
      gradient: const [Color(0xFF006A60), Color(0xFF004D45)],
      illustrationColor: const Color(0xFF40E0D0),
    ),
    OnboardingData(
      title: 'Ask Islamic Questions Anytime',
      description:
          'Chat with AI assistant for guidance on Islamic teachings and hadith knowledge',
      icon: Icons.chat_bubble_outline,
      gradient: const [Color(0xFF004D45), Color(0xFF2E8B57)],
      illustrationColor: const Color(0xFFD4AF37),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipToLogin() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingService.completeOnboarding();
    if (mounted) {
      if (widget.onComplete != null) {
        widget.onComplete!();
      } else {
        // Fallback navigation
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          // PageView for onboarding pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingPage(data: _pages[index]);
            },
          ),

          // Skip button (top right)
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: _skipToLogin,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Bottom section with dots indicator and button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Next/Get Started button
                  CustomButton(
                    text: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    onPressed: _nextPage,
                    icon: _currentPage == _pages.length - 1
                        ? Icons.arrow_forward
                        : null,
                    width: double.infinity,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage extends StatefulWidget {
  final OnboardingData data;

  const OnboardingPage({super.key, required this.data});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.data.gradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Illustration area
              Expanded(
                flex: 3,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Center(
                    child: CustomIllustration(
                      icon: widget.data.icon,
                      color: widget.data.illustrationColor,
                    ),
                  ),
                ),
              ),

              // Text content
              Expanded(
                flex: 2,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          widget.data.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.data.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Space for bottom controls
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom illustration widget with animated Islamic patterns
class CustomIllustration extends StatefulWidget {
  final IconData icon;
  final Color color;

  const CustomIllustration({
    super.key,
    required this.icon,
    required this.color,
  });

  @override
  State<CustomIllustration> createState() => _CustomIllustrationState();
}

class _CustomIllustrationState extends State<CustomIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated background circles
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(300, 300),
              painter: CirclePatternPainter(
                progress: _controller.value,
                color: widget.color,
              ),
            );
          },
        ),

        // Main icon with glow effect
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(
              color: widget.color.withOpacity(0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            size: 70,
            color: Colors.white,
          ),
        ),

        // Decorative corner elements
        Positioned(
          top: 20,
          left: 20,
          child: _buildDecorativeElement(),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: _buildDecorativeElement(),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: _buildDecorativeElement(),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: _buildDecorativeElement(),
        ),
      ],
    );
  }

  Widget _buildDecorativeElement() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: IslamicCornerPainter(color: Colors.white.withOpacity(0.3)),
      ),
    );
  }
}

// Custom painter for animated circles
class CirclePatternPainter extends CustomPainter {
  final double progress;
  final Color color;

  CirclePatternPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw multiple expanding circles
    for (int i = 0; i < 3; i++) {
      final radius = 60.0 + (i * 30) + (progress * 40);
      final opacity = 0.4 - (progress * 0.3) - (i * 0.1);

      paint.color = color.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CirclePatternPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Custom painter for Islamic corner decorations
class IslamicCornerPainter extends CustomPainter {
  final Color color;

  IslamicCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw decorative corner pattern
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Draw small circles at intersections
    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3, circlePaint);
  }

  @override
  bool shouldRepaint(IslamicCornerPainter oldDelegate) => false;
}

// Data model for onboarding pages
class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradient;
  final Color illustrationColor;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.illustrationColor,
  });
}

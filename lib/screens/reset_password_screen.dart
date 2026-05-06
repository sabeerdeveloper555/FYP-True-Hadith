import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../utils/theme_notifier.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? actionCode;
  final String? email;

  const ResetPasswordScreen({
    super.key,
    this.actionCode,
    this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isVerifyingCode = true;
  String? _verifiedEmail;
  String? _errorMessage;
  String? _currentActionCode;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // If action code is provided, verify it
    if (widget.actionCode != null && widget.actionCode!.isNotEmpty) {
      _currentActionCode = widget.actionCode;
      _verifyActionCode();
    } else {
      setState(() {
        _isVerifyingCode = false;
        _errorMessage =
            'No reset code provided. Please use the link from your email to reset your password.';
      });
    }
  }

  Future<void> _verifyActionCode() async {
    if (widget.actionCode == null || widget.actionCode!.isEmpty) {
      setState(() {
        _isVerifyingCode = false;
        _errorMessage = 'Invalid reset code';
      });
      return;
    }

    try {
      // verifyPasswordResetCode returns the email tied to the action code
      final email = await AuthService.verifyPasswordResetCode(widget.actionCode!);
      setState(() {
        _isVerifyingCode = false;
        _verifiedEmail = email.isNotEmpty ? email : widget.email;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isVerifyingCode = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final actionCode = _currentActionCode ?? widget.actionCode;
    if (actionCode == null || actionCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Invalid reset code. Please enter the code from your email.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.confirmPasswordReset(
        actionCode: actionCode,
        newPassword: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Password reset successful! You can now login with your new password.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );

        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on Exception catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    return Scaffold(
      backgroundColor: ThemeColors.background(isDark),
      body: Stack(
        children: [
          // Curved header with gradient
          ClipPath(
            clipper: CurvedHeaderClipper(),
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2E8B57),
                    Color(0xFF006A60),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Arabic calligraphy watermark
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: CustomPaint(
                        painter: CalligraphyPainter(),
                      ),
                    ),
                  ),
                  // Header content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Reset Password',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              _isVerifyingCode
                                  ? 'Verifying reset code...'
                                  : 'Enter your new password',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 200),

                    // Reset Password Card
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Card(
                          elevation: 8,
                          shadowColor: ThemeColors.shadow(isDark),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _isVerifyingCode
                                ? _buildVerifyingState()
                                : _errorMessage != null
                                    ? _buildErrorState()
                                    : _buildResetForm(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyingState() {
    final isDark = ThemeNotifier.instance.isDark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Verifying reset code...',
          style: TextStyle(
            fontSize: 16,
            color: ThemeColors.textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    final isDark = ThemeNotifier.instance.isDark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: AppColors.error,
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'An error occurred',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: ThemeColors.textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'Back to Login',
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildResetForm() {
    final isDark = ThemeNotifier.instance.isDark;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_verifiedEmail != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _verifiedEmail!,
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textPrimary(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // New Password field
          CustomTextField(
            controller: _passwordController,
            label: 'New Password',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: ThemeColors.textSecondary(isDark),
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Confirm Password field
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm New Password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: ThemeColors.textSecondary(isDark),
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Password requirements
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeColors.inputBackground(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Password Requirements:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                _buildRequirement('At least 6 characters'),
                _buildRequirement(
                    'Use a mix of letters and numbers (recommended)'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          CustomButton(
            text: 'Reset Password',
            onPressed: _handleResetPassword,
            isLoading: _isLoading,
            width: double.infinity,
          ),

          const SizedBox(height: 16),

          // Back to login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Remember your password?',
                style: TextStyle(
                  color: ThemeColors.textSecondary(isDark),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Login',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    final isDark = ThemeNotifier.instance.isDark;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: ThemeColors.textSecondary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom TextField Widget (same as in login_screen.dart)
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeNotifier.instance.isDark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 16,
        color: ThemeColors.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: ThemeColors.textSecondary(isDark),
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ThemeColors.inputBackground(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

// Custom clipper for curved header (same as in login_screen.dart)
class CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 60);

    // Create smooth curve
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 60,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Custom painter for Arabic calligraphy watermark (same as in login_screen.dart)
class CalligraphyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Draw flowing calligraphic pattern
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Create elegant curves
    path.moveTo(centerX - 80, centerY);
    path.quadraticBezierTo(
      centerX - 40,
      centerY - 40,
      centerX,
      centerY - 20,
    );
    path.quadraticBezierTo(
      centerX + 40,
      centerY,
      centerX + 80,
      centerY - 30,
    );

    // Second flowing line
    path.moveTo(centerX - 60, centerY + 20);
    path.quadraticBezierTo(
      centerX - 20,
      centerY + 40,
      centerX + 20,
      centerY + 30,
    );
    path.quadraticBezierTo(
      centerX + 60,
      centerY + 20,
      centerX + 90,
      centerY + 40,
    );

    // Add decorative dots
    canvas.drawCircle(Offset(centerX - 90, centerY - 10), 3,
        paint..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(centerX + 100, centerY - 40), 3, paint);
    canvas.drawCircle(Offset(centerX - 70, centerY + 50), 3, paint);

    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(CalligraphyPainter oldDelegate) => false;
}

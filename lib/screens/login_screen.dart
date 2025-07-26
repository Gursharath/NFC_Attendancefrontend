import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final LocalAuthentication authBiometric = LocalAuthentication();
  bool loading = false;
  bool _obscurePassword = true;

  // Animation Controllers
  late AnimationController _backgroundController;
  late AnimationController _containerController;
  late AnimationController _glowController;
  late AnimationController _matrixController;
  late AnimationController _scanlineController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _backgroundAnimation;
  late Animation<double> _containerAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _matrixAnimation;
  late Animation<double> _scanlineAnimation;
  late Animation<double> _pulseAnimation;

  // Focus nodes
  late FocusNode _emailFocus;
  late FocusNode _passwordFocus;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _emailFocus = FocusNode();
    _passwordFocus = FocusNode();
  }

  void _initializeAnimations() {
    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _backgroundAnimation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(_backgroundController);

    // Container entrance animation
    _containerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _containerAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _containerController, curve: Curves.elasticOut),
    );

    // Glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Matrix animation
    _matrixController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _matrixAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_matrixController);

    // Scanline animation
    _scanlineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scanlineAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_scanlineController);

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(_pulseController);

    // Start entrance animation
    _containerController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _containerController.dispose();
    _glowController.dispose();
    _matrixController.dispose();
    _scanlineController.dispose();
    _pulseController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget _buildMatrixBackground() {
    return AnimatedBuilder(
      animation: _matrixAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: MatrixPainter(_matrixAnimation.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildScanlines() {
    return AnimatedBuilder(
      animation: _scanlineAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: ScanlinePainter(_scanlineAnimation.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGlowingTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FocusNode focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow:
                focusNode.hasFocus
                    ? [
                      BoxShadow(
                        color: const Color(
                          0xFF00BFA6,
                        ).withOpacity(0.3 * _glowAnimation.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                    : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            style: GoogleFonts.sourceCodePro(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.orbitron(
                color:
                    focusNode.hasFocus
                        ? const Color(0xFF00BFA6)
                        : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                        focusNode.hasFocus
                            ? [const Color(0xFF00BFA6), const Color(0xFF00FFC6)]
                            : [Colors.white30, Colors.white70],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.black, size: 20),
              ),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: const Color(0xFF1E1E2C).withOpacity(0.8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFF00BFA6).withOpacity(0.8),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            onTap: () => HapticFeedback.lightImpact(),
          ),
        );
      },
    );
  }

  Widget _buildCyberpunkButton({
    required String text,
    required VoidCallback onPressed,
    required IconData icon,
    Color? backgroundColor,
    Color? textColor,
    bool isLoading = false,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors:
                  backgroundColor != null
                      ? [backgroundColor, backgroundColor.withOpacity(0.8)]
                      : [const Color(0xFF00BFA6), const Color(0xFF00FFC6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (backgroundColor ?? const Color(0xFF00BFA6)).withOpacity(
                  0.3 * _glowAnimation.value,
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon:
                isLoading
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textColor ?? Colors.black,
                        ),
                      ),
                    )
                    : Icon(icon, color: textColor ?? Colors.black),
            label: Text(
              isLoading ? 'PROCESSING...' : text,
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor ?? Colors.black,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginContainer() {
    return AnimatedBuilder(
      animation: _containerAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: _containerAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - _containerAnimation.value)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF00BFA6).withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildLoginForm(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return Column(
          children: [
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BFA6), Color(0xFF00FFC6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFA6).withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.security,
                  color: Colors.black,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  colors: [Color(0xFF00BFA6), Color(0xFF00FFC6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds);
              },
              child: Text(
                'NEURAL_ACCESS',
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'QUANTUM AUTHENTICATION PROTOCOL',
              style: GoogleFonts.sourceCodePro(
                fontSize: 12,
                color: Colors.white60,
                letterSpacing: 1.0,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildGlowingTextField(
          controller: emailController,
          label: 'NEURAL_ID',
          icon: Icons.person_outline,
          focusNode: _emailFocus,
        ),
        const SizedBox(height: 20),
        _buildGlowingTextField(
          controller: passwordController,
          label: 'ACCESS_KEY',
          icon: Icons.lock_outline,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
              HapticFeedback.lightImpact();
            },
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white60,
            ),
          ),
        ),
        const SizedBox(height: 30),
        _buildCyberpunkButton(
          text: 'INITIATE_ACCESS',
          icon: Icons.login,
          isLoading: loading,
          onPressed: _handleLogin,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: GoogleFonts.orbitron(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildCyberpunkButton(
          text: 'BIOMETRIC_AUTH',
          icon: Icons.fingerprint,
          backgroundColor: const Color(0xFF2A2A3E),
          textColor: const Color(0xFF00BFA6),
          onPressed: _authenticateWithBiometrics,
        ),
      ],
    );
  }

  Future<void> _handleLogin() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showNotification(
        'Please enter both neural ID and access key',
        isError: true,
      );
      return;
    }

    setState(() => loading = true);
    HapticFeedback.mediumImpact();

    final auth = Provider.of<AuthService>(context, listen: false);
    final success = await auth.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => loading = false);

    if (success) {
      HapticFeedback.lightImpact();
      _showNotification('Neural access granted', isError: false);

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    } else {
      HapticFeedback.heavyImpact();
      _showNotification('Neural access denied', isError: true);
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      HapticFeedback.lightImpact();

      bool canCheck = await authBiometric.canCheckBiometrics;
      bool isSupported = await authBiometric.isDeviceSupported();

      if (!canCheck || !isSupported) {
        _showNotification('Biometric scanner not available', isError: true);
        return;
      }

      bool authenticated = await authBiometric.authenticate(
        localizedReason: 'Scan your biometric signature for neural access',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        HapticFeedback.lightImpact();
        _showNotification(
          'Biometric authentication successful',
          isError: false,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const HomeScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      _showNotification('Biometric error: ${e.toString()}', isError: true);
    }
  }

  void _showNotification(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  isError
                      ? [Colors.redAccent, Colors.red]
                      : [const Color(0xFF00BFA6), const Color(0xFF00FFC6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (isError ? Colors.redAccent : const Color(0xFF00BFA6))
                    .withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0A0F),
              Color(0xFF1E1E2C),
              Color(0xFF2A2A3E),
              Color(0xFF0F2027),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Matrix background
            _buildMatrixBackground(),

            // Scanlines
            _buildScanlines(),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(child: _buildLoginContainer()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for matrix effect
class MatrixPainter extends CustomPainter {
  final double animationValue;

  MatrixPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF00BFA6).withOpacity(0.1)
          ..strokeWidth = 1;

    final random = Random(42); // Fixed seed for consistent pattern

    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final startY =
          (random.nextDouble() * size.height * 2 -
                  size.height +
                  animationValue * size.height * 2) %
              (size.height * 2) -
          size.height;

      canvas.drawLine(Offset(x, startY), Offset(x, startY + 100), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom painter for scanlines
class ScanlinePainter extends CustomPainter {
  final double animationValue;

  ScanlinePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF00BFA6).withOpacity(0.05)
          ..strokeWidth = 2;

    final y = animationValue * size.height;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_service.dart';
import '../theme_helpers.dart';
import 'root_screen.dart';
import 'admin_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _normalizeLoginEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    return '$trimmed@shsma-web.firebaseapp.com';
  }

  void _handleSignIn() async {
    final rawEmail = _emailController.text.trim();
    final password = _passwordController.text;

    if (rawEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final email = _normalizeLoginEmail(rawEmail);
    final user = await _authService.login(email, password);
    if (!mounted) return;

    if (user != null) {
      if (email.contains('admin')) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminScreen(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const RootScreen(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleForgotPassword() async {
    final rawEmail = _emailController.text.trim();
    if (rawEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email address to reset your password.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final email = _normalizeLoginEmail(rawEmail);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send password reset email.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Smart Home Security Monitoring\nApp',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 2,
                color: const Color(0xFF4EEF9B).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 48),
              // Shield Logo
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4EEF9B).withValues(alpha: 0.1),
                      const Color(0xFF0C100E),
                    ],
                    stops: const [0.3, 1.0],
                  ),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/shield_logo.png',
                    width: 140,
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Your Community, Always\nWatching Out',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Premium Smart Home Security Monitoring\nwith hyper-local neighborhood protection.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.mutedText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              _buildTextField(context, 'Email Address', Icons.email_outlined, _emailController),
              const SizedBox(height: 16),
              _buildTextField(context, 'Password', Icons.lock_outline, _passwordController, obscureText: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4EEF9B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF4EEF9B).withValues(alpha: 0.5),
                  ),
                  child: Text(
                    'SIGN IN',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0C100E),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _handleForgotPassword,
                    child: Text(
                      'FORGOT PASSWORD?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF4EEF9B),
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text('•', style: TextStyle(color: Color(0xFF4EEF9B))),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'CREATE ACCOUNT',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF4EEF9B),
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, String hint, IconData icon, TextEditingController controller, {bool obscureText = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fieldBg = context.secondarySurface;
    final borderColor = context.canvasBorder;
    final hintColor = context.mutedText;
    final iconColor = isDark ? Colors.white54 : Colors.black45;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: GoogleFonts.inter(color: textColor),
        decoration: InputDecoration(
          icon: Icon(icon, color: iconColor, size: 20),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: hintColor),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

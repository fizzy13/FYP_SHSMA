import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_service.dart';
import '../theme_helpers.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _normalizeEmail(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    return '$trimmed@shsma-web.firebaseapp.com';
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final rawEmail = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || rawEmail.isEmpty || phone.isEmpty || address.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnack('Please fill in all fields.');
      return;
    }

    if (password != confirmPassword) {
      _showSnack('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final email = _normalizeEmail(rawEmail);
    try {
      final user = await _authService.register(email, password, fullName, phone, address);
      if (user != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Details Saved', style: GoogleFonts.inter()),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Registration failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.secondarySurface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.canvasBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.inter(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              icon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 20),
              hintText: 'Enter $label'.toLowerCase(),
              hintStyle: GoogleFonts.inter(color: context.mutedText),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Create Account',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: textColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create your account',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your details to get started.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: context.mutedText,
                ),
              ),
              const SizedBox(height: 32),
              _buildTextField(context, 'Full Name', Icons.person_outline, _fullNameController),
              const SizedBox(height: 16),
              _buildTextField(context, 'Email Address', Icons.email_outlined, _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(context, 'Phone Number', Icons.phone_outlined, _phoneController, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _buildTextField(context, 'Address', Icons.location_on_outlined, _addressController, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(context, 'Password', Icons.lock_outline, _passwordController, obscureText: true),
              const SizedBox(height: 16),
              _buildTextField(context, 'Re-type Password', Icons.lock_outline, _confirmPasswordController, obscureText: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                    shadowColor: accent.withValues(alpha: 0.35),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                          strokeWidth: 2,
                        )
                      : Text(
                          'CREATE ACCOUNT',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark ? Colors.black : Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: GoogleFonts.inter(color: context.mutedText),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.inter(
                        color: accent,
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
}

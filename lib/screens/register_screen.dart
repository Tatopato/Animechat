import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/anime_auth_ui.dart';
import '../constants/app_motion.dart';
import '../constants/minimal_ui.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  late final TapGestureRecognizer _loginTapRecognizer;

  @override
  void initState() {
    super.initState();

    _loginTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.pushReplacement(
          context,
          animeFadeRoute(const LoginScreen()),
        );
      };
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Mi.bg,
      body: MiBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _authBrand(),
                      const SizedBox(height: 28),
                      Text('Create your account', style: Mi.title(size: 27)),
                      const SizedBox(height: 6),
                      Text(
                        'Join the community and share your anime journey.',
                        style: Mi.body(color: Mi.sub),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: Mi.card(radius: 24),
                        child: _buildFormContent(),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: Mi.body(color: Mi.sub),
                            children: [
                              TextSpan(
                                text: 'Log in',
                                style: Mi.body(
                                  color: Mi.violet,
                                  weight: FontWeight.w700,
                                ),
                                recognizer: _loginTapRecognizer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authBrand() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: Mi.brand,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          ShaderMask(
            shaderCallback: (bounds) => Mi.brand.createShader(bounds),
            child: Text(
              'Anime Chat',
              style: Mi.title(size: 25).copyWith(color: Colors.white),
            ),
          ),
        ],
      );

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _authField(
          controller: _usernameController,
          label: 'Email',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        const SizedBox(height: 16),
        _authField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_rounded,
          obscureText: _hidePassword,
          suffix: IconButton(
            tooltip: _hidePassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _hidePassword = !_hidePassword),
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Mi.sub,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a password';
            }
            if (value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _authField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outline_rounded,
          obscureText: _hideConfirmPassword,
          suffix: IconButton(
            tooltip: _hideConfirmPassword ? 'Show password' : 'Hide password',
            onPressed: () => setState(
              () => _hideConfirmPassword = !_hideConfirmPassword,
            ),
            icon: Icon(
              _hideConfirmPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Mi.sub,
            ),
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
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _register,
            style: FilledButton.styleFrom(
              backgroundColor: Mi.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox.square(
                    dimension: 21,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create account'),
          ),
        ),
        const SizedBox(height: 24),
        _socialDivider(),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialButton(
              const FaIcon(FontAwesomeIcons.google, color: Color(0xFFDB4437), size: 18),
              () => debugPrint('Google Login Clicked'),
            ),
            const SizedBox(width: 14),
            _socialButton(
              const FaIcon(FontAwesomeIcons.facebookF, color: Color(0xFF1877F2), size: 18),
              () => debugPrint('Facebook Login Clicked'),
            ),
            const SizedBox(width: 14),
            _socialButton(
              FaIcon(FontAwesomeIcons.github, color: Mi.text, size: 18),
              () => debugPrint('GitHub Login Clicked'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        style: Mi.body(color: Mi.text),
        cursorColor: Mi.accent,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Mi.violet),
          suffixIcon: suffix,
          filled: true,
          fillColor: Mi.bg,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Mi.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Mi.accent, width: 1.5),
          ),
        ),
      );

  Widget _socialDivider() => Row(children: [
        Expanded(child: Divider(color: Mi.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('Or continue with', style: Mi.caption()),
        ),
        Expanded(child: Divider(color: Mi.line)),
      ]);

  Widget _socialButton(Widget icon, VoidCallback onPressed) => SizedBox(
        width: 52,
        height: 48,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: Mi.surface,
            side: BorderSide(color: Mi.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: icon,
        ),
      );

  // ---------------------------------------------------------------------
  // Auth logic (unchanged)
  // ---------------------------------------------------------------------

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        AppMotion.route(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (_) {
      _showMessage(
          'Firebase is not configured yet. Please complete the setup steps.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return error.message ?? 'Unable to create account. Please try again.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAnimeSnackBar(context, message);
  }
}

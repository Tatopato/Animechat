import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/anime_auth_ui.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  static const List<String> _backgrounds = [
    'assets/images/rezero.jpg',
    'assets/images/slime.jpg',
    'assets/images/sao.jpg',
    'assets/images/bluelock.jpg',
  ];

  // [left, center, right]
  static const List<String> _fan = [
    'assets/images/akame.jpg',
    'assets/images/rezero.jpg',
    'assets/images/slime.jpg',
  ];

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  late final AnimationController _entryController;
  late final AnimationController _floatingController;
  late final TapGestureRecognizer _loginTapRecognizer;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

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
    _entryController.dispose();
    _floatingController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnimePalette.night,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AnimeAuthBackground(
              images: _backgrounds,
              petals: false,
            ),
          ),
          SafeArea(
            child: Center(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimeReveal(
                          parent: _entryController,
                          index: 0,
                          child: AnimePosterFan(
                            images: _fan,
                            float: _floatingController,
                          ),
                        ),
                        const SizedBox(height: 22),
                        AnimeReveal(
                          parent: _entryController,
                          index: 1,
                          child: const AnimeHeading(
                            title: 'CREATE YOUR ACCOUNT',
                            subtitle:
                                'Join the community and start your adventure',
                          ),
                        ),
                        const SizedBox(height: 24),
                        AnimeReveal(
                          parent: _entryController,
                          index: 2,
                          child: AnimeGlassCard(child: _buildFormContent()),
                        ),
                        const SizedBox(height: 24),
                        AnimeReveal(
                          parent: _entryController,
                          index: 3,
                          child: Center(
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: AnimeFonts.body(
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Login',
                                    style: AnimeFonts.body(
                                      size: 14,
                                      color: AnimePalette.sakura,
                                      weight: FontWeight.w800,
                                    ),
                                    recognizer: _loginTapRecognizer,
                                  ),
                                ],
                              ),
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
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimeTextField(
          controller: _usernameController,
          label: 'Email',
          icon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        const SizedBox(height: 16),
        AnimeTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_rounded,
          isPassword: true,
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
        AnimeTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outline_rounded,
          isPassword: true,
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
        AnimeButton(
          label: 'REGISTER',
          jpLabel: '新規登録',
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _register,
        ),
        const SizedBox(height: 24),
        const AnimeDividerLabel(text: 'Or register with'),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.google,
                  color: Colors.white, size: 20),
              color: Colors.white,
              onTap: () => debugPrint('Google Login Clicked'),
            ),
            const SizedBox(width: 20),
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.facebookF,
                  color: Color(0xFF4C8DFF), size: 20),
              color: const Color(0xFF1877F2),
              onTap: () => debugPrint('Facebook Login Clicked'),
            ),
            const SizedBox(width: 20),
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.github,
                  color: Colors.white, size: 20),
              color: Colors.white,
              onTap: () => debugPrint('GitHub Login Clicked'),
            ),
          ],
        ),
      ],
    );
  }

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
        MaterialPageRoute(builder: (_) => const MainScreen()),
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

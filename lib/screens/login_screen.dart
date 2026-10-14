import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/anime_auth_ui.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const List<String> _backgrounds = [
    'assets/images/jjk.jpg',
    'assets/images/bluelock.jpg',
    'assets/images/sao.jpg',
    'assets/images/akame.jpg',
  ];

  // [left, center, right]
  static const List<String> _fan = [
    'assets/images/bluelock.jpg',
    'assets/images/jjk.jpg',
    'assets/images/sao.jpg',
  ];

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isGoogleInitialized = false;

  late final AnimationController _entryController;
  late final AnimationController _floatingController;
  late final TapGestureRecognizer _registerTapRecognizer;

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

    _registerTapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.pushReplacement(
          context,
          animeFadeRoute(const RegisterScreen()),
        );
      };
  }

  @override
  void dispose() {
    _entryController.dispose();
    _floatingController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _registerTapRecognizer.dispose();
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
                            jp: 'おかえりなさい！  ログイン',
                            title: 'WELCOME BACK',
                            subtitle: 'Sign in to continue your anime journey',
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
                                text: "Don't have an account? ",
                                style: AnimeFonts.body(
                                  size: 14,
                                  color: Colors.white70,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Register',
                                    style: AnimeFonts.body(
                                      size: 14,
                                      color: AnimePalette.sakura,
                                      weight: FontWeight.w800,
                                    ),
                                    recognizer: _registerTapRecognizer,
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
          validator: (value) => value == null || value.isEmpty
              ? 'Please enter your password'
              : null,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isSubmitting ? null : _sendPasswordReset,
            style: TextButton.styleFrom(
              foregroundColor: AnimePalette.cyan,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: AnimeFonts.body(
                size: 13,
                color: AnimePalette.cyan,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimeButton(
          label: 'LOGIN',
          loading: _isSubmitting,
          onPressed: _isSubmitting ? null : _signIn,
        ),
        const SizedBox(height: 24),
        const AnimeDividerLabel(text: 'Or login with'),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.google,
                  color: Colors.white, size: 20),
              color: Colors.white,
              onTap: () => _startSocialSignIn(_signInWithGoogle),
            ),
            const SizedBox(width: 20),
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.facebookF,
                  color: Color(0xFF4C8DFF), size: 20),
              color: const Color(0xFF1877F2),
              onTap: () => _startSocialSignIn(_signInWithFacebook),
            ),
            const SizedBox(width: 20),
            AnimeSocialButton(
              icon: const FaIcon(FontAwesomeIcons.github,
                  color: Colors.white, size: 20),
              color: Colors.white,
              onTap: () => _startSocialSignIn(_signInWithGitHub),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Auth logic (unchanged)
  // ---------------------------------------------------------------------

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
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

  Future<void> _startSocialSignIn(
    Future<UserCredential> Function() signIn,
  ) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await signIn();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (error) {
      _showMessage('Unable to sign in: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<UserCredential> _signInWithGoogle() async {
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    }

    if (!_isGoogleInitialized) {
      await GoogleSignIn.instance.initialize();
      _isGoogleInitialized = true;
    }
    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;
    final credential =
        GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<UserCredential> _signInWithFacebook() async {
    if (kIsWeb) {
      final provider = FacebookAuthProvider()..addScope('email');
      return FirebaseAuth.instance.signInWithPopup(provider);
    }

    final result = await FacebookAuth.instance.login();
    if (result.status == LoginStatus.cancelled) {
      throw StateError('Facebook sign-in was cancelled.');
    }
    final token = result.accessToken?.tokenString;
    if (result.status != LoginStatus.success || token == null) {
      throw StateError(result.message ?? 'Facebook sign-in failed.');
    }
    return FirebaseAuth.instance.signInWithCredential(
      FacebookAuthProvider.credential(token),
    );
  }

  Future<UserCredential> _signInWithGitHub() {
    final provider = GithubAuthProvider();
    if (kIsWeb) {
      return FirebaseAuth.instance.signInWithPopup(provider);
    }
    return FirebaseAuth.instance.signInWithProvider(provider);
  }

  Future<void> _sendPasswordReset() async {
    final email = _usernameController.text.trim();
    if (_validateEmail(email) != null) {
      _showMessage('Enter your email first to reset your password.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('Password reset email sent. Please check your inbox.');
    } on FirebaseAuthException catch (error) {
      _showMessage(_authErrorMessage(error));
    } catch (_) {
      _showMessage(
          'Firebase is not configured yet. Please complete the setup steps.');
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
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Please check your internet connection.';
      default:
        return error.message ?? 'Unable to sign in. Please try again.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showAnimeSnackBar(context, message);
  }
}

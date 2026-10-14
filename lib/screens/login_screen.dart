import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/anime_auth_ui.dart';
import '../constants/app_motion.dart';
import '../constants/minimal_ui.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isGoogleInitialized = false;
  bool _hidePassword = true;
  late final TapGestureRecognizer _registerTapRecognizer;

  @override
  void initState() {
    super.initState();

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
    _usernameController.dispose();
    _passwordController.dispose();
    _registerTapRecognizer.dispose();
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
                      Text('Welcome back', style: Mi.title(size: 28)),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to continue your anime journey.',
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
                            text: "Don't have an account? ",
                            style: Mi.body(color: Mi.sub),
                            children: [
                              TextSpan(
                                text: 'Register',
                                style: Mi.body(
                                  color: Mi.violet,
                                  weight: FontWeight.w700,
                                ),
                                recognizer: _registerTapRecognizer,
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
              foregroundColor: Mi.violet,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: Mi.body(
                size: 13,
                color: Mi.violet,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _signIn,
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
                : const Text('Log in'),
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
              () => _startSocialSignIn(_signInWithGoogle),
            ),
            const SizedBox(width: 14),
            _socialButton(
              const FaIcon(FontAwesomeIcons.facebookF, color: Color(0xFF1877F2), size: 18),
              () => _startSocialSignIn(_signInWithFacebook),
            ),
            const SizedBox(width: 14),
            _socialButton(
              FaIcon(FontAwesomeIcons.github, color: Mi.text, size: 18),
              () => _startSocialSignIn(_signInWithGitHub),
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
          onPressed: _isSubmitting ? null : onPressed,
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
        AppMotion.route(builder: (_) => const MainScreen()),
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

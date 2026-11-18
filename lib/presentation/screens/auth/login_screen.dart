import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/content_width.dart';

/// Sign in / create account / continue as guest.
/// After success, AuthGate swaps this screen for the app automatically.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialSignUp = false, this.onBack});

  final bool initialSignUp;
  final VoidCallback? onBack;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late bool _isSignUp;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setMessage(String text, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      _setMessage(_authErrorMessage(error));
    } catch (_) {
      _setMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _setMessage('Enter your email address and password.');
      return;
    }
    if (!email.contains('@')) {
      _setMessage('Enter a valid email address.');
      return;
    }
    if (_isSignUp && password.length < 8) {
      _setMessage('Use a password with at least 8 characters.');
      return;
    }

    await _run(() async {
      final auth = FirebaseAuth.instance;
      if (_isSignUp) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    });
  }

  Future<void> _continueWithGoogle() async {
    await _run(() async {
      final auth = FirebaseAuth.instance;

      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider());
        return;
      }

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // person closed the Google window

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await auth.signInWithCredential(credential);
    });
  }

  Future<void> _continueAsGuest() async {
    await _run(() => FirebaseAuth.instance.signInAnonymously());
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setMessage('Type your email address above, then tap Forgot password.');
      return;
    }

    await _run(() async {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _setMessage(
        'If an account exists for $email, a reset link is on its way.',
        isError: false,
      );
    });
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'The email address or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not switched on in Firebase yet.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'The sign-in window was closed before finishing.';
      default:
        return 'Unable to continue. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar: widget.onBack == null
          ? null
          : AppBar(
              leading: IconButton(
                onPressed: _isLoading ? null : widget.onBack,
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
              ),
              shape: const Border(),
            ),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 440,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    _isSignUp ? 'Create your account' : 'Welcome back',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isSignUp
                        ? 'Your email is only used to sign in. It is never '
                            'shown next to anything you write.'
                        : 'Sign in to pick up where you left off.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _continueWithEmail(),
                    autofillHints: [
                      _isSignUp
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: _isSignUp ? 'At least 8 characters' : null,
                      suffixIcon: IconButton(
                        tooltip:
                            _obscurePassword ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    )
                  else
                    const SizedBox(height: AppSpacing.lg),
                  if (_message != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: _messageIsError
                              ? palette.dangerSoft
                              : palette.primarySoft,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                        child: Text(
                          _message!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _messageIsError
                                ? palette.danger
                                : palette.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _continueWithEmail,
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: palette.onPrimary,
                              ),
                            )
                          : Text(_isSignUp ? 'Create account' : 'Sign in'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _continueWithGoogle,
                      child: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                                _isSignUp = !_isSignUp;
                                _message = null;
                              }),
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Just looking around?',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Use HerCircle as a guest without an email address. '
                    'Guest posts are tied to this device, so signing out '
                    'means you lose access to them.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    child: const Text('Continue as guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/haptics.dart';
import '../../widgets/content_width.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/looma_button.dart';
import '../../widgets/welcome_logo.dart';
import 'login_auth.dart';
import 'sign_in_hold.dart';
import '../../../core/theme/app_icons.dart';

/// Sign in / create account (email + password, or Google).
/// After success, AuthGate swaps this screen for the app automatically.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialSignUp = false,
    this.onBack,
    this.auth = const LoginAuth(),
  });

  final bool initialSignUp;
  final VoidCallback? onBack;

  /// The sign-in calls (tests pass a fake).
  final LoginAuth auth;

  /// If a sign-in has not finished by then, the screen gives up waiting.
  static const Duration timeout = Duration(seconds: 60);

  static const String timeoutMessage =
      'Sign-in did not finish. Please try again.';

  /// On the web, after she comes back to the page from the Google window
  /// (closed it, or switched back), the screen waits this long for the
  /// sign-in to finish, then returns to normal. Safari can take up to a
  /// minute to report a closed Google window.
  static const Duration returnGrace = Duration(seconds: 2);

  /// Tests switch the web behaviour on.
  @visibleForTesting
  static bool? debugIsWeb;

  static bool get _isWeb => debugIsWeb ?? kIsWeb;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with EntranceOnce<LoginScreen>, WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late bool _isSignUp;

  /// Which button shows the success tick (null = none).
  _Method? _succeeded;

  /// Web only: ends a Google sign-in early as "cancelled" when she is back
  /// on the page and it has not finished.
  Completer<void>? _googleAbort;

  /// Web only: she left the page (the Google window opened) during this
  /// Google sign-in.
  bool _leftForGoogle = false;
  Timer? _returnCheck;
  String? _message;
  bool _messageIsError = true;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialSignUp;
    // On the web, page visibility and focus come in as lifecycle changes.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _returnCheck?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Web: the page hid or lost focus (the Google window opened), then came
  /// back. If the sign-in has not finished 2 seconds after she is back, it
  /// was cancelled: the screen returns to normal. (The 60-second timeout
  /// stays as the last safety.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!LoginScreen._isWeb || _googleAbort == null) return;
    if (state != AppLifecycleState.resumed) {
      _leftForGoogle = true;
      _returnCheck?.cancel();
      return;
    }
    if (!_leftForGoogle) return;
    _returnCheck?.cancel();
    _returnCheck = Timer(LoginScreen.returnGrace, () {
      final abort = _googleAbort;
      if (abort == null || abort.isCompleted || widget.auth.signedIn) return;
      abort.completeError(const SignInCancelled());
    });
  }

  void _setMessage(String text, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
  }

  /// Runs a sign-in / sign-up / reset action with a spinner and error text.
  /// For [signIn] actions: on success the button shows a tick for 400 ms,
  /// then AuthGate opens the app.
  ///
  /// Whatever happens (success, error, cancel, or no answer at all within
  /// [LoginScreen.timeout]) the spinner stops and the screen can be used
  /// again. A second tap while one is running is ignored.
  Future<void> _run(Future<void> Function() action, {_Method? signIn}) async {
    if (_isLoading) return; // already running: ignore the second tap
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _message = null;
    });
    // Keep this screen up after Firebase signs in, so the tick can show.
    if (signIn != null) SignInHold.active.value = true;
    try {
      // Never wait forever (e.g. a Google window that never answers).
      await action().timeout(LoginScreen.timeout);
      final signedIn = widget.auth.signedIn;
      if (signIn != null && signedIn && mounted) {
        AppHaptics.medium();
        setState(() {
          _isLoading = false;
          _succeeded = signIn;
        });
        await Future<void>.delayed(SignInHold.tickDuration);
      }
    } on SignInCancelled {
      // She cancelled: no message, just back to normal.
    } on TimeoutException {
      _setMessage(LoginScreen.timeoutMessage);
    } on FirebaseAuthException catch (error) {
      if (!LoginAuth.isCancel(error)) _setMessage(_authErrorMessage(error));
    } catch (error) {
      if (!LoginAuth.isCancel(error)) {
        _setMessage('Something went wrong. Please try again.');
      }
    } finally {
      // Always let go, whatever happened, so nobody is stuck here.
      if (signIn != null) SignInHold.active.value = false;
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

    await _run(
      () =>
          _isSignUp
              ? widget.auth.createAccount(email, password)
              : widget.auth.signInWithEmail(email, password),
      signIn: _Method.email,
    );
  }

  Future<void> _continueWithGoogle() async {
    if (!LoginScreen._isWeb) {
      return _run(widget.auth.signInWithGoogle, signIn: _Method.google);
    }
    // Web: also end it when she is back on the page and nothing happened.
    final abort = Completer<void>();
    await _run(() {
      if (_googleAbort != null) return Future<void>.value();
      _googleAbort = abort;
      _leftForGoogle = false;
      return Future.any([widget.auth.signInWithGoogle(), abort.future]);
    }, signIn: _Method.google);
    if (identical(_googleAbort, abort)) {
      _googleAbort = null;
      _returnCheck?.cancel();
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setMessage('Type your email address above, then tap Forgot password.');
      return;
    }

    await _run(() async {
      await widget.auth.sendPasswordReset(email);
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
      default:
        return 'Unable to continue. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      appBar:
          widget.onBack == null
              ? null
              : AppBar(
                leading: IconButton(
                  onPressed: _isLoading ? null : widget.onBack,
                  tooltip: 'Back',
                  icon: const Icon(AppIcons.back, size: 20),
                ),
                shape: const Border(),
              ),
      body: SafeArea(
        child: ContentWidth(
          maxWidth: 440,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The Looma logo, only when there is room.
                  WelcomeLogo(
                    animate: entrance.enabled,
                    keyboard: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  ...entrance.items([
                    Text(
                      _isSignUp ? 'Create your space' : 'Welcome back',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'We only use your email to sign you in. '
                      'It is never shown to anyone.',
                      style: theme.textTheme.bodyLarge?.copyWith(
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
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted:
                          (_) => _isLoading ? null : _continueWithEmail(),
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
                              _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                          icon: Icon(
                            _obscurePassword ? AppIcons.eye : AppIcons.eyeSlash,
                          ),
                          onPressed:
                              () => setState(
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
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                            textStyle: theme.textTheme.bodyMedium,
                          ),
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
                            color:
                                _messageIsError
                                    ? palette.dangerSoft
                                    : palette.softFill,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          child: Text(
                            _message!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  _messageIsError
                                      ? palette.danger
                                      : palette.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    LoomaButton.primary(
                      label: 'Continue',
                      loading: _isLoading,
                      success: _succeeded == _Method.email,
                      onPressed: _continueWithEmail,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text('or', style: theme.textTheme.bodySmall),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LoomaButton.outline(
                      label: 'Continue with Google',
                      success: _succeeded == _Method.google,
                      onPressed: _isLoading ? null : _continueWithGoogle,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'By continuing you agree to keep Looma kind and '
                      'respectful. Looma is a space for women.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: TextButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () => setState(() {
                                  _isSignUp = !_isSignUp;
                                  _message = null;
                                }),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign in'
                              : 'New to Looma? Create an account',
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How someone signed in, to put the success tick on the right button.
enum _Method { email, google }

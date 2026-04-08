import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/providers.dart';
import '../../core/theme/app_theme.dart';

class AuthPage extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthPage({super.key, required this.onAuthenticated});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool _isSignIn = true;
  bool _loading = false;
  String? _errorMessage;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (!_isSignIn && password != _confirmCtrl.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_isSignIn && password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      if (_isSignIn) {
        debugPrint('[Auth] signIn → email=$email');
        final res = await supabase.signIn(email: email, password: password);
        debugPrint(
          '[Auth] signIn success → user=${res.user?.id} session=${res.session?.accessToken != null}',
        );
      } else {
        debugPrint('[Auth] signUp → email=$email');
        final res = await supabase.signUp(email: email, password: password);
        debugPrint(
          '[Auth] signUp → user=${res.user?.id} session=${res.session?.accessToken != null} emailConfirmed=${res.user?.emailConfirmedAt}',
        );
        if (res.user != null && res.session == null) {
          if (mounted) _showConfirmationDialog();
          setState(() => _loading = false);
          return;
        }
      }
      if (mounted) widget.onAuthenticated();
    } on AuthException catch (e) {
      debugPrint(
        '[Auth] AuthException → code=${e.statusCode} message=${e.message}',
      );
      setState(
        () => _errorMessage = e.message.isNotEmpty
            ? e.message
            : 'Unable to sign in right now. Please try again.',
      );
    } catch (e, st) {
      debugPrint('[Auth] unexpected error → $e\n$st');
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfirmationDialog() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Check your email'),
        content: const Text(
          'We sent a confirmation link to your email address. Please verify it before signing in.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _isSignIn = true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Outlined text field with floating label (Google / Microsoft style) ────

  static const _outlineBorder = AppTheme.border;
  static const _focusBorder = AppTheme.primary;

  InputDecoration _outlinedDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 15,
        color: AppTheme.mutedForeground,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _focusBorder,
      ),
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _outlineBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _outlineBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _focusBorder, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.destructive),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // ── Logo ──────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x3010B981),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────
                  Center(
                    child: Text(
                      _isSignIn ? 'Sign in' : 'Create account',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.foreground,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isSignIn
                          ? 'Use your FitCalorie account'
                          : 'Start tracking your calories',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.mutedForeground,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Form Card ─────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => FocusScope.of(
                            context,
                          ).requestFocus(_passwordFocus),
                          decoration: _outlinedDecoration(label: 'Email'),
                        ),

                        const SizedBox(height: 24),

                        // Password
                        TextField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: _isSignIn
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: (_) => _isSignIn
                              ? _submit()
                              : FocusScope.of(
                                  context,
                                ).requestFocus(_confirmFocus),
                          decoration: _outlinedDecoration(
                            label: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: AppTheme.mutedForeground,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),

                        if (!_isSignIn) ...[
                          const SizedBox(height: 24),
                          TextField(
                            controller: _confirmCtrl,
                            focusNode: _confirmFocus,
                            obscureText: _obscureConfirm,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: _outlinedDecoration(
                              label: 'Confirm password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: AppTheme.mutedForeground,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Error
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                child: Center(
                                  child: Icon(
                                    Icons.error_outline,
                                    color: AppTheme.destructive,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppTheme.destructive,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Submit
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              padding: EdgeInsets.zero,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _isSignIn ? 'Sign in' : 'Create account',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Toggle sign in / sign up ──────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _isSignIn
                            ? "Don't have an account?"
                            : 'Already have an account?',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.mutedForeground,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignIn = !_isSignIn;
                            _errorMessage = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isSignIn ? 'Sign up' : 'Sign in',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_auth_layout.dart';
import '../widgets/karipa_button.dart';
import '../widgets/karipa_feedback.dart';

enum _RecoveryStep { email, code, password, complete }

/// The reset authorization lives only in this route's state, never in storage
/// or navigation arguments. Account verification keeps its existing route.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key});

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _RecoveryStep _step = _RecoveryStep.email;
  bool _busy = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;
  String? _notice;
  String? _challengeId;
  String? _authorization;
  DateTime? _resendAt;
  DateTime? _expiresAt;
  DateTime? _resetExpiresAt;
  Timer? _timer;

  int get _resendSeconds => _remaining(_resendAt);
  int _remaining(DateTime? deadline) => deadline == null
      ? 0
      : (deadline.difference(DateTime.now()).inMilliseconds / 1000)
          .ceil()
          .clamp(0, 3600);

  String get _maskedEmail {
    final parts = _email.text.trim().split('@');
    if (parts.length != 2 || parts.first.isEmpty) return 'your email address';
    return '${parts.first.characters.first}•••@${parts.last}';
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _startAgain() {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = _RecoveryStep.email;
      _error = null;
      _notice = null;
      _authorization = null;
      _challengeId = null;
      _resendAt = null;
      _code.clear();
      _password.clear();
      _confirmation.clear();
    });
    _timer?.cancel();
  }

  Future<void> _submit({bool resend = false}) async {
    if (_busy || _step == _RecoveryStep.complete) return;
    if (resend && (_step != _RecoveryStep.code || _resendSeconds > 0)) return;
    if (!resend &&
        ((_step == _RecoveryStep.email && _resendSeconds > 0) ||
            (_step == _RecoveryStep.code && _remaining(_expiresAt) == 0) ||
            (_step == _RecoveryStep.password &&
                _remaining(_resetExpiresAt) == 0))) {
      return;
    }
    if (!resend && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final operation = resend
        ? 'resend'
        : switch (_step) {
            _RecoveryStep.email => 'request',
            _RecoveryStep.code => 'verify',
            _RecoveryStep.password => 'reset',
            _RecoveryStep.complete => throw StateError('Recovery is complete'),
          };
    final payload = switch (operation) {
      'request' || 'resend' => {'email': _email.text.trim()},
      'verify' => {'challengeId': _challengeId!, 'otp': _code.text.trim()},
      _ => {
          'challengeId': _challengeId!,
          'authorization': _authorization!,
          'password': _password.text
        },
    };
    final result =
        await context.read<AuthService>().recoverPassword(operation, payload);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result['success'] != true) {
        _error = result['message'] as String? ??
            'Something went wrong. Please try again.';
        final retryAfter = result['retryAfter'];
        if (retryAfter is num &&
            (operation == 'request' || operation == 'resend')) {
          _resendAt = DateTime.now().add(Duration(seconds: retryAfter.toInt()));
          _startTimer();
        }
        return;
      }
      if (operation == 'request' || operation == 'resend') {
        _challengeId = result['challengeId'] as String;
        _resendAt = DateTime.now()
            .add(Duration(seconds: (result['resendAfter'] as num).toInt()));
        _expiresAt = DateTime.now()
            .add(Duration(seconds: (result['expiresIn'] as num).toInt()));
        _step = _RecoveryStep.code;
        _code.clear();
        _notice =
            resend ? 'A replacement code was sent. Use the newest code.' : null;
        _startTimer();
      } else if (operation == 'verify') {
        _authorization = result['authorization'] as String;
        _resetExpiresAt = DateTime.now()
            .add(Duration(seconds: (result['expiresIn'] as num).toInt()));
        _code.clear();
        _step = _RecoveryStep.password;
      } else {
        _step = _RecoveryStep.complete;
        _authorization = null;
        _password.clear();
        _confirmation.clear();
        _timer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (_step) {
      _RecoveryStep.email => 'Forgot password?',
      _RecoveryStep.code => 'Check your inbox',
      _RecoveryStep.password => 'Create a new password',
      _RecoveryStep.complete => 'Password updated',
    };
    final codeExpired = _remaining(_expiresAt) == 0;
    final resetExpired = _remaining(_resetExpiresAt) == 0;
    return PopScope(
      canPop: _busy ||
          _step == _RecoveryStep.email ||
          _step == _RecoveryStep.complete,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _startAgain();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account recovery'),
          leading:
              _step == _RecoveryStep.code || _step == _RecoveryStep.password
                  ? IconButton(
                      tooltip: 'Back to email',
                      onPressed: _busy ? null : _startAgain,
                      icon: const Icon(Icons.arrow_back))
                  : null,
        ),
        body: KaripaAuthLayout(
          child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                      header: true,
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                      switch (_step) {
                        _RecoveryStep.email =>
                          'Enter your account email to request a password reset code.',
                        _RecoveryStep.code =>
                          'If an account matches $_maskedEmail, you can use the six-digit code to reset its password. Check your spam folder too.',
                        _RecoveryStep.password =>
                          'Choose a password of at least 8 characters. You have 5 minutes to complete this step.',
                        _RecoveryStep.complete =>
                          'Your password has been reset. Sign in with your new password. Existing sessions have been signed out.',
                      },
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xl),
                  if (_error != null || _notice != null) ...[
                    Semantics(
                        liveRegion: true,
                        child: KaripaFeedback(
                          title:
                              _error != null ? 'Please try again' : 'Code sent',
                          message: _error ?? _notice!,
                          kind: _error != null
                              ? FeedbackKind.error
                              : FeedbackKind.success,
                        )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (_step == _RecoveryStep.email) ...[
                    TextFormField(
                      key: const ValueKey('recovery-email'),
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'alex@example.com',
                          prefixIcon: Icon(Icons.email_outlined)),
                      validator: (value) => value == null ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(value.trim())
                          ? 'Enter a valid email address.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    KaripaButton(
                        label: _busy ? 'Sending code…' : 'Send reset code',
                        isLoading: _busy,
                        onPressed: _resendSeconds > 0 ? null : () => _submit()),
                    if (_resendSeconds > 0)
                      Text('Try again in $_resendSeconds seconds',
                          textAlign: TextAlign.center),
                  ],
                  if (_step == _RecoveryStep.code) ...[
                    TextFormField(
                      key: const ValueKey('recovery-code'),
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6)
                      ],
                      onFieldSubmitted: (_) => _submit(),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(letterSpacing: 4),
                      decoration: const InputDecoration(
                          labelText: 'Six-digit code', hintText: '000000'),
                      validator: (value) =>
                          value?.length != 6 ? 'Enter all six digits.' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                        codeExpired
                            ? 'This code has expired. Request a new code below.'
                            : 'Code expires in ${_remaining(_expiresAt) ~/ 60}:${(_remaining(_expiresAt) % 60).toString().padLeft(2, '0')}. Up to 5 attempts.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xl),
                    KaripaButton(
                        label: _busy ? 'Please wait…' : 'Verify code',
                        isLoading: _busy,
                        onPressed: codeExpired ? null : () => _submit()),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                        onPressed: _busy || _resendSeconds > 0
                            ? null
                            : () => _submit(resend: true),
                        child: Text(_resendSeconds > 0
                            ? 'Resend code in $_resendSeconds seconds'
                            : 'Resend code')),
                    TextButton(
                        onPressed: _busy ? null : _startAgain,
                        child: const Text('Use a different email')),
                  ],
                  if (_step == _RecoveryStep.password) ...[
                    _passwordField(
                        controller: _password,
                        label: 'New password',
                        hidden: _hidePassword,
                        toggle: () =>
                            setState(() => _hidePassword = !_hidePassword),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters.'
                            : utf8.encode(value).length > 72
                                ? 'This password is too long. Try a shorter password.'
                                : null,
                        action: TextInputAction.next),
                    const SizedBox(height: AppSpacing.lg),
                    _passwordField(
                        controller: _confirmation,
                        label: 'Confirm new password',
                        hidden: _hideConfirmation,
                        toggle: () => setState(
                            () => _hideConfirmation = !_hideConfirmation),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Confirm your new password.'
                            : value != _password.text
                                ? 'Passwords do not match.'
                                : null,
                        action: TextInputAction.done),
                    if (resetExpired) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                          liveRegion: true,
                          child: const Text(
                              'Your reset session has expired. Start again to request a new code.')),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    KaripaButton(
                        label: _busy ? 'Updating password…' : 'Reset password',
                        isLoading: _busy,
                        onPressed: resetExpired ? null : () => _submit()),
                    TextButton(
                        onPressed: _busy ? null : _startAgain,
                        child: const Text('Start again')),
                  ],
                  if (_step == _RecoveryStep.complete) ...[
                    const Icon(Icons.check_circle_outline,
                        size: 48, semanticLabel: 'Password reset successful'),
                    const SizedBox(height: AppSpacing.xl),
                    KaripaButton(
                        label: 'Back to sign in',
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false)),
                  ],
                  if (_step == _RecoveryStep.email) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Back to sign in')),
                  ],
                ]),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
          {required TextEditingController controller,
          required String label,
          required bool hidden,
          required VoidCallback toggle,
          required FormFieldValidator<String> validator,
          required TextInputAction action}) =>
      TextFormField(
        key: ValueKey(label),
        controller: controller,
        obscureText: hidden,
        enabled: !_busy,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: action,
        onFieldSubmitted:
            action == TextInputAction.done ? (_) => _submit() : null,
        validator: validator,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
                onPressed: _busy ? null : toggle,
                tooltip: '${hidden ? 'Show' : 'Hide'} ${label.toLowerCase()}',
                icon: Icon(hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined))),
      );
}

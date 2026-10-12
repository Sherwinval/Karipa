import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_auth_layout.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit verification code.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.verifyOtp(widget.email, otp);

    if (!mounted) return;

    if (result['success']) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'];
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.resendOtp(widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (result['success']) {
        _successMessage = 'A new verification code has been sent.';
      } else {
        _errorMessage = result['message'];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: KaripaAuthLayout(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Check your inbox',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            Text(
              'Enter the verification code sent to\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Text(
                  _errorMessage!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Text(
                  _successMessage!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center,
                ),
              ),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, letterSpacing: 2, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Verification code',
                counterText: '',
                hintText: '000000',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: KaripaPalette.coral,
                foregroundColor: KaripaPalette.midnight,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: KaripaPalette.midnight, strokeWidth: 2),
                    )
                  : const Text('Verify', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending ? null : _resendOtp,
              child: _isResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend Code'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
              child: Text('Change Email',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

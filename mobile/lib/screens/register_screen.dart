import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_auth_layout.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/unit_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final units = context.read<UnitPreferences>();
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());

    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.register(
      name,
      email,
      password,
      heightCm: height == null ? null : units.heightToCm(height),
      weightKg: weight == null ? null : units.weightToKg(weight),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Navigator.pushReplacementNamed(
        context,
        '/otp',
        arguments: {'email': email},
      );
    } else {
      setState(() {
        _errorMessage =
            result['message'] ?? 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = context.watch<UnitPreferences>();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Create Account',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: KaripaAuthLayout(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Karipa',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Generate tailored outdoor routes and track your fitness progress.',
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Optional Measurements',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These measurements are optional. Weight supports provisional gross session calorie estimates using published MET examples; adviser review is pending. Height is not used in the current calorie equation. Route planning and activity tracking work without them.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => _validateOptionalMeasurement(
                        value,
                        unit: units.heightUnit,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Height (${units.heightUnit})',
                        suffixText: units.heightUnit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _weightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) => _validateOptionalMeasurement(
                        value,
                        unit: units.weightUnit,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Weight (${units.weightUnit})',
                        suffixText: units.weightUnit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              if (_errorMessage != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // Name
              TextFormField(
                controller: _nameController,
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Full name is required';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Alex Santos',
                  prefixIcon: Icon(Icons.person_outline,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.'))
                    return 'Enter a valid email address';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'alex@example.com',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 8)
                    return 'Password must be at least 8 characters';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline,
                      color: Theme.of(context).colorScheme.onSurface),
                  suffixIcon: IconButton(
                    tooltip: 'Show or hide password',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                validator: (v) {
                  if (v == null || v.isEmpty)
                    return 'Confirm password is required';
                  if (v != _passwordController.text)
                    return 'Passwords do not match';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline,
                      color: Theme.of(context).colorScheme.onSurface),
                  suffixIcon: IconButton(
                    tooltip: 'Show or hide password',
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KaripaPalette.coral,
                  foregroundColor: KaripaPalette.midnight,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: KaripaPalette.midnight, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Register',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),

              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Already have an account?',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Sign in',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold),
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

  String? _validateOptionalMeasurement(
    String? value, {
    required String unit,
  }) {
    if (value == null || value.trim().isEmpty) return null;
    final measurement = double.tryParse(value.trim());
    if (measurement == null || !measurement.isFinite) {
      return 'Enter a valid number in $unit.';
    }
    if (measurement <= 0) {
      return 'Enter a positive value in $unit.';
    }
    return null;
  }
}

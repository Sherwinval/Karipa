import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../widgets/karipa_logo.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isAuthenticated || auth.isGuest) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KaripaPalette.navy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - AppSpacing.xxl * 1.5)
                    .clamp(0.0, double.infinity),
              ),
              child: Center(
                child: FadeTransition(
                  opacity: MediaQuery.disableAnimationsOf(context)
                      ? const AlwaysStoppedAnimation<double>(1)
                      : _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KaripaLogo(width: 280),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Smart Route Generation & Tracking',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: KaripaPalette.white,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          color: KaripaPalette.orange,
                          strokeWidth: 2.5,
                          semanticsLabel: 'Loading Karipa',
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
}

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'karipa_logo.dart';

/// Shared presentation shell; screens retain their forms and callbacks.
class KaripaAuthLayout extends StatelessWidget {
  const KaripaAuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: KaripaPalette.navy,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: const Center(
                    child: KaripaLogo(
                        width: 240, horizontal: true, blendBackground: true),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Theme(
                  data: theme.copyWith(
                    inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                      fillColor: theme.colorScheme.surfaceContainer,
                    ),
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

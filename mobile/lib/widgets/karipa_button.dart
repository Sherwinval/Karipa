import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Presentation only: the caller owns async work and the loading state.
class KaripaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool _secondary;

  const KaripaButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.isLoading = false})
      : _secondary = false;

  const KaripaButton.secondary(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.isLoading = false})
      : _secondary = true;

  @override
  Widget build(BuildContext context) {
    final child = Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (isLoading)
          const Icon(Icons.hourglass_top, size: AppSizes.compactIcon)
        else if (icon != null)
          Icon(icon, size: AppSizes.compactIcon),
        Text(label, textAlign: TextAlign.center),
      ],
    );
    return Semantics(
      value: isLoading ? 'In progress' : null,
      child: _secondary
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed, child: child)
          : FilledButton(onPressed: isLoading ? null : onPressed, child: child),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class ActivityConfirmationDialog extends StatelessWidget {
  const ActivityConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    const inset = EdgeInsets.all(AppSpacing.lg);
    const contentPadding = EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xl,
    );
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth = (constraints.maxWidth -
              MediaQuery.viewInsetsOf(context).horizontal -
              inset.horizontal -
              contentPadding.horizontal)
          .clamp(0.0, 360.0);
      return AlertDialog(
        scrollable: true,
        insetPadding: inset,
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.sm,
        ),
        contentPadding: contentPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(title),
        content: SizedBox(
          width: contentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: AppSpacing.xl),
              _buildActions(context, contentWidth),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildActions(BuildContext context, double contentWidth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const buttonPadding = EdgeInsets.all(AppSpacing.md);
    const buttonSize = Size.square(AppSizes.touchTarget);
    final labelStyle = theme.textTheme.labelLarge;
    final labelWidth =
        (contentWidth - AppSpacing.sm) / 2 - buttonPadding.horizontal;
    final rowFits = [cancelLabel, confirmLabel].every((label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width <= labelWidth;
      painter.dispose();
      return fits;
    });
    final cancel = TextButton(
      onPressed: () => Navigator.pop(context, false),
      style: TextButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: labelStyle,
      ),
      child: Text(cancelLabel, textAlign: TextAlign.center),
    );
    final confirm = FilledButton(
      onPressed: () => Navigator.pop(context, true),
      style: FilledButton.styleFrom(
        minimumSize: buttonSize,
        padding: buttonPadding,
        textStyle: labelStyle,
        backgroundColor: destructive ? scheme.error : null,
        foregroundColor: destructive ? scheme.onError : null,
      ),
      child: Text(confirmLabel, textAlign: TextAlign.center),
    );
    if (rowFits) {
      return Row(children: [
        Expanded(child: cancel),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: confirm),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cancel,
        const SizedBox(height: AppSpacing.sm),
        confirm,
      ],
    );
  }
}

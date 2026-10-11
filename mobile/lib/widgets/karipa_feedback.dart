import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'karipa_button.dart';
import 'section_heading.dart';

enum FeedbackKind { information, success, warning, error, empty }

class KaripaFeedback extends StatelessWidget {
  final String title;
  final String message;
  final FeedbackKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KaripaFeedback(
      {super.key,
      required this.title,
      required this.message,
      this.kind = FeedbackKind.information,
      this.actionLabel,
      this.onAction})
      : assert((actionLabel == null) == (onAction == null));

  IconData get _icon => switch (kind) {
        FeedbackKind.information => Icons.info_outline,
        FeedbackKind.success => Icons.check_circle_outline,
        FeedbackKind.warning => Icons.warning_amber_outlined,
        FeedbackKind.error => Icons.error_outline,
        FeedbackKind.empty => Icons.explore_outlined,
      };

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, semanticLabel: kind.name),
              const SizedBox(height: AppSpacing.md),
              SectionHeading(title: title, subtitle: message),
              if (onAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                KaripaButton.secondary(
                    label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      );
}

/// Null value means an indeterminate operation; the caller supplies real status.
class KaripaProgress extends StatelessWidget {
  final String label;
  final double? value;

  const KaripaProgress({super.key, required this.label, this.value})
      : assert(value == null || (value >= 0 && value <= 1));

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        if (reduceMotion && value == null)
          const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(Icons.hourglass_top, semanticLabel: 'In progress'))
        else
          LinearProgressIndicator(
              value: value, semanticsLabel: label, minHeight: AppSpacing.sm),
      ],
    );
  }
}

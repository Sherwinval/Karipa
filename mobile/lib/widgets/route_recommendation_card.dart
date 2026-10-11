import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'karipa_button.dart';
import 'status_badge.dart';

/// Formatted values and map preview come from the existing screen. No model,
/// recommendation calculation, service call, or navigation is owned here.
class RouteRecommendationCard extends StatelessWidget {
  final String title;
  final String distanceLabel;
  final String estimatedDurationLabel;
  final String suitabilityLabel;
  final String explanation;
  final bool recommended;
  final Widget? mapPreview;
  final VoidCallback? onPressed;

  const RouteRecommendationCard(
      {super.key,
      required this.title,
      required this.distanceLabel,
      required this.estimatedDurationLabel,
      required this.suitabilityLabel,
      required this.explanation,
      required this.onPressed,
      this.recommended = false,
      this.mapPreview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (recommended) ...[
              const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: StatusBadge(
                      text: 'Recommended',
                      icon: Icons.star_outline,
                      color: KaripaPalette.coral)),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.lg, runSpacing: AppSpacing.sm, children: [
              Text(distanceLabel, style: theme.textTheme.titleMedium),
              Text('Est. time: $estimatedDurationLabel',
                  style: theme.textTheme.bodyMedium),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text('Suitability: $suitabilityLabel',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(explanation, style: theme.textTheme.bodyMedium),
            if (mapPreview != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  child: mapPreview!),
            ],
            const SizedBox(height: AppSpacing.lg),
            KaripaButton(
                label: 'View route details',
                icon: Icons.arrow_forward,
                onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}

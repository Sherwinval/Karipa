import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
              header: true,
              child: Text(title,
                  style: Theme.of(context).textTheme.headlineSmall)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      );
}

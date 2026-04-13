import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';

class SectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SectionCard({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(title!, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.55),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/category.dart';

/// Category shown as small coloured text (not a big coloured pill).
class CategoryLabel extends StatelessWidget {
  const CategoryLabel({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final name = AppCategories.fromId(categoryId)?.shortName ?? 'Community';

    return Text(
      name.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.palette.categoryColor(categoryId),
        letterSpacing: 0.8,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/category.dart';

/// The category as a small pill in its soft colour: Health sage,
/// Education sand, Career blush, Safety lavender.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final name = AppCategories.fromId(categoryId)?.shortName ?? 'Community';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.categoryFill(categoryId),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: palette.text,
        ),
      ),
    );
  }
}

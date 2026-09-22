import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.isAnonymous,
    this.displayName,
    this.size = 42,
  });

  final bool isAnonymous;
  final String? displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = _getInitial();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isAnonymous
            ? Icon(
                Icons.person_outline_rounded,
                size: size * 0.52,
                color: AppColors.primary,
              )
            : Text(
                initial,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.primary,
                  fontSize: size * 0.38,
                ),
              ),
      ),
    );
  }

  String _getInitial() {
    if (displayName == null || displayName!.trim().isEmpty) {
      return '?';
    }

    return displayName!.trim()[0].toUpperCase();
  }
}
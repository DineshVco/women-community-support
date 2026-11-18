import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(AppPalette.light, Brightness.light);
  static final ThemeData dark = _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final text = AppTypography.textTheme(p);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.softFill,
      onPrimaryContainer: p.text,
      secondary: p.accent,
      onSecondary: p.onPrimary,
      secondaryContainer: p.softFill,
      onSecondaryContainer: p.text,
      error: p.danger,
      onError: isLight ? Colors.white : const Color(0xFF3A100A),
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border,
    );

    // Buttons are fully round. Screens make their main buttons full width.
    const pill = StadiumBorder();
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final buttonText = text.labelLarge!;

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      // iPhone-style slide (with swipe-back) on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CupertinoUnlessReducedMotion(),
          TargetPlatform.iOS: _CupertinoUnlessReducedMotion(),
          TargetPlatform.macOS: _CupertinoUnlessReducedMotion(),
          TargetPlatform.windows: _CupertinoUnlessReducedMotion(),
          TargetPlatform.linux: _CupertinoUnlessReducedMotion(),
          TargetPlatform.fuchsia: _CupertinoUnlessReducedMotion(),
        },
      ),
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      textTheme: text,
      // Quiet press feedback, no coloured ripple.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: p.text.withValues(alpha: 0.05),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        shape: Border(bottom: BorderSide(color: p.border)),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: text.bodyLarge!.copyWith(color: p.textMuted),
        labelStyle: text.bodyLarge!.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.bodyMedium!.copyWith(color: p.text),
        errorStyle: text.bodySmall!.copyWith(color: p.danger),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        focusedBorder: inputBorder(p.borderStrong, 1.8),
        errorBorder: inputBorder(p.danger),
        focusedErrorBorder: inputBorder(p.danger, 1.8),
        disabledBorder: inputBorder(p.border),
      ),
      // Primary: black fill, white text, 56 high, fully round.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pill,
          elevation: 0,
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.border,
          disabledForegroundColor: p.textMuted,
          textStyle: buttonText,
        ),
      ),
      // Outline: 1.5 px border, no fill, 52 high, fully round.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.outlineButtonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pill,
          foregroundColor: p.text,
          side: BorderSide(color: p.borderStrong, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: pill,
          foregroundColor: p.text,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: pill,
          foregroundColor: p.text,
          selectedBackgroundColor: p.primary,
          selectedForegroundColor: p.onPrimary,
          side: BorderSide(color: p.border),
          textStyle: text.labelMedium!.copyWith(fontSize: 15),
        ),
      ),
      // Category chips: pill, selected = black fill with white text.
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? p.primary : p.surface,
        ),
        labelStyle: text.labelMedium!.copyWith(
          fontSize: 14,
          color: WidgetStateColor.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? p.onPrimary : p.text,
          ),
        ),
        checkmarkColor: p.onPrimary,
        side: WidgetStateBorderSide.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? BorderSide(color: p.primary)
                  : BorderSide(color: p.border),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        elevation: 0,
        pressElevation: 0,
      ),
      // Bottom bar: selected black, others grey, no indicator blob.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium!.copyWith(
            fontSize: 12,
            color: selected ? p.text : p.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? p.text : p.textSecondary,
          );
        }),
      ),
      // Write a post: black pill.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: pill,
        extendedTextStyle: buttonText,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: text.bodyMedium!.copyWith(color: p.background),
        actionTextColor: p.background,
        elevation: 0,
        shape: rounded,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: p.border),
        ),
        textStyle: text.bodyLarge,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
      ),
    );
  }
}

/// The iOS page slide (with edge swipe-back) everywhere, except when the
/// person has asked their phone to reduce motion: then pages just appear.
class _CupertinoUnlessReducedMotion extends PageTransitionsBuilder {
  const _CupertinoUnlessReducedMotion();

  static const _cupertino = CupertinoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _cupertino.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

import 'package:flutter/material.dart';

// Shared additions to the app's Material theme; widgets read colors and type
// through Theme.of(context), including on editor routes and overlays.
abstract final class AppSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24;
  static const double section = 32, empty = 40;
}

abstract final class AppShape {
  static const double radius = 20;
  static const double elevation = 0;
  static const borderRadius = BorderRadius.all(Radius.circular(radius));
}

abstract final class AppLayout {
  static const double authWidth = 440, editorWidth = 650, contentWidth = 960;
  static const double metricBreakpoint = 480, actionClearance = 112;
  static const double chartValueWidth = 128, chartHeight = 8;
  static const double controlSize = 48, iconSize = 24, emptyIconSize = 56;
}

// Readable foreground for category swatches supplied by the user.
Color contentOn(Color background) =>
    background.computeLuminance() > 0.179 ? Colors.black : Colors.white;

ThemeData expenseTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFBEF264),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFBEF264),
        onPrimary: const Color(0xFF142008),
        primaryContainer: const Color(0xFF2D4320),
        onPrimaryContainer: const Color(0xFFD9F99D),
        secondary: const Color(0xFFFF91A4),
        onSecondary: const Color(0xFF390D1B),
        secondaryContainer: const Color(0xFF38202C),
        onSecondaryContainer: const Color(0xFFFFBBC7),
        tertiary: const Color(0xFF91DFC2),
        onTertiary: const Color(0xFF07382A),
        surface: const Color(0xFF111827),
        onSurface: const Color(0xFFF3F6FC),
        onSurfaceVariant: const Color(0xFFB6C2D5),
        surfaceContainerLowest: const Color(0xFF1C273A),
        surfaceContainerLow: const Color(0xFF172133),
        surfaceContainerHighest: const Color(0xFF2B3950),
        outline: const Color(0xFF7F90AA),
        outlineVariant: const Color(0xFF344259),
        error: const Color(0xFFFFA4AC),
        onError: const Color(0xFF520D20),
      );
  const focus = Color(0xFF507BD2);
  const shape = RoundedRectangleBorder(borderRadius: AppShape.borderRadius);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final type = base.textTheme
      .copyWith(
        headlineLarge: const TextStyle(
          fontSize: 36,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineMedium: const TextStyle(
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        titleLarge: const TextStyle(
          fontSize: 24,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: const TextStyle(
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 16, height: 1.5),
        bodySmall: const TextStyle(fontSize: 13, height: 1.5),
        labelSmall: const TextStyle(
          fontSize: 12,
          height: 1.5,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
        ),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(AppLayout.controlSize, AppLayout.controlSize),
    ),
    shape: const WidgetStatePropertyAll(shape),
    elevation: const WidgetStatePropertyAll(AppShape.elevation),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(color: focus, width: 3)
          : null,
    ),
  );
  return base.copyWith(
    textTheme: type,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    focusColor: focus.withValues(alpha: 0.2),
    hoverColor: scheme.primary.withValues(alpha: 0.06),
    highlightColor: scheme.primary.withValues(alpha: 0.12),
    disabledColor: scheme.onSurface.withValues(alpha: 0.38),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      scrolledUnderElevation: AppShape.elevation,
      centerTitle: false,
      titleTextStyle: type.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
      border: const OutlineInputBorder(borderRadius: AppShape.borderRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShape.borderRadius,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppShape.borderRadius,
        borderSide: BorderSide(color: focus, width: 3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShape.borderRadius,
        borderSide: BorderSide(color: scheme.error, width: 3),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      margin: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.borderRadius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button),
    textButtonTheme: TextButtonThemeData(style: button),
    iconButtonTheme: IconButtonThemeData(style: button),
    segmentedButtonTheme: SegmentedButtonThemeData(style: button),
    chipTheme: base.chipTheme.copyWith(
      shape: shape,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(color: scheme.outline),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: const StadiumBorder(),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: AppShape.elevation,
      focusElevation: AppShape.elevation,
      hoverElevation: AppShape.elevation,
      highlightElevation: AppShape.elevation,
      focusColor: focus,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => type.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: shape,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: shape,
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearTrackColor: scheme.surfaceContainerHighest,
      color: scheme.primary,
      borderRadius: AppShape.borderRadius,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.error,
      contentTextStyle: type.bodyMedium?.copyWith(color: scheme.onError),
      shape: shape,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}

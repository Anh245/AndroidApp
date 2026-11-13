import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double section = 32;
  static const double empty = 40;
}

abstract final class AppShape {
  static const double radius = 20;
  static const double elevation = 0;

  static const borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );

  static const inputRadius = BorderRadius.all(
    Radius.circular(14),
  );
}

abstract final class AppLayout {
  static const double authWidth = 440;
  static const double editorWidth = 650;
  static const double contentWidth = 960;
  static const double metricBreakpoint = 480;
  static const double actionClearance = 112;
  static const double chartValueWidth = 128;
  static const double chartHeight = 8;
  static const double controlSize = 48;
  static const double iconSize = 24;
  static const double emptyIconSize = 56;
}

Color contentOn(Color background) =>
    background.computeLuminance() > 0.179
        ? Colors.black
        : Colors.white;

ThemeData expenseTheme() {
  final scheme = ColorScheme.fromSeed(
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
    surface: const Color(0xFF101418),
    onSurface: const Color(0xFFF2F5F3),
    onSurfaceVariant: const Color(0xFFA9B4AF),
    surfaceContainerLowest: const Color(0xFF19211D),
    surfaceContainerLow: const Color(0xFF151C18),
    surfaceContainerHighest: const Color(0xFF29382F),
    outline: const Color(0xFF64756B),
    outlineVariant: const Color(0xFF303E35),
    error: const Color(0xFFFFA4AC),
    onError: const Color(0xFF520D20),
  );

  const focus = Color(0xFF507BD2);

  const shape = RoundedRectangleBorder(
    borderRadius: AppShape.borderRadius,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
  );

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
      height: 1.3,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleMedium: const TextStyle(
      fontSize: 18,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      height: 1.5,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      height: 1.5,
    ),
    bodySmall: const TextStyle(
      fontSize: 13,
      height: 1.5,
    ),
    labelSmall: const TextStyle(
      fontSize: 12,
      height: 1.4,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
    ),
  )
      .apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(
        AppLayout.controlSize,
        AppLayout.controlSize,
      ),
    ),
    shape: const WidgetStatePropertyAll(shape),
    elevation: const WidgetStatePropertyAll(
      AppShape.elevation,
    ),
    side: WidgetStateProperty.resolveWith<BorderSide?>(
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

    // Thanh tiêu đề.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      scrolledUnderElevation: AppShape.elevation,
      centerTitle: false,
      titleTextStyle: type.titleLarge,
    ),

    // Ô nhập liệu: bo góc 14.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.all(AppSpace.lg),
      border: const OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
        borderSide: BorderSide(
          color: scheme.outlineVariant,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
        borderSide: BorderSide(
          color: focus,
          width: 3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
        borderSide: BorderSide(
          color: scheme.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
        borderSide: BorderSide(
          color: scheme.error,
          width: 3,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppShape.inputRadius,
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      errorMaxLines: 3,
      helperMaxLines: 3,
    ),

    // Thẻ nội dung: bo góc 20.
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      margin: const EdgeInsets.symmetric(
        vertical: AppSpace.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.borderRadius,
        side: BorderSide(
          color: scheme.outlineVariant,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: button,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button,
    ),
    textButtonTheme: TextButtonThemeData(
      style: button,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: button,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: button,
    ),

    chipTheme: base.chipTheme.copyWith(
      shape: shape,
      selectedColor: scheme.primaryContainer,
      side: BorderSide(
        color: scheme.outline,
      ),
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

    // Thanh điều hướng phía dưới.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: AppShape.elevation,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
            (states) => type.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
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
      contentTextStyle: type.bodyMedium?.copyWith(
        color: scheme.onError,
      ),
      shape: shape,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
    ),
  );
}
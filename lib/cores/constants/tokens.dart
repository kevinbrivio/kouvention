// lib/cores/constants/tokens.dart
//
// Single source of truth for all design tokens.
// 6 layers: Brand → Surface (Light/Dark) → Shadows → Spacing/Sizing/Radius → Text → ThemeData.
//
// Usage:
//   Colors:    Theme.of(context).colorScheme.primary  (preferred)
//              AppColorTokens.primary                  (only when no scheme equivalent)
//   Text:      context.text.bodyMedium
//   Spacing:   AppSpacing.md.w
//   Sizing:    AppSizing.buttonHeight.h
//   Radius:    AppRadius.button.r
//   Theme:     theme: AppTheme.light, darkTheme: AppTheme.dark

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 1: AppColorTokens — Brand + Functional
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// DO NOT use these directly in widgets. Use Theme.of(context).colorScheme.xxx.
// These are raw VALUES, only consumed by AppTheme constructors.
class AppColorTokens {
  AppColorTokens._();

  // Brand
  static const Color primary = Color(0xFF0FBA39);
  static const Color primaryLighter = Color(0xFFADFFB0); // dark mode variant
  static const Color primaryDark = Color(0xFF02410E); // blue (legacy, min use)
  static const Color secondary = Color(0xFFEF17BA); // orange (legacy, min use)

  // Functional
  static const Color error = Color(0xFFFF0033);
  static const Color success = Color(0xFF0FBA39);
  static const Color warning = Color(0xFFFF8040);
  static const Color info = Color(0xFFE7FDED);
  static const Color disabled = Color(0xFFB3B3B3);
  static const Color disabledText = Color(0xFF8C8C8C);

  // Avatar / sender identifier color palette
  static const List<Color> _senderNameColors = [
    Color(0xFF0FBA39), // green
    Color(0xFF4490ED), // blue
    Color(0xFFFF8040), // orange
    Color(0xFFFF0033), // red
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
    Color(0xFF795548), // brown
  ];

  /// Deterministic color for a sender, used as avatar tint / sender name accent.
  static Color senderNameColor(String senderId) {
    final index = senderId.hashCode.abs() % _senderNameColors.length;
    return _senderNameColors[index];
  }

  // Form / search bar surface tints (for compatibility with legacy code)
  static const Color formField = Colors.white38;
  static const Color searchBar = Color(0xFFF5F5F0);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 2a: AppSurfaceLight — 5 tonal layers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// No pure white (#FFFFFF) below surfaces layer (use only for overlays).
class AppSurfaceLight {
  AppSurfaceLight._();

  /// Scaffold / page background
  static const Color background = Color(0xFFF5F5F5);

  /// Surface containers (cards, list items, dialogs)
  static const Color surface = Color(0xFFFAFAFA);

  /// Elevated surfaces (sheets, menus)
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Input fields, search bars
  static const Color surfaceInput = Color(0xFFF5F5F0);

  /// Other-user message bubble
  static const Color surfaceBubbleReceived = Color(0xFFF5F5F0);

  /// Navigation bars, app bars
  static const Color surfaceBar = Color(0xFFF3F3F3);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 2b: AppSurfaceDark — 5 tonal layers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Base: #121212. Never use #000000 or #FFFFFF as layer colors.
// Each layer steps up in luminance from the base.
class AppSurfaceDark {
  AppSurfaceDark._();

  /// Scaffold / page background      — base layer (0dp elevation)
  static const Color background = Color(0xFF121212);

  /// Surface containers (cards)      — 1dp elevation equivalent
  static const Color surface = Color(0xFF1E1E1E);

  /// Elevated surfaces (sheets)      — 4dp elevation equivalent
  static const Color surfaceElevated = Color(0xFF2C2C2C);

  /// Input fields, search bars       — distinguishable from surface
  static const Color surfaceInput = Color(0xFF1F2A30);

  /// Other-user message bubble
  static const Color surfaceBubbleReceived = Color(0xFF202C33);

  /// Chat input bar surface
  static const Color surfaceInputBar = Color(0xFF1A1A1A);

  /// Navigation bars, app bars       — same as background
  static const Color surfaceBar = Color(0xFF121212);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 3: AppShadowTokens — Shadows / Overlays
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppShadowTokens {
  AppShadowTokens._();

  // Light mode: dark-based shadows
  static const Color shadowLight = Color(0x1A000000); // 10% black
  static const Color shadowLightStrong = Color(0x33000000); // 20% black

  // Dark mode: white-based shadows (light on dark)
  static const Color shadowDark = Color(0x1AFFFFFF); // 10% white
  static const Color shadowDarkStrong = Color(0x33FFFFFF); // 20% white

  /// Screen overlay / modal backdrop (light mode)
  static const Color overlayLight = Color(0x40000000); // 25% black

  /// Screen overlay / modal backdrop (dark mode)
  static const Color overlayDark = Color(0x40800080); // 25% dark tint
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 4: AppSpacing (4pt grid)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppSpacing {
  AppSpacing._();

  // Base units
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  // Semantic aliases (use these, not base units, in layouts)
  static const double screenH = md; // horizontal screen padding
  static const double betweenCards = xs; // gap between list items
  static const double betweenSections = lg; // gap between sections
  static const double cardPadding = md; // padding inside cards
  static const double avatarGap = sm; // gap between avatar & text
  static const double inputPadding = sm; // horizontal padding inside inputs

  /// Convert to ScreenUtil: call .w or .h at usage site
  /// e.g., SizedBox(height: AppSpacing.sm.h)
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 5: AppSizing
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppSizing {
  AppSizing._();

  // Touch targets (minimum 48pt)
  static const double touchMin = 48.0;
  static const double touchIcon = 44.0; // icon-only buttons

  // Button heights
  static const double buttonHeight = 48.0;
  static const double buttonSmall = 36.0;

  // Input fields
  static const double inputHeight = 46.0;
  static const double inputLargeHeight = 125.0;

  // Icons
  static const double iconXxs = 12.0;
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  // Avatars
  static const double avatarXs = 24.0;
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 48.0;
  static const double avatarXl = 56.0;

  // Chat components
  static const double chatInputBarMin = 56.0;
  static const double bubbleMaxWidth = 0.75; // fraction of screen width

  /// Convert to ScreenUtil at usage: AppSizing.buttonHeight.h
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 6: AppRadius
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 1000.0; // pill shape

  // Semantic aliases
  static const double card = md;
  static const double button = lg;
  static const double input = md;
  static const double bubble = sm;
  static const double avatar = full;
  static const double modal = xl;

  /// Convert: AppRadius.md.r
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 7: AppTextTheme — resolved text styles
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Follows Material 3 type scale: display, headline, title, body, label.
// Deviations from M3 spec: headlineSmall keeps w500 (M3 default is w400).
// Color variants live in call sites via .copyWith(), not in getter names.

extension AppTextTheme on BuildContext {
  _AppTextStyles get text => _AppTextStyles.of(this);
}

class _AppTextStyles {
  _AppTextStyles._(this._scheme);
  final ColorScheme _scheme;

  // ── Public color resolvers (for .copyWith at call sites) ──
  Color get primaryText => _scheme.onSurface;
  Color get secondaryText => _scheme.onSurface.withValues(alpha: 0.85);
  Color get tertiaryText => _scheme.onSurface.withValues(alpha: 0.5);
  Color get accentText => _scheme.primary;

  static _AppTextStyles of(BuildContext context) {
    return _AppTextStyles._(Theme.of(context).colorScheme);
  }

  // ── Display ──
  TextStyle get displayLarge => TextStyle(
    fontSize: 57.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get displayMedium => TextStyle(
    fontSize: 45.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get displaySmall => TextStyle(
    fontSize: 36.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );

  // ── Headline ──
  TextStyle get headlineLarge => TextStyle(
    fontSize: 32.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get headlineMedium => TextStyle(
    fontSize: 28.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get headlineSmall => TextStyle(
    fontSize: 24.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );

  // ── Title ──
  TextStyle get titleLarge => TextStyle(
    fontSize: 22.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get titleMedium => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get titleSmall => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );

  // ── Body ──
  TextStyle get bodyLarge => TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get bodyMedium => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get bodySmall => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );

  // ── Label ──
  TextStyle get labelLarge => TextStyle(
    fontSize: 14.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get labelMedium => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );
  TextStyle get labelSmall => TextStyle(
    fontSize: 9.sp,
    fontWeight: FontWeight.w400,
    color: primaryText,
    height: 1.5,
  );

  // ── Semantic aliases (for high-frequency reusable patterns) ──
  TextStyle get appBarTitle => titleMedium.copyWith(color: accentText);
  TextStyle get senderName =>
      bodyMedium.copyWith(fontWeight: FontWeight.w600, color: secondaryText);
  TextStyle get typeMessage => TextStyle(
    fontSize: 13.sp,
    fontWeight: FontWeight.w400,
    color: secondaryText,
    height: 1.5,
    decoration: TextDecoration.none,
  );
  TextStyle get contactName => TextStyle(
    fontSize: 13.sp,
    fontWeight: FontWeight.w400,
    color: tertiaryText,
    height: 1.5,
  );
  TextStyle get buttonText => TextStyle(
    fontSize: 12.sp,
    fontWeight: FontWeight.w400,
    color: _scheme.onPrimary,
    height: 1.5,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 8: AppTheme — ThemeData constructors
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildLight();
  static ThemeData get dark => _buildDark();

  static ThemeData _buildLight() {
    final scheme = ColorScheme.light(
      primary: AppColorTokens.primary,
      secondary: AppColorTokens.secondary,
      error: AppColorTokens.error,
      surface: AppSurfaceLight.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppSurfaceLight.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppSurfaceLight.surfaceBar,
        foregroundColor: scheme.surface,
        elevation: 0.5,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme, isDark: false),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      segmentedButtonTheme: _segmentedButtonTheme(scheme),
      extensions: [_skeletonConfig(isDark: false)],
    );
  }

  static ThemeData _buildDark() {
    final scheme = ColorScheme.dark(
      primary: AppColorTokens.primary,
      secondary: AppColorTokens.secondary,
      error: AppColorTokens.error,
      surface: AppSurfaceDark.surface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppSurfaceDark.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppSurfaceDark.surfaceBar,
        foregroundColor: scheme.surface.withValues(alpha: 0.9),
        elevation: 0.5,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme, isDark: true),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      segmentedButtonTheme: _segmentedButtonTheme(scheme),
      extensions: [_skeletonConfig(isDark: true)],
    );
  }

  // ── Shared sub-themes ──

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: AppColorTokens.disabled,
        disabledForegroundColor: AppColorTokens.disabledText,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w),
        minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button.r),
        ),
        textStyle: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? AppSurfaceDark.surfaceInput
          : AppSurfaceLight.surfaceInput,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        borderSide: BorderSide(color: scheme.error),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.inputPadding.w,
        vertical: AppSpacing.sm.h,
      ),
    );
  }

  // --- Segmented Button Theme
  static SegmentedButtonThemeData _segmentedButtonTheme(ColorScheme scheme) {
    return SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surface;
        }),

        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.onSurface.withValues(alpha: 0.6);
        }),

        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(color: scheme.primary.withValues(alpha: 0.4));
        }),

        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button.r),
          ),
        ),
      ),
    );
  }

  static SkeletonizerConfigData _skeletonConfig({required bool isDark}) {
    return SkeletonizerConfigData(
      effect: ShimmerEffect(
        baseColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE6E9ED),
        highlightColor: isDark
            ? const Color(0xFF03DAC6)
            : const Color(0xFF82B1FF),
      ),
    );
  }
}

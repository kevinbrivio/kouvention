# Implementation Guide: Visual Hierarchy & Token System

> Guide for @davinci to execute the design token migration.
> Single source of truth for colors, spacing, sizing, radius, and text theme.

---

## Overview

Replace ad-hoc hex literals (~74 values), inline `ScreenUtil` calls, and scattered `AppColors` / `AppTextTheme` references with a **single `tokens.dart`** consumed by every widget.

**Scope:** ~40 files, 404 named color usages, 74 unique hex values, 7 surface levels.

**Principle:** One `tokens.dart` file. No exceptions. Every UI file imports from one place.

---

## Phase 0 — Create `tokens.dart`

**File:** `lib/cores/constants/tokens.dart`

Single source of truth. 6 layers:

### Layer 1: Brand Colors

```dart
// lib/cores/constants/tokens.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 1: AppColorTokens — Brand + Functional
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// DO NOT use these directly in widgets. Use AppTheme.of(context).surface.xxx
// These are raw VALUES, only consumed by AppTheme constructors.
class AppColorTokens {
  AppColorTokens._();

  // Brand
  static const Color primary = Color(0xFF0FBA39);
  static const Color primaryLighter = Color(0xFF80D58B); // dark mode variant
  static const Color primaryDark = Color(0xFF4490ED); // blue (legacy, min use)
  static const Color secondary = Color(0xFFFF8040); // orange (legacy, min use)

  // Functional
  static const Color error = Color(0xFFFF0033);
  static const Color success = Color(0xFF0FBA39);
  static const Color warning = Color(0xFFFF8040);
  static const Color info = Color(0xFF4490ED);
  static const Color disabled = Color(0xFFB3B3B3);
  static const Color disabledText = Color(0xFF8C8C8C);
}
```

### Layer 2: Surface Colors (Light)

```dart
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 2a: AppSurfaceLight — 5 tonal layers
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// No pure white (#FFFFFF) below surfaces layer (use only for overlays.)
// Each surface has numbered elevation: surface0 = highest (cards),
// surface4 = lowest (background).
class AppSurfaceLight {
  AppSurfaceLight._();

  /// Scaffold / page background
  static const Color background = Color(0xFFF6F4E8);

  /// Surface containers (cards, list items, dialogs)
  static const Color surface = Color(0xFFFFFFFF);

  /// Elevated surfaces (sheets, menus)
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  /// Input fields, search bars
  static const Color surfaceInput = Color(0xFFF5F5F0);

  /// Other-user message bubble
  static const Color surfaceBubbleReceived = Color(0xFFF5F5F0);

  /// Navigation bars, app bars
  static const Color surfaceBar = Color(0xFFF6F4E8);
}
```

### Layer 3: Surface Colors (Dark)

```dart
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
```

### Layer 4: Shadows / Overlays

```dart
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 3: AppShadowTokens
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
```

### Layer 5: Spacing, Sizing, Radius

```dart
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
  static const double screenH = md;      // horizontal screen padding
  static const double betweenCards = xs; // gap between list items
  static const double betweenSections = lg; // gap between sections
  static const double cardPadding = md;  // padding inside cards
  static const double avatarGap = sm;    // gap between avatar & text
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
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;

  // Avatars
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 48.0;

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
```

### Layer 6: Text Theme

```dart
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LAYER 7: AppTextTheme — resolved text styles
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Replaces the old AppTextTheme.of(context) pattern.
// Resolves colors from ColorScheme (context-aware) instead of hardcoded hex.

extension AppTextTheme on BuildContext {
  _AppTextStyles get text => _AppTextStyles.of(this);
}

class _AppTextStyles {
  _AppTextStyles._(this._scheme);
  final ColorScheme _scheme;

  // Color resolvers (read from ColorScheme, not hardcoded)
  Color get _primaryText => _scheme.onSurface;
  Color get _secondaryText => _scheme.onSurface.withValues(alpha: 0.7);
  Color get _tertiaryText => _scheme.onSurface.withValues(alpha: 0.5);
  Color get _accentText => _scheme.primary;

  static _AppTextStyles of(BuildContext context) {
    return _AppTextStyles._(Theme.of(context).colorScheme);
  }

  // ── Headlines ──
  TextStyle get headline1 => TextStyle(
        fontSize: 42.sp,
        fontWeight: FontWeight.bold,
        color: _primaryText,
        height: 1.5,
      );

  TextStyle get subheadline1 => TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.w500,
        color: _primaryText,
        height: 1.5,
      );

  // ── Body ──
  TextStyle get body1 => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        color: _primaryText,
        height: 1.5,
      );

  TextStyle get body2 => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w400,
        color: _primaryText,
        height: 1.5,
      );

  // ── Descriptions (secondary) ──
  TextStyle get subDescription => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: _secondaryText,
        height: 1.5,
      );

  TextStyle get subDescription2 => TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
        color: _secondaryText,
        height: 1.5,
      );

  TextStyle get subDescription3 => TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: _tertiaryText,
        height: 1.5,
      );

  // ── Specialized ──
  TextStyle get appBar => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: _accentText,
        height: 1.5,
      );

  TextStyle get buttonText => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        color: _scheme.onPrimary,
        height: 1.5,
      );

  TextStyle get contactName => TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: _tertiaryText,
        height: 1.5,
      );

  TextStyle get senderName => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: _secondaryText,
        height: 1.5,
      );

  TextStyle get typeMessage => TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
        color: _secondaryText,
        height: 1.5,
        decoration: TextDecoration.none,
      );
}
```

### Layer 7: AppTheme (Light + Dark ThemeData)

```dart
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
        foregroundColor: scheme.onSurface,
        elevation: 0.5,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme, isDark: false),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      extensions: [
        _skeletonConfig(isDark: false),
      ],
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
        foregroundColor: scheme.onSurface.withValues(alpha: 0.9),
        elevation: 0.5,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(scheme),
      inputDecorationTheme: _inputDecorationTheme(scheme, isDark: true),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      extensions: [
        _skeletonConfig(isDark: true),
      ],
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
      fillColor: isDark ? AppSurfaceDark.surfaceInput : AppSurfaceLight.surfaceInput,
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

  static _skeletonConfig({required bool isDark}) {
    return SkeletonizerConfigData(
      baseColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE6E9ED),
      highlightColor:
          isDark ? const Color(0xFF03DAC6) : const Color(0xFF82B1FF),
    );
  }
}
```

---

## Phase 1 — PR1: Foundation

**Goal:** Create `tokens.dart`, delete old files, verify no regressions.

### Steps

1. **Create `lib/cores/constants/tokens.dart`** with all 6 layers above.
2. **Delete or deprecate:**
   - `lib/cores/constants/colors.dart` (keep as thin re-export wrapper for 1 release cycle if needed)
   - `lib/cores/constants/text_theme.dart` (moved into tokens.dart as extension)
   - `lib/cores/constants/button_theme.dart/` (entire directory — moved into AppTheme)
3. **Update `lib/cores/constants/custom_theme.dart`:**
   - Replace body with `export 'tokens.dart' show AppTheme;`
   - Or import tokens.dart and re-export AppTheme
4. **Update `main.dart`:**
   - Remove imports of `custom_theme.dart` if path changed
   - Keep `theme: AppTheme.light, darkTheme: AppTheme.dark`
5. **Verify:** `flutter analyze` passes.
6. **Verify:** app builds and launches in both light/dark modes.

### Files to touch

| File | Action |
|---|---|
| `lib/cores/constants/tokens.dart` | CREATE |
| `lib/cores/constants/colors.dart` | DELETE content, keep as `export` |
| `lib/cores/constants/text_theme.dart` | DELETE |
| `lib/cores/constants/custom_theme.dart` | Rewrite to import tokens.dart |
| `lib/cores/constants/button_theme/elevated_button_theme.dart` | DELETE |
| `lib/cores/constants/button_theme/secondary_button_theme.dart` | DELETE |
| `lib/cores/constants/button_theme/cancel_button_theme.dart` | DELETE |
| `lib/cores/constants/button_theme/white_button_theme.dart` | DELETE |
| `lib/main.dart` | Remove dead imports |

### Validation

```bash
flutter analyze
flutter build apk --debug  # or ios debug
```

---

## Phase 2 — PR2: Core Components

**Goal:** Migrate widgets in `lib/cores/widgets/` to use `context.text.xxx` and theme tokens.

### Order (lowest risk first)

1. `custom_divider.dart` — simplest, 2 refs
2. `custom_app_bar.dart` — 1 file, uses AppColors.primary
3. `icon_holder.dart` — uses primary + primary2
4. `transparent_box.dart` — uses AppColors.white
5. `liquid_glass_box.dart` — brightness check + bg colors
6. `loading_indicator.dart` — uses AppColors.primary + backdrop
7. `custom_button.dart` — 4 button theme imports
8. `custom_text_field.dart` — heaviest, uses colors + text theme
9. `base_view.dart` — gradient bg + dark overlay

### Conversion pattern for each file

```dart
// BEFORE (old pattern)
Text(
  'Hello',
  style: AppTextTheme.of(context).body1,
)

// AFTER (new pattern)
Text(
  'Hello',
  style: context.text.body1,
)
```

```dart
// BEFORE (old AppColors usage)
Container(
  color: AppColors.primary,
)

// AFTER (use ColorScheme)
Container(
  color: Theme.of(context).colorScheme.primary,
)
// OR if no scheme equivalent, use AppColorTokens.primary
// (only after verifying no theme-aware alternative exists)
```

### Validation

```bash
flutter analyze
# Manually check: custom_text_field.dart still shows validation colors correctly
# Manually check: custom_button.dart shows all 4 variants correctly
```

---

## Phase 3 — PR3: Screen Migration (7 sub-phases)

**Goal:** Migrate all feature files. Order is by UI density (simplest first).

### Sub-phase 3a: Auth / Login (`login_view.dart`, `privacy_policy_view.dart`)

- `AppTextTheme.of(context).xxx` → `context.text.xxx`
- `AppColors.primary` → `Theme.of(context).colorScheme.primary`

### Sub-phase 3b: Profile & Settings

- `chat_profile_view.dart`
- `appearance_settings_view.dart`
- `new_chat_view.dart`
- `new_group_chat_view.dart`

### Sub-phase 3c: Chat List

- `chat_list_view.dart`
- `chat_list_item.dart`
- `chat_header.dart`

### Sub-phase 3d: Chat Room

- `chat_room_view.dart`
- `chat_room_appbar.dart`
- `message_bubble.dart`
- `media_bubble.dart`

### Sub-phase 3e: Chat Profile

- `chat_profile_view.dart`

### Sub-phase 3f: Search & Widgets

- All remaining widget files under `lib/features/chat/widgets/`
- `lib/features/auth/` and `lib/features/profile/` if any

### Sub-phase 3g: Polish

- Audit remaining hardcoded hex values: `rg "Color\(0x" --include="*.dart"` > audit.txt
- Audit remaining `AppColors.` refs: `rg "AppColors\." --include="*.dart"` > audit.txt
- Audit remaining `AppTextTheme.of` refs: `rg "AppTextTheme\.of" --include="*.dart"` > audit.txt
- Fix all remaining violations

---

## Conversion Rules

### Rule 1: Always prefer ColorScheme before AppColorTokens

```dart
// ✅ GOOD
color: Theme.of(context).colorScheme.primary
color: Theme.of(context).colorScheme.onSurface

// ❌ BAD
color: AppColorTokens.primary  // (unless scheme doesn't have it)
color: AppColorTokens.primaryDark  // (it's a special-purpose blue)
```

### Rule 2: Only use AppColorTokens for brand colors not in ColorScheme

```dart
// OK — not in ColorScheme:
AppColorTokens.primaryLighter  // (#80D58B, used in gradients)
AppSurfaceLight.surfaceInput   // (#F5F5F0, not a scheme concept)
```

### Rule 3: Text styles go through `context.text.xxx`

```dart
// ✅ GOOD: context-aware, no context parameter needed
style: context.text.body1
style: context.text.subDescription2

// ❌ BAD: old pattern
style: AppTextTheme.of(context).body1
```

### Rule 4: Spacing uses `AppSpacing.semanticName.h` / `.w`

```dart
// ✅ GOOD
padding: EdgeInsets.all(AppSpacing.md.w),
SizedBox(height: AppSpacing.betweenCards.h),

// ❌ BAD
padding: EdgeInsets.all(16.w),
SizedBox(height: 8.h),
```

### Rule 5: Sizing uses `AppSizing.name.h`

```dart
// ✅ GOOD
minimumSize: Size(double.minPositive, AppSizing.buttonHeight.h),

// ❌ BAD
minimumSize: Size(double.minPositive, 48.h),
```

### Rule 6: Radius uses `AppRadius.name.r`

```dart
// ✅ GOOD
borderRadius: BorderRadius.circular(AppRadius.button.r),

// ❌ BAD
borderRadius: BorderRadius.circular(16.r),
```

### Rule 7: Never use `Colors.black` or `Colors.white` for surfaces

```dart
// ✅ GOOD (dark mode)
backgroundColor: AppSurfaceDark.background  // #121212

// ✅ GOOD (light mode)
backgroundColor: AppSurfaceLight.background  // #F6F4E8

// ❌ BAD — never
backgroundColor: Colors.black
backgroundColor: Colors.white
```

### Rule 8: Dark mode overlay uses AppShadowTokens

```dart
// ✅ GOOD
color: isDark ? AppShadowTokens.shadowDark : AppShadowTokens.shadowLight

// ❌ BAD
color: Colors.black.withOpacity(0.1)
```

---

## Rollback Plan

If a PR breaks the UI:

1. Revert the PR commit: `git revert HEAD`
2. Log the file and the specific token that caused the issue
3. Fix the token value in `tokens.dart` (wrong hex?)
4. Re-apply PR with fix

---

## Verification Checklist

### Before merge (per file)

- [ ] No `AppTextTheme.of(context)` calls remain
- [ ] No `AppColors.xxx` for color values that have a scheme equivalent
- [ ] No `Colors.black` or `Colors.white` for surface/background
- [ ] No inline `ScreenUtil` values for spacing/sizing/radius
- [ ] `context.text.xxx` used for all text styles
- [ ] `Theme.of(context).colorScheme.xxx` preferred over raw tokens
- [ ] `flutter analyze` passes on the changed file

### Before PR merge

- [ ] Light mode chat list: no regressions in item spacing, text colors, bubble colors
- [ ] Dark mode chat list: no pure black (#000000) or pure white (#FFFFFF) surfaces
- [ ] Light mode chat room: bubbles, input bar, app bar render correctly
- [ ] Dark mode chat room: input bar surface is #1A1A1A, bubble received is #202C33
- [ ] Buttons: all 4 variants render with correct colors
- [ ] Text fields: focus border uses primary color, error uses error color

---

## Audit commands

```bash
# Count remaining old-pattern references
rg "AppTextTheme\.of" --include="*.dart" --no-filename | wc -l
rg "AppColors\." --include="*.dart" --no-filename | wc -l
rg "Color\(0x" --include="*.dart" --no-filename | wc -l

# Find hardcoded black/white on surfaces
rg "Colors\.black" --include="*.dart" -n
rg "Colors\.white" --include="*.dart" -n

# Find inline ScreenUtil values (potential spacing violations)
rg "\d+\.(w|h|r)\b" --include="*.dart" -n --no-filename | sort | uniq -c | sort -rn
```

// lib/core/theme/app_theme.dart
//
// Design tokens from the handoff spec (app-shared.jsx T object).
// Every colour, font, radius, and spacing is sourced directly from the prototype.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Colour tokens ────────────────────────────────────────────────────────────
class AC {
  AC._();

  static const bg           = Color(0xFFEDE0C0); // Page/screen background
  static const surface      = Color(0xFFF8F2E4); // Cards, list items
  static const surfaceAlt   = Color(0xFFEAD9B2); // Secondary surfaces, accordion headers
  static const surfaceDim   = Color(0xFFE4CFA0); // Dimmed surfaces
  static const text         = Color(0xFF1E1208); // Primary text
  static const textSec      = Color(0xFF6A4618); // Secondary text
  static const textMuted    = Color(0xFF7A5428); // Muted/placeholder text
  static const accent       = Color(0xFF7A3A10); // Accent — links, active states
  static const accentBright = Color(0xFF9A5020); // Hover accent
  static const border       = Color(0xFFC4A060); // Standard borders
  static const borderLight  = Color(0xFFDEC890); // Light dividers
  static const btnBg        = Color(0xFF7A3A10); // Primary button background
  static const btnText      = Color(0xFFFFF4E4); // Primary button text
  static const trackBg      = Color(0xFFC8A870); // Audio track background
  static const trackFill    = Color(0xFF7A3A10); // Audio track fill
  static const dot          = Color(0xFFA86030); // Seek dot
  static const chipBg       = Color(0xFFEAD9B2); // Word chip background
  static const chipText     = Color(0xFF5A3010); // Word chip text
  static const loopActive   = Color(0xFF4A6A30); // Repeat active (green)
  static const loopActiveBg = Color(0xFFE8F0D8); // Repeat counter background
  static const lineHl       = Color(0xFFFFEEC8); // Active pāda highlight
  static const lineBorder   = Color(0xFFC89840); // Active pāda border
  static const dangerBg     = Color(0xFFF8EDE0); // Danger background
  static const recRed       = Color(0xFFC03020); // Recording red

  // Sidebar / tree pane — dark warm wood
  static const sidebar      = Color(0xFF2C1A0A); // sidebar background
  static const sidebarHdr   = Color(0xFF1E1208); // sidebar header strip
  static const sidebarText  = Color(0xFFF0E4C8); // primary text on dark bg
  static const sidebarMuted = Color(0xFFBB9060); // secondary text on dark bg
  static const sidebarSel   = Color(0xFFE8A840); // amber — selected item
  static const sidebarBorder= Color(0xFF503A20); // dividers within sidebar

  // Gender badge colours
  static const genderMasc   = Color(0xFF7A3A10);
  static const genderFem    = Color(0xFF6A3060);
  static const genderNeut   = Color(0xFF2A5A40);
}

// ─── Text styles ─────────────────────────────────────────────────────────────
class AT {
  AT._();

  // Tiro Devanagari Sanskrit — for all Sanskrit/Devanagari text
  static const devanagari22 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 22,
    color: AC.text, height: 1.7,
  );
  static const devanagari20 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 20,
    color: AC.text, height: 1.5,
  );
  static const devanagari18 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 18,
    color: AC.text, height: 1.6,
  );
  static const devanagari16 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 16,
    color: AC.text,
  );
  static const devanagari15 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 15,
    color: AC.text,
  );
  static const devanagari14 = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 14,
    color: AC.textMuted,
  );
  static const wordChip = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 17,
    color: AC.text,
  );
  static const grammarWord = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 36,
    color: AC.text, height: 1.3,
  );
  static const grammarStem = TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 18,
    color: AC.text,
  );

  // Devanagari — selectable font family, for Sanskrit text
  static TextStyle devanagari(double size, {
    Color  color  = AC.text,
    double height = 1.8,
    String family = 'TiroDevanagarSanskrit',
  }) {
    if (family == 'NotoSerifDevanagari') {
      return GoogleFonts.notoSerifDevanagari(
          fontSize: size, color: color, height: height);
    }
    return TextStyle(
        fontFamily: 'TiroDevanagarSanskrit',
        fontSize: size, color: color, height: height);
  }

  // EB Garamond — for all UI text
  static TextStyle garamond(double size, {
    Color color = AC.text,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.ebGaramond(
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // Pre-built common variants
  static TextStyle get body16  => garamond(16);
  static TextStyle get body15  => garamond(15);
  static TextStyle get body14  => garamond(14);
  static TextStyle get body13  => garamond(13);
  static TextStyle get body12  => garamond(12);
  static TextStyle get body11  => garamond(11);
  static TextStyle get label10 => garamond(10,
      color: AC.textMuted,
      letterSpacing: 0.1 * 10,);
  static TextStyle get stats28 => garamond(28, color: AC.accent);
  static TextStyle get btnLabel => garamond(16, color: AC.btnText);
  static TextStyle get btnLabel18 => garamond(18, color: AC.btnText);
}

// ─── Theme ────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AC.bg,
      colorScheme: const ColorScheme.light(
        primary: AC.accent,
        onPrimary: AC.btnText,
        secondary: AC.accentBright,
        surface: AC.surface,
        onSurface: AC.text,
        outline: AC.border,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AC.bg,
        foregroundColor: AC.text,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AT.garamond(16, color: AC.text),
      ),
      dividerTheme: const DividerThemeData(
        color: AC.borderLight,
        thickness: 1,
        space: 0,
      ),
    );
  }
}

// ─── Shared decorations ───────────────────────────────────────────────────────
class AD {
  AD._();

  static BoxDecoration card({double radius = 14}) => BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AC.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 2))
        ],
      );

  static BoxDecoration surfaceAlt({double radius = 12}) => BoxDecoration(
        color: AC.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AC.border),
      );

  static BoxDecoration chip() => BoxDecoration(
        color: AC.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.border),
      );

  static BoxDecoration activeLine() => BoxDecoration(
        color: AC.lineHl,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.lineBorder, width: 1.5),
      );

  static BoxDecoration loopCounter() => BoxDecoration(
        color: AC.loopActiveBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.loopActive.withOpacity(0.4)),
      );
}

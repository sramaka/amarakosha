// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../settings/app_settings.dart';

// ─── Color scheme ─────────────────────────────────────────────────────────────
class AppColorScheme {
  final String id;
  final String label;

  final Color bg, surface, surfaceAlt, surfaceDim;
  final Color text, textSec, textMuted;
  final Color accent, accentBright;
  final Color border, borderLight;
  final Color btnBg, btnText;
  final Color trackBg, trackFill, dot;
  final Color chipBg, chipText;
  final Color loopActive, loopActiveBg;
  final Color lineHl, lineBorder;
  final Color dangerBg, recRed;

  // Sidebar / tree pane
  final Color sidebar, sidebarHdr, sidebarText, sidebarMuted, sidebarSel, sidebarBorder;

  // Gender badge colours
  final Color genderMasc, genderFem, genderNeut;

  const AppColorScheme({
    required this.id,
    required this.label,
    required this.bg, required this.surface,
    required this.surfaceAlt, required this.surfaceDim,
    required this.text, required this.textSec, required this.textMuted,
    required this.accent, required this.accentBright,
    required this.border, required this.borderLight,
    required this.btnBg, required this.btnText,
    required this.trackBg, required this.trackFill, required this.dot,
    required this.chipBg, required this.chipText,
    required this.loopActive, required this.loopActiveBg,
    required this.lineHl, required this.lineBorder,
    required this.dangerBg, required this.recRed,
    required this.sidebar, required this.sidebarHdr,
    required this.sidebarText, required this.sidebarMuted,
    required this.sidebarSel, required this.sidebarBorder,
    required this.genderMasc, required this.genderFem, required this.genderNeut,
  });
}

// ─── Theme instances ──────────────────────────────────────────────────────────
class AppColorSchemes {
  AppColorSchemes._();

  static const parchment = AppColorScheme(
    id: 'parchment', label: 'Parchment',
    bg:          Color(0xFFEDE0C0),
    surface:     Color(0xFFF8F2E4),
    surfaceAlt:  Color(0xFFEAD9B2),
    surfaceDim:  Color(0xFFE4CFA0),
    text:        Color(0xFF1E1208),
    textSec:     Color(0xFF6A4618),
    textMuted:   Color(0xFF7A5428),
    accent:      Color(0xFF7A3A10),
    accentBright:Color(0xFF9A5020),
    border:      Color(0xFFC4A060),
    borderLight: Color(0xFFDEC890),
    btnBg:       Color(0xFF7A3A10),
    btnText:     Color(0xFFFFF4E4),
    trackBg:     Color(0xFFC8A870),
    trackFill:   Color(0xFF7A3A10),
    dot:         Color(0xFFA86030),
    chipBg:      Color(0xFFEAD9B2),
    chipText:    Color(0xFF5A3010),
    loopActive:  Color(0xFF4A6A30),
    loopActiveBg:Color(0xFFE8F0D8),
    lineHl:      Color(0xFFFFEEC8),
    lineBorder:  Color(0xFFC89840),
    dangerBg:    Color(0xFFF8EDE0),
    recRed:      Color(0xFFC03020),
    sidebar:     Color(0xFF2C1A0A),
    sidebarHdr:  Color(0xFF1E1208),
    sidebarText: Color(0xFFF0E4C8),
    sidebarMuted:Color(0xFFBB9060),
    sidebarSel:  Color(0xFFE8A840),
    sidebarBorder:Color(0xFF503A20),
    genderMasc:  Color(0xFF7A3A10),
    genderFem:   Color(0xFF6A3060),
    genderNeut:  Color(0xFF2A5A40),
  );

  static const night = AppColorScheme(
    id: 'night', label: 'Night',
    bg:          Color(0xFF1A1208),
    surface:     Color(0xFF221810),
    surfaceAlt:  Color(0xFF2C1E10),
    surfaceDim:  Color(0xFF261A0C),
    text:        Color(0xFFF0E4C8),
    textSec:     Color(0xFFC8A068),
    textMuted:   Color(0xFF8A6840),
    accent:      Color(0xFFE8A840),
    accentBright:Color(0xFFF0C060),
    border:      Color(0xFF4A3018),
    borderLight: Color(0xFF3A2410),
    btnBg:       Color(0xFFE8A840),
    btnText:     Color(0xFF1A1208),
    trackBg:     Color(0xFF4A3018),
    trackFill:   Color(0xFFE8A840),
    dot:         Color(0xFFC88030),
    chipBg:      Color(0xFF2C1E10),
    chipText:    Color(0xFFC8A068),
    loopActive:  Color(0xFF60A040),
    loopActiveBg:Color(0xFF243018),
    lineHl:      Color(0xFF3A2808),
    lineBorder:  Color(0xFF8A6020),
    dangerBg:    Color(0xFF2A1A10),
    recRed:      Color(0xFFE04030),
    sidebar:     Color(0xFF0E0806),
    sidebarHdr:  Color(0xFF0A0604),
    sidebarText: Color(0xFFE8D4A8),
    sidebarMuted:Color(0xFF9A7040),
    sidebarSel:  Color(0xFFF0C060),
    sidebarBorder:Color(0xFF2C1A0A),
    genderMasc:  Color(0xFFE8A840),
    genderFem:   Color(0xFFC080A0),
    genderNeut:  Color(0xFF70B060),
  );

  static const slate = AppColorScheme(
    id: 'slate', label: 'Slate',
    bg:          Color(0xFFE2E6EC),
    surface:     Color(0xFFECEEF2),
    surfaceAlt:  Color(0xFFD6DAE0),
    surfaceDim:  Color(0xFFCDD1D8),
    text:        Color(0xFF1A1C20),
    textSec:     Color(0xFF3C4450),
    textMuted:   Color(0xFF68727E),
    accent:      Color(0xFF2C5898),
    accentBright:Color(0xFF3A68A8),
    border:      Color(0xFFA8B0BC),
    borderLight: Color(0xFFBEC8D4),
    btnBg:       Color(0xFF2C5898),
    btnText:     Color(0xFFF0F4F8),
    trackBg:     Color(0xFFA8B0BC),
    trackFill:   Color(0xFF2C5898),
    dot:         Color(0xFF4A78C0),
    chipBg:      Color(0xFFD6DAE0),
    chipText:    Color(0xFF202830),
    loopActive:  Color(0xFF2A7840),
    loopActiveBg:Color(0xFFD0E8D8),
    lineHl:      Color(0xFFDDE8F8),
    lineBorder:  Color(0xFF88A8E0),
    dangerBg:    Color(0xFFF4ECED),
    recRed:      Color(0xFFC02820),
    sidebar:     Color(0xFF1A202A),
    sidebarHdr:  Color(0xFF121820),
    sidebarText: Color(0xFFDCE4EE),
    sidebarMuted:Color(0xFF8090A4),
    sidebarSel:  Color(0xFF7090E8),
    sidebarBorder:Color(0xFF2C3444),
    genderMasc:  Color(0xFF2C5898),
    genderFem:   Color(0xFF703090),
    genderNeut:  Color(0xFF227040),
  );

  static const minimal = AppColorScheme(
    id: 'minimal', label: 'Minimal',
    bg:          Color(0xFFF4F4F5),
    surface:     Color(0xFFFFFFFF),
    surfaceAlt:  Color(0xFFEFEFF1),
    surfaceDim:  Color(0xFFE7E7EA),
    text:        Color(0xFF18181B),
    textSec:     Color(0xFF52525B),
    textMuted:   Color(0xFFA1A1AA),
    accent:      Color(0xFF4F46E5),
    accentBright:Color(0xFF6366F1),
    border:      Color(0xFFD4D4D8),
    borderLight: Color(0xFFE4E4E7),
    btnBg:       Color(0xFF4F46E5),
    btnText:     Color(0xFFFFFFFF),
    trackBg:     Color(0xFFD4D4D8),
    trackFill:   Color(0xFF4F46E5),
    dot:         Color(0xFF6366F1),
    chipBg:      Color(0xFFEFEFF1),
    chipText:    Color(0xFF18181B),
    loopActive:  Color(0xFF059669),
    loopActiveBg:Color(0xFFD1FAE5),
    lineHl:      Color(0xFFEEF2FF),
    lineBorder:  Color(0xFFA5B4FC),
    dangerBg:    Color(0xFFFEF2F2),
    recRed:      Color(0xFFDC2626),
    sidebar:     Color(0xFF1C1C1F),
    sidebarHdr:  Color(0xFF18181B),
    sidebarText: Color(0xFFF4F4F5),
    sidebarMuted:Color(0xFFA1A1AA),
    sidebarSel:  Color(0xFF818CF8),
    sidebarBorder:Color(0xFF3F3F46),
    genderMasc:  Color(0xFF4F46E5),
    genderFem:   Color(0xFFDB2777),
    genderNeut:  Color(0xFF059669),
  );

  static const List<AppColorScheme> all = [parchment, night, slate, minimal];

  static AppColorScheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => parchment);
}

// ─── Colour tokens (delegates to current theme) ────────────────────────────────
// Use AC.xxx everywhere — never reference raw Color(...) inline.
class AC {
  AC._();

  static AppColorScheme get _t => AppSettings.instance.colors;

  static Color get bg           => _t.bg;
  static Color get surface      => _t.surface;
  static Color get surfaceAlt   => _t.surfaceAlt;
  static Color get surfaceDim   => _t.surfaceDim;
  static Color get text         => _t.text;
  static Color get textSec      => _t.textSec;
  static Color get textMuted    => _t.textMuted;
  static Color get accent       => _t.accent;
  static Color get accentBright => _t.accentBright;
  static Color get border       => _t.border;
  static Color get borderLight  => _t.borderLight;
  static Color get btnBg        => _t.btnBg;
  static Color get btnText      => _t.btnText;
  static Color get trackBg      => _t.trackBg;
  static Color get trackFill    => _t.trackFill;
  static Color get dot          => _t.dot;
  static Color get chipBg       => _t.chipBg;
  static Color get chipText     => _t.chipText;
  static Color get loopActive   => _t.loopActive;
  static Color get loopActiveBg => _t.loopActiveBg;
  static Color get lineHl       => _t.lineHl;
  static Color get lineBorder   => _t.lineBorder;
  static Color get dangerBg     => _t.dangerBg;
  static Color get recRed       => _t.recRed;
  static Color get sidebar      => _t.sidebar;
  static Color get sidebarHdr   => _t.sidebarHdr;
  static Color get sidebarText  => _t.sidebarText;
  static Color get sidebarMuted => _t.sidebarMuted;
  static Color get sidebarSel   => _t.sidebarSel;
  static Color get sidebarBorder=> _t.sidebarBorder;
  static Color get genderMasc   => _t.genderMasc;
  static Color get genderFem    => _t.genderFem;
  static Color get genderNeut   => _t.genderNeut;
}

// ─── Text styles ──────────────────────────────────────────────────────────────
class AT {
  AT._();

  // Tiro Devanagari Sanskrit — for all Sanskrit/Devanagari text
  static TextStyle get devanagari22 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 22,
    color: AC.text, height: 1.7,
  );
  static TextStyle get devanagari20 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 20,
    color: AC.text, height: 1.5,
  );
  static TextStyle get devanagari18 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 18,
    color: AC.text, height: 1.6,
  );
  static TextStyle get devanagari16 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 16,
    color: AC.text,
  );
  static TextStyle get devanagari15 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 15,
    color: AC.text,
  );
  static TextStyle get devanagari14 => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 14,
    color: AC.textMuted,
  );
  static TextStyle get wordChip => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 17,
    color: AC.text,
  );
  static TextStyle get grammarWord => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 36,
    color: AC.text, height: 1.3,
  );
  static TextStyle get grammarStem => TextStyle(
    fontFamily: 'TiroDevanagarSanskrit', fontSize: 18,
    color: AC.text,
  );

  // Devanagari — selectable font family, for Sanskrit text
  static TextStyle devanagari(double size, {
    Color?  color,
    double  height = 1.8,
    String  family = 'TiroDevanagarSanskrit',
  }) {
    final c = color ?? AC.text;
    if (family == 'NotoSerifDevanagari') {
      return GoogleFonts.notoSerifDevanagari(
          fontSize: size, color: c, height: height);
    }
    return TextStyle(
        fontFamily: 'TiroDevanagarSanskrit',
        fontSize: size, color: c, height: height);
  }

  // EB Garamond — for all UI text
  static TextStyle garamond(double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
    bool italic = false,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.ebGaramond(
      fontSize: size,
      color: color ?? AC.text,
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
      color: AC.textMuted, letterSpacing: 1.0);
  static TextStyle get stats28 => garamond(28, color: AC.accent);
  static TextStyle get btnLabel   => garamond(16, color: AC.btnText);
  static TextStyle get btnLabel18 => garamond(18, color: AC.btnText);
}

// ─── Theme ────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final isDark = AppSettings.instance.colors.bg.computeLuminance() < 0.15;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AC.bg,
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: AC.accent,
              onPrimary: AC.btnText,
              secondary: AC.accentBright,
              surface: AC.surface,
              onSurface: AC.text,
              outline: AC.border,
            )
          : ColorScheme.light(
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
      dividerTheme: DividerThemeData(
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
        border: Border.all(color: AC.loopActive.withValues(alpha: 0.4)),
      );
}

import 'package:flutter/material.dart' show FontWeight;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart' show AppColorScheme, AppColorSchemes;

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  int    devFontSize              = 36;   // Sanskrit body text (14–72)
  int    treeFontSize             = 14;   // Tree pane Devanagari + labels (10–20)
  int    uiFontSize               = 14;   // UI labels / headings (11–22)
  int    uiFontWeight             = 700;  // 400 / 500 / 600 / 700
  String devFontFamily            = 'TiroDevanagarSanskrit';
  int    contextBefore            = 2;    // padas shown above active pada in browse mode (0–5)
  int    contextAfter             = 2;    // padas shown below active pada in browse mode (0–5)
  int    setPlaylistContextBefore = 1;    // context padas before active pada during set playback (0–5)
  int    setPlaylistContextAfter  = 1;    // context padas after active pada during set playback (0–5)
  int    reciteVolumePct          = 10;   // volume % for repeat plays in Recite mode (2–20, step 2)
  bool   autoPlayBrowse           = true;  // auto-play audio when navigating in browse mode
  bool   showSpeedButtons         = false; // show speed buttons in the audio player
  String themeId                  = 'parchment';

  AppColorScheme get colors => AppColorSchemes.byId(themeId);

  static const _kDevSize          = 'dev_font_size';
  static const _kTreeSize         = 'tree_font_size';
  static const _kUiSize           = 'ui_font_size';
  static const _kUiWeight         = 'ui_font_weight';
  static const _kDevFamily        = 'dev_font_family';
  static const _kCtxBefore        = 'context_before';
  static const _kCtxAfter         = 'context_after';
  static const _kSetCtxBefore     = 'set_ctx_before';
  static const _kSetCtxAfter      = 'set_ctx_after';
  static const _kReciteVolume     = 'recite_volume_pct';
  static const _kAutoPlayBrowse   = 'auto_play_browse';
  static const _kShowSpeedButtons = 'show_speed_buttons';
  static const _kThemeId          = 'theme_id';

  FontWeight get fontWeight {
    switch (uiFontWeight) {
      case 400: return FontWeight.w400;
      case 600: return FontWeight.w600;
      case 700: return FontWeight.w700;
      default:  return FontWeight.w500;
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    devFontSize   = p.getInt(_kDevSize)      ?? 36;
    treeFontSize  = p.getInt(_kTreeSize)     ?? 14;
    uiFontSize    = p.getInt(_kUiSize)       ?? 14;
    uiFontWeight  = p.getInt(_kUiWeight)     ?? 700;
    devFontFamily = p.getString(_kDevFamily) ?? 'TiroDevanagarSanskrit';
    contextBefore            = p.getInt(_kCtxBefore)    ?? 2;
    contextAfter             = p.getInt(_kCtxAfter)     ?? 2;
    setPlaylistContextBefore = p.getInt(_kSetCtxBefore)    ?? 1;
    setPlaylistContextAfter  = p.getInt(_kSetCtxAfter)     ?? 1;
    reciteVolumePct          = p.getInt(_kReciteVolume)    ?? 10;
    autoPlayBrowse           = p.getBool(_kAutoPlayBrowse)   ?? true;
    showSpeedButtons         = p.getBool(_kShowSpeedButtons) ?? false;
    themeId                  = p.getString(_kThemeId)      ?? 'parchment';
    notifyListeners();
  }

  Future<void> setDevFontSize(int v) async {
    devFontSize = v.clamp(14, 72);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kDevSize, devFontSize);
  }

  Future<void> setTreeFontSize(int v) async {
    treeFontSize = v.clamp(10, 20);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kTreeSize, treeFontSize);
  }

  Future<void> setUiFontSize(int v) async {
    uiFontSize = v.clamp(11, 22);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kUiSize, uiFontSize);
  }

  Future<void> setUiFontWeight(int v) async {
    uiFontWeight = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kUiWeight, uiFontWeight);
  }

  Future<void> setDevFontFamily(String v) async {
    devFontFamily = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_kDevFamily, devFontFamily);
  }

  Future<void> setContextBefore(int v) async {
    contextBefore = v.clamp(0, 5);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kCtxBefore, contextBefore);
  }

  Future<void> setContextAfter(int v) async {
    contextAfter = v.clamp(0, 5);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kCtxAfter, contextAfter);
  }

  Future<void> setSetPlaylistContextBefore(int v) async {
    setPlaylistContextBefore = v.clamp(0, 5);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kSetCtxBefore, setPlaylistContextBefore);
  }

  Future<void> setSetPlaylistContextAfter(int v) async {
    setPlaylistContextAfter = v.clamp(0, 5);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kSetCtxAfter, setPlaylistContextAfter);
  }

  Future<void> setThemeId(String v) async {
    themeId = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_kThemeId, themeId);
  }

  Future<void> setReciteVolumePct(int v) async {
    reciteVolumePct = v.clamp(0, 20);
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt(_kReciteVolume, reciteVolumePct);
  }

  Future<void> setAutoPlayBrowse(bool v) async {
    autoPlayBrowse = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kAutoPlayBrowse, autoPlayBrowse);
  }

  Future<void> setShowSpeedButtons(bool v) async {
    showSpeedButtons = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kShowSpeedButtons, showSpeedButtons);
  }
}

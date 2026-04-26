import 'package:flutter/material.dart' show FontWeight;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final instance = AppSettings._();

  int    devFontSize     = 20;   // Sanskrit body text (14–72)
  int    treeFontSize    = 13;   // Tree pane Devanagari + labels (10–20)
  int    uiFontSize      = 13;   // UI labels / headings (11–22)
  int    uiFontWeight    = 500;  // 400 / 500 / 600 / 700
  String devFontFamily   = 'TiroDevanagarSanskrit';
  int    contextBefore   = 1;    // padas shown above active pada (0–5)
  int    contextAfter    = 1;    // padas shown below active pada (0–5)

  static const _kDevSize      = 'dev_font_size';
  static const _kTreeSize     = 'tree_font_size';
  static const _kUiSize       = 'ui_font_size';
  static const _kUiWeight     = 'ui_font_weight';
  static const _kDevFamily    = 'dev_font_family';
  static const _kCtxBefore    = 'context_before';
  static const _kCtxAfter     = 'context_after';

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
    devFontSize   = p.getInt(_kDevSize)      ?? 20;
    treeFontSize  = p.getInt(_kTreeSize)     ?? 13;
    uiFontSize    = p.getInt(_kUiSize)       ?? 13;
    uiFontWeight  = p.getInt(_kUiWeight)     ?? 500;
    devFontFamily = p.getString(_kDevFamily) ?? 'TiroDevanagarSanskrit';
    contextBefore = p.getInt(_kCtxBefore)   ?? 1;
    contextAfter  = p.getInt(_kCtxAfter)    ?? 1;
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
}

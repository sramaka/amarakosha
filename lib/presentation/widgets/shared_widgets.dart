// lib/presentation/widgets/shared_widgets.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/app_settings.dart';

// ─── Section label (10px uppercase muted) ────────────────────────────────────
class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key,
      this.padding = const EdgeInsets.only(bottom: 8)});

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(text.toUpperCase(),
        style: AT.garamond(11,
            color: AC.textSec, weight: FontWeight.w600, letterSpacing: 1.0)),
  );
}

// ─── Stepper (−/value/+) ─────────────────────────────────────────────────────
class AStepperWidget extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool small;

  const AStepperWidget({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final sz = small ? 26.0 : 30.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn('−', () => onChanged((value - 1).clamp(min, max)), sz),
        SizedBox(width: small ? 6 : 8),
        SizedBox(
          width: small ? 20 : 24,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: AT.garamond(small ? 15 : 17,
                  color: AC.text, weight: FontWeight.w500)),
        ),
        SizedBox(width: small ? 6 : 8),
        _btn('+', () => onChanged((value + 1).clamp(min, max)), sz),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onTap, double sz) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: sz, height: sz,
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AC.border),
      ),
      child: Center(
        child: Text(label, style: TextStyle(
            fontSize: 16, color: AC.textSec, fontFamily: 'system-ui')),
      ),
    ),
  );
}

// ─── RepDots ──────────────────────────────────────────────────────────────────
class RepDots extends StatelessWidget {
  final int cur;
  final int total;
  const RepDots({super.key, required this.cur, required this.total});

  @override
  Widget build(BuildContext context) {
    final dots = total.clamp(0, 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(dots, (i) => Container(
          margin: EdgeInsets.only(right: 5),
          width: i < cur ? 8 : 7,
          height: i < cur ? 8 : 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < cur ? AC.loopActive : AC.trackBg,
          ),
        )),
        if (total > 8)
          Text('+${total - 8}',
              style: TextStyle(color: AC.textMuted, fontSize: 11)),
      ],
    );
  }
}

// ─── ProgressBar ─────────────────────────────────────────────────────────────
class AProgressBar extends StatelessWidget {
  final double value; // 0.0–1.0
  final Color? fillColor;

  const AProgressBar({super.key, required this.value, this.fillColor});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: LinearProgressIndicator(
      value: value.clamp(0.0, 1.0),
      backgroundColor: AC.trackBg,
      valueColor:
          AlwaysStoppedAnimation(fillColor ?? AC.trackFill),
      minHeight: 4,
    ),
  );
}

// ─── AButton — primary full-width brown button ────────────────────────────────
class AButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final double radius;
  final EdgeInsets padding;

  const AButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 16,
    this.radius = 10,
    this.padding = const EdgeInsets.symmetric(vertical: 11),
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AC.btnBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(label,
            style: AT.garamond(fontSize, color: AC.btnText,
                letterSpacing: 0.2)),
      ),
    ),
  );
}

// ─── AOutlineButton ───────────────────────────────────────────────────────────
class AOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final Widget? leading;

  const AOutlineButton({
    super.key, required this.label, this.onTap,
    this.fontSize = 14, this.leading,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, SizedBox(width: 5)],
          Text(label, style: AT.garamond(fontSize, color: AC.textSec)),
        ],
      ),
    ),
  );
}

// ─── NavBar ───────────────────────────────────────────────────────────────────
class ANavBar extends StatelessWidget {
  final String? backLabel;
  final VoidCallback? onBack;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ANavBar({
    super.key, this.backLabel, this.onBack,
    required this.title, this.subtitle, this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AC.border)),
    ),
    child: Row(
      children: [
        if (backLabel != null)
          GestureDetector(
            onTap: onBack,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ChevLeft(),
                SizedBox(width: 5),
                Text(backLabel!,
                    style: AT.garamond(15, color: AC.accent)),
              ],
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Text(title, style: AT.garamond(16, color: AC.text)),
              if (subtitle != null)
                Text(subtitle!.toUpperCase(),
                    style: AT.garamond(10,
                        color: AC.textSec, letterSpacing: 0.8)),
            ],
          ),
        ),
        if (trailing != null) trailing!
        else const SizedBox(width: 50),
      ],
    ),
  );
}

// ─── Small chevron icons (inline SVG-style via CustomPaint) ──────────────────
class _ChevLeft extends StatelessWidget {
  const _ChevLeft();
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(7, 13),
    painter: _ChevPainter(right: false),
  );
}

class AChevRight extends StatelessWidget {
  final Color? color;
  const AChevRight({super.key, this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(7, 13),
    painter: _ChevPainter(right: true, color: color ?? AC.textSec),
  );
}

class _ChevPainter extends CustomPainter {
  final bool right;
  final Color? color;
  const _ChevPainter({required this.right, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color ?? AC.accent
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (right) {
      path.moveTo(1, 1);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(1, size.height);
    } else {
      path.moveTo(size.width, 1);
      path.lineTo(1, size.height / 2);
      path.lineTo(size.width, size.height);
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ChevPainter old) => old.right != right || old.color != color;
}

// ─── Handle bar (for bottom sheets) ──────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36, height: 4,
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AC.border,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

// ─── Breadcrumb (काण्ड X · वर्ग Y) ──────────────────────────────────────────
class ABreadcrumb extends StatelessWidget {
  final int kandaNum;
  final int vargaSeq;
  ABreadcrumb({super.key, required this.kandaNum, required this.vargaSeq});

  @override
  Widget build(BuildContext context) => Text(
    'काण्ड $kandaNum · वर्ग $vargaSeq',
    style: AT.garamond(11, color: AC.textSec, letterSpacing: 0.5),
  );
}

// ─── Selectable setting chip ──────────────────────────────────────────────────
class ASettingChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const ASettingChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AC.accent.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? AC.accent : AC.border),
        ),
        child: Text(label,
            style: AT.garamond(13, color: active ? AC.accent : AC.textSec)),
      ),
    );
  }
}

// ─── Row setting item (label + optional sub + trailing widget) ────────────────
class SettingRow extends StatelessWidget {
  final String label;
  final String? sub;
  final Widget trailing;
  final bool last;

  const SettingRow({
    super.key, required this.label, this.sub,
    required this.trailing, this.last = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(vertical: 13),
    decoration: BoxDecoration(
      border: last
          ? null
          : Border(bottom: BorderSide(color: AC.borderLight)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AT.body15),
              if (sub != null)
                Text(sub!, style: AT.garamond(13, color: AC.textSec)),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

// ─── Display settings sheet ───────────────────────────────────────────────────
void showDisplaySettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AC.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (ctx, __) {
        final s = AppSettings.instance;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 0, 20,
              40 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            Text('Display Settings',
                style: AT.garamond(16, weight: FontWeight.w600)),
            const SizedBox(height: 20),
            SettingRow(
              label: 'Sanskrit text size',
              sub: 'Shloka body text',
              trailing: AStepperWidget(
                  value: s.devFontSize, min: 14, max: 72,
                  onChanged: s.setDevFontSize),
            ),
            SettingRow(
              label: 'UI text size',
              sub: 'Labels and annotations',
              trailing: AStepperWidget(
                  value: s.uiFontSize, min: 11, max: 22,
                  onChanged: s.setUiFontSize),
            ),
            SettingRow(
              label: 'Navigation text size',
              sub: 'Tree pane labels',
              trailing: AStepperWidget(
                  value: s.treeFontSize, min: 10, max: 20,
                  onChanged: s.setTreeFontSize),
            ),
            SettingRow(
              label: 'Context lines before',
              sub: 'Pādas shown above the active pada',
              trailing: AStepperWidget(
                  value: s.contextBefore, min: 0, max: 5,
                  onChanged: s.setContextBefore),
            ),
            SettingRow(
              label: 'Context lines after',
              sub: 'Pādas shown below the active pada',
              trailing: AStepperWidget(
                  value: s.contextAfter, min: 0, max: 5,
                  onChanged: s.setContextAfter),
            ),
            SettingRow(
              label: 'Set context before',
              sub: 'Context pādas above active pada during set playback',
              trailing: AStepperWidget(
                  value: s.setPlaylistContextBefore, min: 0, max: 5,
                  onChanged: s.setSetPlaylistContextBefore),
            ),
            SettingRow(
              label: 'Set context after',
              sub: 'Context pādas below active pada during set playback',
              last: true,
              trailing: AStepperWidget(
                  value: s.setPlaylistContextAfter, min: 0, max: 5,
                  onChanged: s.setSetPlaylistContextAfter),
            ),
            Divider(height: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Text weight', style: AT.garamond(14, color: AC.text)),
              Text('UI label weight',
                  style: AT.garamond(13, color: AC.textSec)),
              const SizedBox(height: 10),
              Row(children: [
                ASettingChip(label: 'Normal', active: s.uiFontWeight == 400,
                    onTap: () => s.setUiFontWeight(400)),
                const SizedBox(width: 6),
                ASettingChip(label: 'Medium', active: s.uiFontWeight == 500,
                    onTap: () => s.setUiFontWeight(500)),
                const SizedBox(width: 6),
                ASettingChip(label: 'Bold', active: s.uiFontWeight == 600,
                    onTap: () => s.setUiFontWeight(600)),
                const SizedBox(width: 6),
                ASettingChip(label: 'Heavy', active: s.uiFontWeight == 700,
                    onTap: () => s.setUiFontWeight(700)),
              ]),
            ]),
            Divider(height: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sanskrit font', style: AT.garamond(14, color: AC.text)),
              const SizedBox(height: 10),
              Row(children: [
                ASettingChip(label: 'Tiro',
                    active: s.devFontFamily == 'TiroDevanagarSanskrit',
                    onTap: () => s.setDevFontFamily('TiroDevanagarSanskrit')),
                const SizedBox(width: 8),
                ASettingChip(label: 'Noto Serif',
                    active: s.devFontFamily == 'NotoSerifDevanagari',
                    onTap: () => s.setDevFontFamily('NotoSerifDevanagari')),
              ]),
            ]),
            Divider(height: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Theme', style: AT.garamond(14, color: AC.text)),
              const SizedBox(height: 12),
              Row(children: AppColorSchemes.all.map((theme) {
                final active = s.themeId == theme.id;
                return GestureDetector(
                  onTap: () => s.setThemeId(theme.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: theme.bg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? AC.accent : AC.border,
                            width: active ? 2.5 : 1.5,
                          ),
                          boxShadow: active ? [BoxShadow(
                            color: AC.accent.withValues(alpha: 0.3),
                            blurRadius: 6, offset: const Offset(0, 2),
                          )] : null,
                        ),
                        child: Center(
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(theme.label,
                          style: AT.garamond(12,
                              color: active ? AC.accent : AC.textSec,
                              weight: active ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
                );
              }).toList()),
            ]),
            Divider(height: 24),
            SettingRow(
              label: 'Auto-play on navigation',
              sub: 'Play audio when selecting a pāda',
              last: true,
              trailing: GestureDetector(
                onTap: () => s.setAutoPlayBrowse(!s.autoPlayBrowse),
                child: Container(
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: s.autoPlayBrowse ? AC.accent : AC.border,
                    borderRadius: BorderRadius.circular(10)),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment: s.autoPlayBrowse
                        ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    ),
  );
}

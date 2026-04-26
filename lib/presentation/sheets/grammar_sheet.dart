// lib/presentation/sheets/grammar_sheet.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';

// ─── Grammar Bottom Sheet ────────────────────────────────────────────────────
class GrammarSheet extends StatelessWidget {
  final AWord word;
  const GrammarSheet({super.key, required this.word});

  static Future<void> show(BuildContext context, AWord word) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => GrammarSheet(word: word),
    );
  }

  Color get _genderColor => switch (word.gender) {
    'पुंलिङ्ग'     => AC.genderMasc,
    'स्त्रीलिङ्ग' => AC.genderFem,
    'नपुंसकलिङ्ग' => AC.genderNeut,
    _              => AC.accent,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          const SheetHandle(),

          // Header: word + gender badge
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.w, style: AT.grammarWord),
                      const SizedBox(height: 2),
                      Text(word.m,
                          style: AT.garamond(15,
                              color: AC.textSec, italic: true)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _genderColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: _genderColor.withOpacity(0.27)),
                  ),
                  child: Text(word.gender,
                      style: TextStyle(
                        fontFamily: 'TiroDevanagarSanskrit',
                        fontSize: 13, color: _genderColor,
                      )),
                ),
              ],
            ),
          ),

          // 2×2 grid
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AC.borderLight),
              ),
            ),
            child: _Grid2x2(word: word),
          ),

          // Etymology note
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Note'.toUpperCase(),
                    style: AT.garamond(10,
                        color: AC.textMuted, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Text(word.note,
                    style: AT.garamond(14,
                        color: AC.textSec, italic: true, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid2x2 extends StatelessWidget {
  final AWord word;
  const _Grid2x2({required this.word});

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('विभक्ति', word.vibhakti, false),
      ('वचन', word.vacana, false),
      ('प्रातिपदिक', word.stem, true), // Devanagari
      ('Meaning', word.m, false),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.8,
      mainAxisSpacing: 1,
      crossAxisSpacing: 1,
      children: cells.map((c) {
        final label = c.$1;
        final value = c.$2;
        final isDevanagari = c.$3;
        return Container(
          color: AC.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(),
                  style: AT.garamond(10,
                      color: AC.textMuted, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(value,
                  style: isDevanagari
                      ? AT.grammarStem
                      : AT.garamond(15, color: AC.text)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Audio Set Picker Bottom Sheet ───────────────────────────────────────────
class AudioSetPicker extends StatelessWidget {
  final AudioSet activeSet;
  final int recordedCount;
  final ValueChanged<AudioSet> onSelect;
  final VoidCallback onGoRecord;

  const AudioSetPicker({
    super.key, required this.activeSet,
    required this.recordedCount,
    required this.onSelect, required this.onGoRecord,
  });

  static Future<void> show(BuildContext context, {
    required AudioSet activeSet,
    required int recordedCount,
    required ValueChanged<AudioSet> onSelect,
    required VoidCallback onGoRecord,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AudioSetPicker(
        activeSet: activeSet, recordedCount: recordedCount,
        onSelect: onSelect, onGoRecord: onGoRecord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sets = [
      (AudioSet.defaultSet, 'Default', 'App-provided · read-only', null),
      (AudioSet.userRecordings, 'My Recordings',
          recordedCount > 0
              ? '$recordedCount pādas recorded'
              : 'No recordings yet',
          recordedCount > 0 ? recordedCount : null),
    ];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Audio Set', style: AT.garamond(16, color: AC.text)),
                Text('Select which recording to play',
                    style: AT.garamond(12,
                        color: AC.textMuted, italic: true)),
              ],
            ),
          ),
          const Divider(height: 0),

          // Set rows
          ...sets.map((s) {
            final (setId, label, sub, badge) = s;
            final isActive = activeSet == setId;
            return GestureDetector(
              onTap: () {
                onSelect(setId);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AC.borderLight)),
                ),
                child: Row(
                  children: [
                    // Radio
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isActive ? AC.accent : AC.border,
                            width: 2),
                        color: isActive ? AC.accent : Colors.transparent,
                      ),
                      child: isActive
                          ? const Center(
                              child: CircleAvatar(
                                  radius: 4,
                                  backgroundColor: AC.btnText))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: AT.garamond(16, color: AC.text)),
                          Text(sub,
                              style: AT.garamond(12,
                                  color: AC.textMuted, italic: true)),
                        ],
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 2),
                        decoration: BoxDecoration(
                          color: AC.loopActiveBg,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                              color: AC.loopActive.withOpacity(0.27)),
                        ),
                        child: Text('$badge',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AC.loopActive)),
                      ),
                  ],
                ),
              ),
            );
          }),

          // CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onGoRecord();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AC.accent, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_outlined,
                        color: AC.accent, size: 16),
                    const SizedBox(width: 8),
                    Text('Record your own pādas',
                        style: AT.garamond(15, color: AC.accent)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Repeat Panel (inside audio player) ──────────────────────────────────────
class RepeatPanel extends StatelessWidget {
  final LoopConfig config;
  final ValueChanged<LoopConfig> onChanged;

  const RepeatPanel({
    super.key, required this.config, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: AD.surfaceAlt(radius: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode tabs
          Row(
            children: [
              _ModeBtn('Verse', LoopMode.verse, config, onChanged),
              const SizedBox(width: 6),
              _ModeBtn('Pāda Range', LoopMode.padaRange, config, onChanged),
              const SizedBox(width: 6),
              _ModeBtn('Verse Set', LoopMode.verseSet, config, onChanged),
            ],
          ),
          const SizedBox(height: 12),

          // Verse mode
          if (config.mode == LoopMode.verse) ...[
            Text('Repeat the current verse continuously.',
                style: AT.garamond(12, color: AC.textMuted, italic: true)),
            const SizedBox(height: 10),
            _Row('Times',
                AStepperWidget(
                    value: config.repN, min: 1, max: 50,
                    onChanged: (v) => onChanged(config.copyWith(repN: v)))),
          ],

          // Pāda Range mode
          if (config.mode == LoopMode.padaRange) ...[
            Text('Loop between two pādas within the verse.',
                style: AT.garamond(12, color: AC.textMuted, italic: true)),
            const SizedBox(height: 10),
            _Row('From pāda',
                AStepperWidget(
                    value: config.lineA, min: 1, max: 2, small: true,
                    onChanged: (v) => onChanged(config.copyWith(
                        lineA: v.clamp(1, config.lineB))))),
            _Row('To pāda',
                AStepperWidget(
                    value: config.lineB,
                    min: config.lineA, max: 2, small: true,
                    onChanged: (v) => onChanged(config.copyWith(lineB: v)))),
            _Row('Times',
                AStepperWidget(
                    value: config.repN, min: 1, max: 50,
                    onChanged: (v) => onChanged(config.copyWith(repN: v)))),
          ],

          // Verse Set mode
          if (config.mode == LoopMode.verseSet) ...[
            Text('Cycle through a range of verses repeatedly.',
                style: AT.garamond(12, color: AC.textMuted, italic: true)),
            const SizedBox(height: 10),
            _Row('From verse',
                AStepperWidget(
                    value: config.setFrom, min: 1, max: config.setTo,
                    small: true,
                    onChanged: (v) => onChanged(config.copyWith(
                        setFrom: v.clamp(1, config.setTo))))),
            _Row('To verse',
                AStepperWidget(
                    value: config.setTo,
                    min: config.setFrom, max: 28, small: true,
                    onChanged: (v) => onChanged(config.copyWith(setTo: v)))),
            _Row('Times',
                AStepperWidget(
                    value: config.setRepN, min: 1, max: 50,
                    onChanged: (v) => onChanged(config.copyWith(setRepN: v)))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color: AC.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AC.border),
              ),
              child: Text(
                '${config.setSize} verse${config.setSize != 1 ? "s" : ""} · '
                '${config.setSize * config.setRepN} total recitations',
                style: AT.garamond(13, color: AC.textSec, italic: true),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _Row(String label, Widget trailing) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AC.borderLight)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AT.garamond(14, color: AC.textSec, italic: true)),
        trailing,
      ],
    ),
  );
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final LoopMode mode;
  final LoopConfig config;
  final ValueChanged<LoopConfig> onChanged;

  const _ModeBtn(this.label, this.mode, this.config, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final active = config.mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(config.copyWith(mode: mode)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? AC.btnBg : AC.surface,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: active ? AC.accent : AC.border),
          ),
          child: Center(
            child: Text(label,
                style: AT.garamond(13,
                    color: active ? AC.btnText : AC.textSec)),
          ),
        ),
      ),
    );
  }
}

// ─── Audio Set Manager Sheet (stub — no riverpod dependency) ────────────────
// A simple bottom sheet that just offers to go to the Recording Studio.

class AudioSetManagerSheet extends StatelessWidget {
  final VoidCallback onGoRecord;

  const AudioSetManagerSheet({super.key, required this.onGoRecord});

  static Future<void> show(BuildContext context,
      {required VoidCallback onGoRecord}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AudioSetManagerSheet(onGoRecord: onGoRecord),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.5,
      expand: false,
      builder: (_, __) => Column(children: [
        const SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Text('Audio', style: AT.garamond(18, color: AC.text,
              weight: FontWeight.w600)),
        ),
        const Divider(height: 0),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              onGoRecord();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AC.btnBg,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: AC.trackFill.withOpacity(0.25),
                    blurRadius: 12, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.mic_outlined, color: AC.btnText, size: 18),
                const SizedBox(width: 8),
                Text('Open Recording Studio',
                    style: AT.garamond(16, color: AC.btnText)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Record your own voice for any pāda. '
            'Recordings are saved locally in this browser session.',
            style: AT.garamond(12, color: AC.textMuted, italic: true,
                height: 1.5),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

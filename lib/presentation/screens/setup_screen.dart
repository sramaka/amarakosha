// lib/presentation/screens/setup_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';

class SetupScreen extends StatefulWidget {
  final Kanda kanda;
  final Varga varga;
  final VoidCallback onBack;
  final void Function(Session session) onStart;

  const SetupScreen({
    super.key,
    required this.kanda, required this.varga,
    required this.onBack, required this.onStart,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _verseFrom = 1;
  late int _verseTo;
  PracticeMode _mode = PracticeMode.listen;
  int _repeatN = 1;

  @override
  void initState() {
    super.initState();
    _verseTo = widget.varga.verses;
  }

  int get _verseCount => _verseTo - _verseFrom + 1;
  int get _totalRecitations => _verseCount * _repeatN;

  String get _modeDesc => switch (_mode) {
    PracticeMode.listen  => 'You will listen to ',
    PracticeMode.recite  => 'You will recite ',
    PracticeMode.guided  => 'You will work through ',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── NAV ─────────────────────────────────────────────────────────
        ANavBar(
          backLabel: 'Back',
          onBack: widget.onBack,
          title: 'Set up Practice',
        ),

        // ── SCROLLABLE BODY ───────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Varga header card ──────────────────────────────────
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AD.card(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ABreadcrumb(
                          kandaNum: widget.kanda.num,
                          vargaNum: widget.varga.num),
                      const SizedBox(height: 4),
                      Text(widget.varga.name,
                          style: AT.devanagari22),
                      Text(
                          '${widget.kanda.nameEn} · ${widget.varga.nameEn}',
                          style: AT.garamond(13,
                              color: AC.textSec, italic: true)),
                      const SizedBox(height: 10),
                      Text('${widget.varga.verses} verses total',
                          style: AT.garamond(12, color: AC.textMuted)),
                    ],
                  ),
                ),

                // ── Verse Range ────────────────────────────────────────
                const SizedBox(height: 18),
                SectionLabel('Verse Range'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AC.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.border),
                  ),
                  child: Column(
                    children: [
                      SettingRow(
                        label: 'From verse',
                        trailing: AStepperWidget(
                          value: _verseFrom,
                          min: 1, max: _verseTo, small: true,
                          onChanged: (v) => setState(() =>
                              _verseFrom = v.clamp(1, _verseTo)),
                        ),
                      ),
                      SettingRow(
                        label: 'To verse',
                        sub: '$_verseCount verse${_verseCount != 1 ? "s" : ""} selected',
                        trailing: AStepperWidget(
                          value: _verseTo,
                          min: _verseFrom,
                          max: widget.varga.verses,
                          small: true,
                          onChanged: (v) => setState(() => _verseTo = v),
                        ),
                        last: true,
                      ),
                    ],
                  ),
                ),

                // ── Practice Mode ──────────────────────────────────────
                const SizedBox(height: 18),
                SectionLabel('Practice Mode'),
                Row(
                  children: [
                    _ModeCard(
                      k: PracticeMode.listen,
                      title: 'Listen',
                      desc: 'Full verse visible · audio plays',
                      selected: _mode == PracticeMode.listen,
                      onTap: () => setState(() => _mode = PracticeMode.listen),
                    ),
                    const SizedBox(width: 8),
                    _ModeCard(
                      k: PracticeMode.recite,
                      title: 'Recite',
                      desc: 'Pādas hidden · reveal after attempt',
                      selected: _mode == PracticeMode.recite,
                      onTap: () => setState(() => _mode = PracticeMode.recite),
                    ),
                    const SizedBox(width: 8),
                    _ModeCard(
                      k: PracticeMode.guided,
                      title: 'Guided',
                      desc: 'One pāda at a time · call & response',
                      selected: _mode == PracticeMode.guided,
                      onTap: () => setState(() => _mode = PracticeMode.guided),
                    ),
                  ],
                ),

                // ── Repetitions ────────────────────────────────────────
                const SizedBox(height: 18),
                SectionLabel('Repetitions'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AC.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.border),
                  ),
                  child: SettingRow(
                    label: 'Repeat entire set',
                    sub: '$_totalRecitations total recitations',
                    trailing: AStepperWidget(
                      value: _repeatN, min: 1, max: 20,
                      onChanged: (v) => setState(() => _repeatN = v),
                    ),
                    last: true,
                  ),
                ),

                // ── Session summary ────────────────────────────────────
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                  decoration: AD.surfaceAlt(radius: 10),
                  child: RichText(
                    text: TextSpan(
                      style: AT.garamond(13, color: AC.textSec, italic: true,
                          height: 1.7),
                      children: [
                        TextSpan(text: _modeDesc),
                        TextSpan(
                            text: '$_verseCount verse${_verseCount != 1 ? "s" : ""}',
                            style: AT.garamond(13, color: AC.text,
                                weight: FontWeight.w600)),
                        const TextSpan(text: ' (श्लोक '),
                        TextSpan(
                            text: '$_verseFrom–$_verseTo',
                            style: AT.garamond(13, color: AC.text,
                                weight: FontWeight.w600)),
                        const TextSpan(text: ') '),
                        TextSpan(
                            text: '${_repeatN}×',
                            style: AT.garamond(13, color: AC.text,
                                weight: FontWeight.w600)),
                        const TextSpan(text: ' — '),
                        TextSpan(
                            text: '$_totalRecitations',
                            style: AT.garamond(13, color: AC.text,
                                weight: FontWeight.w600)),
                        const TextSpan(text: ' total recitations.'),
                      ],
                    ),
                  ),
                ),

                // ── Start button ───────────────────────────────────────
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => widget.onStart(Session(
                    kanda: widget.kanda,
                    varga: widget.varga,
                    verseFrom: _verseFrom,
                    verseTo: _verseTo,
                    mode: _mode,
                    repeatN: _repeatN,
                  )),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: AC.btnBg,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: AC.trackFill.withOpacity(0.27),
                            blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: Text('Start Practice',
                          style: AT.garamond(18, color: AC.btnText,
                              letterSpacing: 0.2)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final PracticeMode k;
  final String title;
  final String desc;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.k, required this.title, required this.desc,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AC.btnBg : AC.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AC.accent : AC.border,
              width: selected ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: AT.garamond(15,
                    color: selected ? AC.btnText : AC.textSec)),
            const SizedBox(height: 3),
            Text(desc,
                textAlign: TextAlign.center,
                style: AT.garamond(11,
                    color: selected
                        ? AC.btnText.withOpacity(0.8)
                        : AC.textMuted,
                    italic: true,
                    height: 1.3)),
          ],
        ),
      ),
    ),
  );
}

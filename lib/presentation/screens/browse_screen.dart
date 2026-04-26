// lib/presentation/screens/browse_screen.dart (v3 model)
// Shows: Kanda accordion → Varga list → tap to enter practice

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/app_settings.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(Kanda kanda, Varga varga) onSelectVarga;

  const BrowseScreen({super.key, required this.onBack, required this.onSelectVarga});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  // Async-loaded kandas for full data; falls back to bootstrap until loaded
  List<Kanda> _kandas = kBootstrapKandas;
  bool _loaded = false;
  int? _expandedKanda = 1;

  @override
  void initState() {
    super.initState();
    loadKandas().then((k) {
      if (mounted) setState(() { _kandas = k; _loaded = true; });
    });
    AppSettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  @override
  Widget build(BuildContext context) => Column(children: [
    ANavBar(
      backLabel: 'Home', onBack: widget.onBack,
      title: 'Browse', subtitle: 'Select a Varga to practise',
    ),
    Expanded(child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: _kandas.map(_buildKanda).toList(),
    )),
  ]);

  Widget _buildKanda(Kanda kanda) {
    final isOpen = _expandedKanda == kanda.num;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        // ── Kanda header ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() =>
              _expandedKanda = isOpen ? null : kanda.num),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: BoxDecoration(
              color: isOpen ? AC.surfaceAlt : AC.surface,
              borderRadius: isOpen
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              border: Border.all(color: AC.border),
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: isOpen ? AC.btnBg : AC.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isOpen ? AC.btnBg : AC.border)),
                child: Center(child: Text('${kanda.num}', style: TextStyle(
                    fontFamily: 'TiroDevanagarSanskrit', fontSize: 16,
                    color: isOpen ? AC.btnText : AC.accent))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(kanda.name, style: const TextStyle(
                      fontFamily: 'TiroDevanagarSanskrit', fontSize: 16, color: AC.text)),
                  Text('${kanda.totalPadas} pādas',
                      style: AT.garamond(
                          (AppSettings.instance.uiFontSize - 2).toDouble(),
                          color: AC.textSec)),
                ]),
                Text(kanda.nameEn, style: AT.garamond(
                    (AppSettings.instance.uiFontSize - 1).toDouble(),
                    color: AC.textSec, italic: true)),
                const SizedBox(height: 5),
                const AProgressBar(value: 0),
              ])),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down, color: AC.textSec, size: 20),
              ),
            ]),
          ),
        ),

        // ── Varga list ────────────────────────────────────────────────────
        if (isOpen)
          Container(
            decoration: BoxDecoration(
              color: AC.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: const Border(
                left: BorderSide(color: AC.border), right: BorderSide(color: AC.border),
                bottom: BorderSide(color: AC.border)),
            ),
            child: Column(children: kanda.vargas.asMap().entries.map((e) {
              final isLast = e.key == kanda.vargas.length - 1;
              final varga = e.value;
              // Count only sections with actual text
              final sectionsWithText = varga.sections.where((s) => s.hasText).length;
              return GestureDetector(
                onTap: () => widget.onSelectVarga(kanda, varga),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  decoration: BoxDecoration(border: isLast
                      ? null
                      : const Border(bottom: BorderSide(color: AC.borderLight))),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(color: AC.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AC.border)),
                      child: Center(child: Text('${varga.seq}', style: const TextStyle(
                          fontSize: 11, color: AC.textSec, fontFamily: 'system-ui'))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(varga.name, style: const TextStyle(
                            fontFamily: 'TiroDevanagarSanskrit', fontSize: 15, color: AC.text)),
                        Text('${varga.totalPadas} pādas',
                            style: AT.garamond(
                                (AppSettings.instance.uiFontSize - 2).toDouble(),
                                color: AC.textSec)),
                      ]),
                      Text(
                        '${varga.sections.length} sections'
                        '${sectionsWithText > 0 ? ' · $sectionsWithText with text' : ''}',
                        style: AT.garamond(
                            (AppSettings.instance.uiFontSize - 2).toDouble(),
                            color: AC.textSec, italic: true),
                      ),
                    ])),
                    const SizedBox(width: 8),
                    const AChevRight(),
                  ]),
                ),
              );
            }).toList()),
          ),
      ]),
    );
  }
}

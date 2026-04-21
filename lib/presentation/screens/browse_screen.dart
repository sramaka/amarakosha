// lib/presentation/screens/browse_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';

class BrowseScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(Kanda kanda, Varga varga) onSelectVarga;

  const BrowseScreen({
    super.key, required this.onBack, required this.onSelectVarga,
  });

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int? _expandedKanda = 1; // first open by default

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── NAV ─────────────────────────────────────────────────────────
        ANavBar(
          backLabel: 'Home',
          onBack: widget.onBack,
          title: 'Browse',
          subtitle: 'Select a Varga to practise',
        ),

        // ── KĀṆḌA ACCORDION LIST ─────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: kKandas.map((kanda) {
              final isOpen = _expandedKanda == kanda.num;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    // Kāṇḍa header
                    GestureDetector(
                      onTap: () => setState(() =>
                          _expandedKanda = isOpen ? null : kanda.num),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                        decoration: BoxDecoration(
                          color: isOpen ? AC.surfaceAlt : AC.surface,
                          borderRadius: isOpen
                              ? const BorderRadius.vertical(
                                  top: Radius.circular(12))
                              : BorderRadius.circular(12),
                          border: Border.all(color: AC.border),
                        ),
                        child: Row(
                          children: [
                            // Number badge
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38, height: 38,
                              decoration: BoxDecoration(
                                color: isOpen ? AC.btnBg : AC.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isOpen ? AC.btnBg : AC.border),
                              ),
                              child: Center(
                                child: Text('${kanda.num}',
                                    style: TextStyle(
                                      fontFamily: 'TiroDevanagarSanskrit',
                                      fontSize: 16,
                                      color: isOpen ? AC.btnText : AC.accent,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name + stats
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(kanda.name,
                                          style: const TextStyle(
                                            fontFamily:
                                                'TiroDevanagarSanskrit',
                                            fontSize: 16,
                                            color: AC.text,
                                          )),
                                      Text('${kanda.totalVerses} verses',
                                          style: AT.garamond(11,
                                              color: AC.textMuted)),
                                    ],
                                  ),
                                  Text(kanda.nameEn,
                                      style: AT.garamond(12,
                                          color: AC.textSec, italic: true)),
                                  const SizedBox(height: 5),
                                  AProgressBar(value: 0),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Animated chevron
                            AnimatedRotation(
                              turns: isOpen ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down,
                                  color: AC.textMuted, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Varga list (expanded)
                    if (isOpen)
                      Container(
                        decoration: BoxDecoration(
                          color: AC.surface,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12)),
                          border: Border(
                            left: BorderSide(color: AC.border),
                            right: BorderSide(color: AC.border),
                            bottom: BorderSide(color: AC.border),
                          ),
                        ),
                        child: Column(
                          children: kanda.vargas.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final varga = entry.value;
                            final isLast =
                                idx == kanda.vargas.length - 1;
                            return GestureDetector(
                              onTap: () => widget.onSelectVarga(kanda, varga),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 12, 16, 12),
                                decoration: BoxDecoration(
                                  border: isLast
                                      ? null
                                      : const Border(
                                          bottom: BorderSide(
                                              color: AC.borderLight)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: AC.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(color: AC.border),
                                      ),
                                      child: Center(
                                        child: Text('${varga.num}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AC.textMuted,
                                                fontFamily: 'system-ui')),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(varga.name,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        'TiroDevanagarSanskrit',
                                                    fontSize: 15,
                                                    color: AC.text,
                                                  )),
                                              Text('${varga.verses} verses',
                                                  style: AT.garamond(11,
                                                      color: AC.textMuted)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const AChevRight(),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

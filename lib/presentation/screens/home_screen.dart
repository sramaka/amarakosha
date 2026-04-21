// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/static_data.dart';
import '../widgets/shared_widgets.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const HomeScreen({super.key, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    final lastKanda = kKandas[0];
    final lastVarga = lastKanda.vargas[0];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AC.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('अमरकोश',
                    style: const TextStyle(
                      fontFamily: 'TiroDevanagarSanskrit',
                      fontSize: 22, color: AC.text, height: 1.2,
                    )),
                Text('Amarakosha Practice'.toUpperCase(),
                    style: AT.garamond(12,
                        color: AC.textMuted, letterSpacing: 1.0)),
              ],
            ),
          ),

          // ── RESUME CARD ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Continue where you left off'.toUpperCase(),
                    style: AT.garamond(10,
                        color: AC.textMuted, letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  decoration: AD.card(radius: 16),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ABreadcrumb(
                                    kandaNum: lastKanda.num,
                                    vargaNum: lastVarga.num),
                                const SizedBox(height: 3),
                                Text(lastVarga.name,
                                    style: AT.devanagari20),
                                Text(
                                    '${lastKanda.nameEn} · ${lastVarga.nameEn}',
                                    style: AT.garamond(13,
                                        color: AC.textSec, italic: true)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AC.chipBg,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: AC.border),
                            ),
                            child: Text('${lastVarga.verses} verses',
                                style: AT.garamond(11,
                                    color: AC.chipText)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const AProgressBar(value: 0),
                      const SizedBox(height: 14),
                      AButton(
                          label: 'Continue Practice',
                          onTap: onBrowse,
                          radius: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── STATS ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                _StatCard(
                    label: 'Total verses',
                    value: kTotalVerses,
                    sub: 'across all kāṇḍas'),
                const SizedBox(width: 10),
                _StatCard(
                    label: 'Vargas',
                    value: kTotalVargas,
                    sub: 'to practise'),
              ],
            ),
          ),

          // ── KĀṆḌA LIST ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All Kāṇḍas'.toUpperCase(),
                    style: AT.garamond(10,
                        color: AC.textMuted, letterSpacing: 1.0)),
                const SizedBox(height: 10),
                ...kKandas.map((kanda) => _KandaRow(
                      kanda: kanda,
                      onTap: onBrowse,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final String sub;
  const _StatCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: AT.stats28),
          const SizedBox(height: 3),
          Text(label, style: AT.garamond(12, color: AC.textSec)),
          Text(sub, style: AT.garamond(11, color: AC.textMuted, italic: true)),
        ],
      ),
    ),
  );
}

class _KandaRow extends StatelessWidget {
  final dynamic kanda;
  final VoidCallback onTap;
  const _KandaRow({required this.kanda, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AC.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AC.border),
            ),
            child: Center(
              child: Text('${kanda.num}',
                  style: const TextStyle(
                      fontFamily: 'TiroDevanagarSanskrit',
                      fontSize: 16, color: AC.accent)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(kanda.name,
                        style: const TextStyle(
                            fontFamily: 'TiroDevanagarSanskrit',
                            fontSize: 16, color: AC.text)),
                    Text('${kanda.totalVerses} verses',
                        style: AT.garamond(12, color: AC.textMuted)),
                  ],
                ),
                Text('${kanda.vargas.length} vargas',
                    style: AT.garamond(12,
                        color: AC.textSec, italic: true)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const AChevRight(),
        ],
      ),
    ),
  );
}

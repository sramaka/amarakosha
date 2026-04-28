// lib/presentation/screens/home_screen.dart (v3 model)

import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/settings/app_settings.dart';
import '../../data/repositories/static_data.dart';
import '../widgets/shared_widgets.dart';

@JS('open')
external void _jsOpen(JSString url, JSString target);

void _openUrl(String url) {
  if (kIsWeb) _jsOpen(url.toJS, '_blank'.toJS);
}

class HomeScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const HomeScreen({super.key, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final kanda = kKandas[0];
    final varga = kanda.vargas[0];

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AC.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('अमरकोश', style: TextStyle(
                  fontFamily: 'TiroDevanagarSanskrit',
                  fontSize: 22, color: AC.text, height: 1.2)),
              Text('Amarakosha Practice'.toUpperCase(),
                  style: AT.garamond(
                      (AppSettings.instance.uiFontSize - 2).toDouble(),
                      color: AC.textSec, letterSpacing: 1.0,
                      weight: AppSettings.instance.fontWeight)),
            ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _NavLink(label: 'Studio', onTap: () => _openUrl('recorder.html')),
              const SizedBox(width: 6),
              _NavLink(label: 'Help', onTap: () => _openUrl('help.html')),
            ]),
          ]),
        ),

        // ── Resume card ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Continue where you left off'.toUpperCase(),
                style: AT.garamond(
                    (AppSettings.instance.uiFontSize - 2).toDouble(),
                    color: AC.textSec, weight: AppSettings.instance.fontWeight,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Container(
              decoration: AD.card(radius: 16),
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ABreadcrumb(kandaNum: kanda.num, vargaSeq: varga.seq),
                    const SizedBox(height: 3),
                    Text(varga.name, style: AT.devanagari20),
                    Text(kanda.nameEn, style: AT.garamond(
                        AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textSec, italic: true)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AC.chipBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AC.border)),
                    child: Text('${varga.totalPadas} pādas',
                        style: AT.garamond(
                            (AppSettings.instance.uiFontSize - 2).toDouble(),
                            color: AC.chipText)),
                  ),
                ]),
                const SizedBox(height: 12),
                const AProgressBar(value: 0),
                const SizedBox(height: 14),
                AButton(label: 'Continue Practice', onTap: onBrowse, radius: 10),
              ]),
            ),
          ]),
        ),

        // ── Stats ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            _StatCard(label: 'Total Pādas',   value: kTotalPadas,    sub: 'across all kāṇḍas'),
            const SizedBox(width: 10),
            _StatCard(label: 'Sections',      value: kTotalSections, sub: 'semantic groups'),
            const SizedBox(width: 10),
            _StatCard(label: 'Vargas',        value: kTotalVargas,   sub: 'to practise'),
          ]),
        ),

        // ── Kānda list ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All Kāṇḍas'.toUpperCase(),
                style: AT.garamond(
                    (AppSettings.instance.uiFontSize - 2).toDouble(),
                    color: AC.textSec, weight: AppSettings.instance.fontWeight,
                    letterSpacing: 1.0)),
            const SizedBox(height: 10),
            ...kKandas.map((k) => _KandaRow(kanda: k, onTap: onBrowse)),
          ]),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, sub;
  final int value;
  const _StatCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: AC.surface,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value', style: AT.stats28),
        const SizedBox(height: 2),
        Text(label, style: AT.garamond(
            (AppSettings.instance.uiFontSize - 2).toDouble(), color: AC.textSec)),
        Text(sub, style: AT.garamond(
            (AppSettings.instance.uiFontSize - 3).clamp(9, 99).toDouble(),
            color: AC.textMuted, italic: true)),
      ]),
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
      decoration: BoxDecoration(color: AC.surface,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: AC.surfaceAlt,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.border)),
          child: Center(child: Text('${kanda.num}', style: const TextStyle(
              fontFamily: 'TiroDevanagarSanskrit', fontSize: 16, color: AC.accent))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(kanda.name, style: const TextStyle(
                fontFamily: 'TiroDevanagarSanskrit', fontSize: 16, color: AC.text)),
            Text('${kanda.totalPadas} pādas',
                style: AT.garamond(
                    (AppSettings.instance.uiFontSize - 2).toDouble(),
                    color: AC.textMuted)),
          ]),
          Text('${kanda.vargas.length} vargas',
              style: AT.garamond(
                  (AppSettings.instance.uiFontSize - 1).toDouble(),
                  color: AC.textSec, italic: true)),
        ])),
        const SizedBox(width: 8),
        const AChevRight(),
      ]),
    ),
  );
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AC.border)),
      child: Text(label, style: AT.garamond(12, color: AC.textMuted)),
    ),
  );
}

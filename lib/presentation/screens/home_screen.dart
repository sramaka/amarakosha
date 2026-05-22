// lib/presentation/screens/home_screen.dart (v3 model)

import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final VoidCallback                onBrowse;
  final void Function(int setIdx)   onContinuePractice;
  final VoidCallback                onNewPracticeSet;

  const HomeScreen({
    super.key,
    required this.onBrowse,
    required this.onContinuePractice,
    required this.onNewPracticeSet,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final fs = AppSettings.instance.uiFontSize.toDouble();

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 14),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AC.border))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('अमरकोशः', style: TextStyle(
                  fontFamily: 'TiroDevanagarSanskrit',
                  fontSize: 26, color: AC.text, height: 1.2)),
              Text('Amarakosha Practice'.toUpperCase(),
                  style: AT.garamond(
                      (fs - 2).clamp(10, 99),
                      color: AC.textSec, letterSpacing: 1.0,
                      weight: AppSettings.instance.fontWeight)),
            ])),
            GestureDetector(
              onTap: () => _openUrl('landing.html'),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AC.textMuted),
                  const SizedBox(width: 4),
                  Text('About', style: AT.garamond(12, color: AC.textMuted)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Action tiles ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            _ActionTile(
              icon: Icons.menu_book_outlined,
              label: 'Browse',
              description: 'Explore the Amarakosha text',
              onTap: onBrowse,
            ),
            _ActionTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'Continue Practicing',
              description: 'Resume from a saved practice set',
              onTap: () => _showContinueSheet(context),
            ),
            _ActionTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Create New Practice Set',
              description: 'Start a new drill session',
              onTap: onNewPracticeSet,
            ),
            _ActionTile(
              icon: Icons.mic_none_rounded,
              label: 'Recording Studio',
              description: 'Record your recitation',
              onTap: () => _openUrl('recorder.html'),
            ),
            _ActionTile(
              icon: Icons.help_outline_rounded,
              label: 'Help',
              description: 'How to use this app',
              onTap: () => _openUrl('help.html'),
            ),
          ]),
        ),

        // ── Stats ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(children: [
            _StatCard(label: 'Total Pādas',  value: kTotalPadas,    sub: 'across all kāṇḍas'),
            const SizedBox(width: 10),
            _StatCard(label: 'Sections',     value: kTotalSections, sub: 'semantic groups'),
            const SizedBox(width: 10),
            _StatCard(label: 'Vargas',       value: kTotalVargas,   sub: 'to practise'),
          ]),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }

  // ── Practice-set picker sheet ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _loadSets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('amarakosha_practice_sets_v2');
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      return data.map<Map<String, dynamic>>((s) {
        int padaCount = 0;
        for (final item in (s['items'] as List<dynamic>)) {
          padaCount += (item['ids'] as List<dynamic>).length;
        }
        return {'name': s['name'] as String, 'count': padaCount};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _showContinueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadSets(),
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()));
          }
          final sets = snap.data ?? [];
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AC.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Practice Set'.toUpperCase(),
                    style: AT.garamond(12, color: AC.textMuted, letterSpacing: 1.0)),
              ),
            ),
            if (sets.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Text(
                  'No practice sets yet. Browse the text and long-press a section or pāda to add it to a set.',
                  style: AT.garamond(14, color: AC.textMuted, italic: true, height: 1.5),
                ),
              )
            else ...[
              ...sets.asMap().entries.map((e) => _SetTile(
                name: e.value['name'] as String,
                count: e.value['count'] as int,
                onTap: () {
                  Navigator.pop(ctx);
                  onContinuePractice(e.key);
                },
              )),
              const SizedBox(height: 16),
            ],
          ]);
        },
      ),
    );
  }
}

// ─── Action tile ──────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final String       description;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fs = AppSettings.instance.uiFontSize.toDouble();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.border),
        ),
        child: Row(children: [
          Icon(icon, size: 22, color: AC.accent),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AT.garamond(fs, color: AC.text,
                weight: FontWeight.w600)),
            Text(description, style: AT.garamond(
                (fs - 2).clamp(10, 99), color: AC.textMuted, italic: true)),
          ])),
          const AChevRight(),
        ]),
      ),
    );
  }
}

// ─── Practice set tile (in sheet) ────────────────────────────────────────────
class _SetTile extends StatelessWidget {
  final String       name;
  final int          count;
  final VoidCallback onTap;
  const _SetTile({required this.name, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fs = AppSettings.instance.uiFontSize.toDouble();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        decoration: BoxDecoration(
          color: AC.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AC.border),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: AT.garamond(fs, color: AC.text)),
            Text('$count pāda${count == 1 ? '' : 's'}',
                style: AT.garamond((fs - 2).clamp(10, 99),
                    color: AC.textMuted, italic: true)),
          ])),
          const AChevRight(),
        ]),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, sub;
  final int    value;
  const _StatCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    final fs = AppSettings.instance.uiFontSize.toDouble();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: AT.stats28),
          const SizedBox(height: 2),
          Text(label, style: AT.garamond((fs - 2).clamp(10, 99), color: AC.textSec)),
          Text(sub,   style: AT.garamond((fs - 3).clamp(9, 99),
              color: AC.textMuted, italic: true)),
        ]),
      ),
    );
  }
}

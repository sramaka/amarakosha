// lib/main.dart — app shell for Amarakosha Practice (v3 model)

import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/entities.dart';
import 'data/repositories/static_data.dart';
import 'data/repositories/recording_store.dart';
import 'data/repositories/audio_service.dart';
import 'core/settings/app_settings.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/browse_screen.dart';
import 'presentation/screens/practice_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  await RecordingStore.instance.restoreAll();
  await AppSettings.instance.load();
  unawaited(AudioService.instance.preloadManifest());
  runApp(const AmarakoshaApp());
}

class AmarakoshaApp extends StatelessWidget {
  const AmarakoshaApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppSettings.instance,
    builder: (_, __) => MaterialApp(
      title: 'अमरकोशः',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppShell(),
    ),
  );
}

// ─── App shell ────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;  // 0=Home  1=Browse
  final List<Widget> _stack = [];

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  Session get _defaultSession {
    final kanda   = kBootstrapKandas.first;
    final varga   = kanda.vargas.first;
    final section = varga.sections.first;
    return Session(kanda: kanda, varga: varga, section: section, repeatN: 1);
  }

  void _push(Widget w) => setState(() => _stack.add(w));
  void _pop()          => setState(() { if (_stack.isNotEmpty) _stack.removeLast(); });

  void _onSelectVarga(Kanda kanda, Varga varga) {
    final section = varga.sections.isNotEmpty ? varga.sections.first : kBootstrapSection;
    _push(PracticeScreen(
      session: Session(kanda: kanda, varga: varga, section: section, repeatN: 1),
      onBack: _pop,
    ));
  }

  void _onContinuePractice(int setIdx) {
    _push(PracticeScreen(
      session: _defaultSession,
      onBack: _pop,
      initialSetIdx: setIdx,
      showSetPanel: true,
    ));
  }

  void _onBrowse() {
    _push(PracticeScreen(
      session: _defaultSession,
      onBack: _pop,
    ));
  }

  void _onNewPracticeSet() {
    _push(PracticeScreen(
      session: _defaultSession,
      onBack: _pop,
      startWithNewSet: true,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_stack.isNotEmpty) {
      return Scaffold(backgroundColor: AC.bg, body: SafeArea(child: _stack.last));
    }
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Expanded(child: IndexedStack(
            index: _tabIndex,
            children: [
              HomeScreen(
                onBrowse: _onBrowse,
                onContinuePractice: _onContinuePractice,
                onNewPracticeSet: _onNewPracticeSet,
              ),
              BrowseScreen(
                onBack: () => setState(() => _tabIndex = 0),
                onSelectVarga: _onSelectVarga,
              ),
            ],
          )),
          _TabBar(
            current: _tabIndex,
            onTap: (i) {
              if (i == 1) { _onBrowse(); }
              else { setState(() => _tabIndex = i); }
            },
          ),
        ]),
      ),
    );
  }
}

// ─── Tab bar ──────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _TabBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AC.surface,
      border: Border(top: BorderSide(color: AC.border)),
    ),
    child: SafeArea(
      top: false,
      child: Row(children: [
        _Tab(icon: Icons.home_outlined,      iconActive: Icons.home_rounded,
             label: 'Home',   active: current == 0, onTap: () => onTap(0)),
        _Tab(icon: Icons.menu_book_outlined, iconActive: Icons.menu_book_rounded,
             label: 'Browse', active: current == 1, onTap: () => onTap(1)),
      ]),
    ),
  );
}

class _Tab extends StatelessWidget {
  final IconData icon, iconActive;
  final String   label;
  final bool     active;
  final VoidCallback onTap;
  const _Tab({required this.icon, required this.iconActive,
              required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? iconActive : icon,
              color: active ? AC.accent : AC.textMuted, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontFamily: 'system-ui', fontSize: 10,
            color: active ? AC.accent : AC.textMuted,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      ),
    ),
  );
}

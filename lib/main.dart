// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'domain/entities/entities.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/browse_screen.dart';
import 'presentation/screens/setup_screen.dart';
import 'presentation/screens/practice_screen.dart';
import 'presentation/screens/recording_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const AmarakoshaApp());
}

class AmarakoshaApp extends StatelessWidget {
  const AmarakoshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'अमरकोश',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppShell(),
    );
  }
}

// ─── App shell with tab bar + screen stack ────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Which tab is active
  int _tabIndex = 0; // 0 = Home, 1 = Browse

  // Navigation stack above the tabs (Setup, Practice, Recording)
  // When this is non-empty, tab bar is hidden
  final List<Widget> _stack = [];

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _push(Widget screen) => setState(() => _stack.add(screen));
  void _pop() => setState(() { if (_stack.isNotEmpty) _stack.removeLast(); });

  void _onSelectVarga(Kanda kanda, Varga varga) {
    _push(SetupScreen(
      kanda: kanda,
      varga: varga,
      onBack: _pop,
      onStart: (session) {
        _push(PracticeScreen(
          session: session,
          onBack: _pop,
          onGoRecord: () {
            _push(RecordingScreen(
              session: session,
              onBack: _pop,
            ));
          },
        ));
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    // When a modal screen is on the stack, show it full-screen (no tab bar)
    if (_stack.isNotEmpty) {
      return Scaffold(
        backgroundColor: AC.bg,
        body: SafeArea(child: _stack.last),
      );
    }

    // Otherwise show the tab layout
    return Scaffold(
      backgroundColor: AC.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  // Home tab
                  HomeScreen(
                    onBrowse: () => setState(() => _tabIndex = 1),
                  ),
                  // Browse tab
                  BrowseScreen(
                    onBack: () => setState(() => _tabIndex = 0),
                    onSelectVarga: _onSelectVarga,
                  ),
                ],
              ),
            ),
            // Tab bar
            _TabBar(
              current: _tabIndex,
              onTap: (i) => setState(() => _tabIndex = i),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab bar ─────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _TabBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AC.surface,
        border: Border(top: BorderSide(color: AC.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _Tab(
              icon: Icons.home_outlined,
              iconActive: Icons.home_rounded,
              label: 'Home',
              active: current == 0,
              onTap: () => onTap(0),
            ),
            _Tab(
              icon: Icons.menu_book_outlined,
              iconActive: Icons.menu_book_rounded,
              label: 'Browse',
              active: current == 1,
              onTap: () => onTap(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final IconData iconActive;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.icon, required this.iconActive,
    required this.label, required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? iconActive : icon,
                color: active ? AC.accent : AC.textMuted,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'system-ui',
                  fontSize: 10,
                  color: active ? AC.accent : AC.textMuted,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

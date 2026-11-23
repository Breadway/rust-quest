import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'models.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'sync_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final source = await rootBundle.loadString('assets/curriculum.json');
  final curriculum = Curriculum.fromJsonString(source);
  final state = await AppState.load(curriculum);
  final sync = SyncService(state);
  if (state.syncConfigured) unawaited(sync.syncNow());
  runApp(RustQuestApp(state: state, sync: sync));
}

class RustQuestApp extends StatelessWidget {
  const RustQuestApp({super.key, required this.state, required this.sync});

  final AppState state;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rust Quest',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: RootShell(state: state, sync: sync),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state, required this.sync});

  final AppState state;
  final SyncService sync;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final extendedRail = constraints.maxWidth >= 1280;
        final pages = IndexedStack(
          index: _index,
          children: [
            HomeScreen(state: widget.state),
            ProfileScreen(state: widget.state, sync: widget.sync),
          ],
        );
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  backgroundColor: kSurface,
                  extended: extendedRail,
                  minExtendedWidth: 190,
                  labelType: extendedRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      extendedRail ? 'Rust Quest 🦀' : '🦀',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school, color: kPrimary),
                      label: Text('Learn'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded, color: kPrimary),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1, color: kSurfaceAlt),
                Expanded(child: pages),
              ],
            ),
          );
        }
        return Scaffold(
          body: pages,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: kSurface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: kPrimary.withValues(alpha: .18),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school, color: kPrimary),
                label: 'Learn',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded, color: kPrimary),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

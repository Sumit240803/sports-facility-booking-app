import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../widgets/async_view.dart';
import 'admin/admin_screen.dart';
import 'bookings_screen.dart';
import 'explore_screen.dart';
import 'manage/my_venues_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      context.profileStore.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.profileStore;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final profile = store.profile;
        if (profile == null) {
          return Scaffold(
            body: store.error == null
                ? const Center(child: CircularProgressIndicator())
                : MessageView(
                    icon: Icons.cloud_off,
                    title: 'Couldn\'t load your profile',
                    message: '${store.error}',
                    action: FilledButton.tonal(onPressed: store.load, child: const Text('Retry')),
                  ),
          );
        }
        if (!profile.isOnboarded) return const OnboardingScreen();

        final pages = <(NavigationDestination, Widget)>[
          (
            const NavigationDestination(
                icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
            const ExploreScreen(),
          ),
          (
            const NavigationDestination(
                icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Bookings'),
            const BookingsScreen(),
          ),
          if (profile.canOwnVenues)
            (
              const NavigationDestination(
                  icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Manage'),
              const MyVenuesScreen(),
            ),
          if (profile.isAdmin)
            (
              const NavigationDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: 'Admin'),
              const AdminScreen(),
            ),
          (
            const NavigationDestination(
                icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            const ProfileScreen(),
          ),
        ];
        final index = _index.clamp(0, pages.length - 1);

        return Scaffold(
          body: IndexedStack(index: index, children: [for (final p in pages) p.$2]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [for (final p in pages) p.$1],
          ),
        );
      },
    );
  }
}

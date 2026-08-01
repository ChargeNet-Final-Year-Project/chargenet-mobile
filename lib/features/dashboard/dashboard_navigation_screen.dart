import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/activity/activity_screen.dart';
import 'package:chargenet_mobile/features/charging/active_charging_screen.dart';
import 'package:chargenet_mobile/features/dashboard/widgets/charging_mini_bar.dart';
import 'package:chargenet_mobile/features/home/home_screen.dart';
import 'package:chargenet_mobile/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';

class DashboardNavigationScreen extends StatefulWidget {
  const DashboardNavigationScreen({super.key});

  @override
  State<DashboardNavigationScreen> createState() =>
      _DashboardNavigationScreenState();
}

class _DashboardNavigationScreenState extends State<DashboardNavigationScreen> {
  int _selectedIndex = dashboardTabNotifier.value.index;

  final List<Widget> _pages = [
    HomeScreen(),
    const ActivityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Any screen can ask for a tab through this notifier — the live monitor
    // sends the driver to Activity once a session ends.
    dashboardTabNotifier.addListener(_followRequestedTab);
  }

  @override
  void dispose() {
    dashboardTabNotifier.removeListener(_followRequestedTab);
    super.dispose();
  }

  void _followRequestedTab() {
    final requested = dashboardTabNotifier.value.index;
    if (!mounted || requested == _selectedIndex) return;

    setState(() => _selectedIndex = requested);
  }

  void _selectTab(int index) {
    setState(() => _selectedIndex = index);
    // Keep the notifier in step so the next deep link starts from here and the
    // listener above does not fire an identical setState.
    dashboardTabNotifier.value = DashboardTab.values[index];
  }

  /// The monitor reads the session from the notifier, so a stale mini-bar tap
  /// (the session ended between the last frame and the tap) is simply ignored.
  void _openMonitor() {
    final session = activeSessionNotifier.value;
    if (session == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ActiveChargingScreen(session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The persistent "still charging" strip: on every
          // tab while a session runs, gone the moment the monitor clears the
          // notifier.
          ValueListenableBuilder<ChargingSession?>(
            valueListenable: activeSessionNotifier,
            builder: (context, session, child) => session == null
                ? const SizedBox.shrink()
                : ChargingMiniBar(session: session, onTap: _openMonitor),
          ),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.near_me_outlined),
                selectedIcon: Icon(Icons.near_me),
                label: "Home",
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: "Activity",
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: "Profile",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

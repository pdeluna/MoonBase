import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonbase_skeleton/features/chat/presentation/screens/chat_screen.dart';
import 'package:moonbase_skeleton/legacy/screens/profile_screen.dart';
import 'package:moonbase_skeleton/features/auth/presentation/providers/auth_providers.dart';
import 'package:moonbase_skeleton/features/auth/presentation/controllers/auth_controller.dart';
import 'package:moonbase_skeleton/features/bases/presentation/providers/sidebar_providers.dart'
    as refactored;
import 'package:moonbase_skeleton/features/bases/presentation/widgets/refactored_swipable_sidebar.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/providers/calendar_home_vm_provider.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_actions.dart';
import 'package:moonbase_skeleton/features/calendar/presentation/widgets/calendar_home_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;
  final pages = const [
    CalendarHomeView(),
    ChatScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final selectedBase = ref.watch(refactored.effectiveSelectedBaseProvider);
    final calendarVm = ref.watch(calendarHomeVmProvider);
    final nickname = user?.nickname ?? 'Guest';
    final baseName = selectedBase?.name ?? 'No Base Selected';

    return RefactoredSwipableBaseSidebar(
      child: Scaffold(
        appBar: AppBar(
          leading: selectedBase != null
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      selectedBase.name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.home_work_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MoonBase - $nickname'),
              if (selectedBase != null)
                Text(
                  baseName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                final selectedBase = ref.read(refactored.selectedBaseProvider);
                if (selectedBase != null) {
                  context.go('/invites');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a base first')),
                  );
                }
              },
              icon: const Icon(Icons.group_add),
              tooltip: 'Manage Invites',
            ),
            // Notification bell hidden until notifications ship (D-13).
            IconButton(
              onPressed: () async {
                ref.read(refactored.selectedBaseProvider.notifier).state = null;
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: pages[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chats'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile'),
          ],
        ),
        // "Add event" only on the Home tab, only when the creation policy
        // allows this user (CreateEvent re-checks; rules enforce).
        floatingActionButton: _tab == 0 && canShowAddEventFab(calendarVm)
            ? FloatingActionButton.extended(
                key: const Key('home-add-event-fab'),
                onPressed: () => showEventEditor(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add event'),
              )
            : null,
      ),
    );
  }
}

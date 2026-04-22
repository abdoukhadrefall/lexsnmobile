import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/dossiers'))  return 1;
    if (loc.startsWith('/audiences')) return 2;
    if (loc.startsWith('/clients'))   return 3;
    if (loc.startsWith('/factures'))  return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LexSnTheme.border, width: 0.5)),
        ),
        // FIX: Tous les onglets restaurés (Clients et Honoraires étaient commentés)
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) {
            switch (i) {
              case 0: context.go('/dashboard');  break;
              case 1: context.go('/dossiers');   break;
              case 2: context.go('/audiences');  break;
              case 3: context.go('/clients');    break;
              case 4: context.go('/factures');   break;
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.speed_outlined),
              activeIcon: Icon(Icons.speed),
              label: 'Tableau',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Dossiers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Audiences',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Clients',
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.receipt_long_outlined),
            //   activeIcon: Icon(Icons.receipt_long),
            //   label: 'Honoraires',
            // ),
          ],
        ),
      ),
    );
  }
}
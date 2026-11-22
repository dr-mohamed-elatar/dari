import 'package:flutter/material.dart';

import 'screens/clients_screen.dart';
import 'screens/collections_screen.dart';
import 'screens/contracts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/guarantors_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['الرئيسية', 'العملاء', 'الضامنين', 'العقود / الأقساط', 'التحصيل', 'التقارير', 'الإعدادات'];
  static const _screens = [
    DashboardScreen(),
    ClientsScreen(),
    GuarantorsScreen(),
    ContractsScreen(),
    CollectionsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    final body = _screens[_index];
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('الرئيسية')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('العملاء')),
              NavigationRailDestination(icon: Icon(Icons.handshake), label: Text('الضامنين')),
              NavigationRailDestination(icon: Icon(Icons.description), label: Text('العقود')),
              NavigationRailDestination(icon: Icon(Icons.payments), label: Text('التحصيل')),
              NavigationRailDestination(icon: Icon(Icons.bar_chart), label: Text('التقارير')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('الإعدادات')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.people), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.handshake), label: 'الضامنين'),
          NavigationDestination(icon: Icon(Icons.description), label: 'العقود'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'التحصيل'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

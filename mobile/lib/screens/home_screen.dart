import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'houses_screen.dart';
import 'devices_screen.dart';
import 'scenarios_screen.dart';
import 'notifications_screen.dart';
import 'energy_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    DashboardScreen(),
    HousesScreen(),
    DevicesScreen(),
    ScenariosScreen(),
    EnergyScreen(),
    NotificationsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user != null ? '${user['name']} ${user['surname']}' : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartHome'),
        backgroundColor: const Color(0xFF18181D),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF00D4AA)),
              child: Text(
                name,
                style: const TextStyle(color: Colors.black, fontSize: 18),
              ),
            ),
            ...['Дашборд', 'Дома', 'Устройства', 'Сценарии', 'Энергия', 'Уведомления'].asMap().entries.map((e) {
              return ListTile(
                title: Text(e.value),
                selected: _selectedIndex == e.key,
                onTap: () {
                  setState(() => _selectedIndex = e.key);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
    );
  }
}

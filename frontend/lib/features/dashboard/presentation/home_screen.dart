import 'package:flutter/material.dart';
import '../../password_manager/presentation/password_vault_screen.dart';
import '../../password_manager/presentation/password_auditor_screen.dart';
import '../../transactions/presentation/budget_manager_screen.dart';
import '../../auth/presentation/profile_settings_screen.dart';
import 'dashboard_screen.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BudgetManagerScreen(),
    PasswordVaultScreen(),
    PasswordAuditorScreen(),
    ProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryDark : AppTheme.primaryLight,
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.surfaceDark : Colors.white,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Finanzas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Límites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.vpn_key_outlined),
            activeIcon: Icon(Icons.vpn_key),
            label: 'Bóveda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            activeIcon: Icon(Icons.security),
            label: 'Auditoría',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_coordinator.dart';
import 'scan_screen.dart';
import 'inventory_screen.dart';
import 'recipes_screen.dart';
import 'shopping_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScanScreen(),
    InventoryScreen(),
    RecipesScreen(),
    ShoppingScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppCoordinator>(
        builder: (context, coordinator, child) {
          // Show global loading overlay
          return Stack(
            children: [
              _screens[_currentIndex],
              
              // Global messages
              if (coordinator.errorMessage != null || coordinator.successMessage != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: _MessageBanner(
                    message: coordinator.errorMessage ?? coordinator.successMessage!,
                    isError: coordinator.errorMessage != null,
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Consumer<AppCoordinator>(
              builder: (context, coordinator, child) {
                final count = coordinator.expiringCount;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.kitchen),
                );
              },
            ),
            selectedIcon: const Icon(Icons.kitchen),
            label: 'Fridge',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Consumer<AppCoordinator>(
              builder: (context, coordinator, child) {
                final count = coordinator.unpurchasedCount;
                return Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.shopping_cart),
                );
              },
            ),
            selectedIcon: const Icon(Icons.shopping_cart),
            label: 'Shop',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE BANNER
// ============================================================================
class _MessageBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const _MessageBanner({
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: isError ? Colors.red.shade100 : Colors.green.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red.shade700 : Colors.green.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red.shade900 : Colors.green.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
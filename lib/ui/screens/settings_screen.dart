import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_coordinator.dart';
import '../../models/models.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppCoordinator>(
        builder: (context, coordinator, child) {
          return ListView(
            children: [
              // Profile section
              _ProfileSection(),

              const Divider(height: 32),

              // Inventory management
              _SectionHeader(title: 'Inventory'),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('Clear All Inventory'),
                subtitle: Text('${coordinator.inventory.length} items'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showClearInventoryDialog(context, coordinator),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('Sync with Cloud'),
                subtitle: coordinator.currentPosition != null
                    ? const Text('Connected')
                    : const Text('Not synced'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // TODO: Toggle cloud sync
                  },
                ),
              ),

              const Divider(height: 32),

              // Notifications
              _SectionHeader(title: 'Notifications'),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Expiry Warnings'),
                subtitle: const Text('Get notified before items expire'),
                trailing: Switch(
                  value: coordinator.preferences.notifyExpiringSoon,
                  onChanged: (value) {
                    final newPrefs = UserPreferences(
                      dietaryRestrictions: coordinator.preferences.dietaryRestrictions,
                      allergies: coordinator.preferences.allergies,
                      dislikedIngredients: coordinator.preferences.dislikedIngredients,
                      notifyExpiringSoon: value,
                      expiryWarningDays: coordinator.preferences.expiryWarningDays,
                      preferredUnits: coordinator.preferences.preferredUnits,
                    );
                    coordinator.updatePreferences(newPrefs);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Warning Days'),
                subtitle: Text(
                  'Notify ${coordinator.preferences.expiryWarningDays} days before expiry',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showWarningDaysDialog(context, coordinator),
              ),

              const Divider(height: 32),

              // Dietary preferences
              _SectionHeader(title: 'Dietary Preferences'),
              ListTile(
                leading: const Icon(Icons.restaurant),
                title: const Text('Dietary Restrictions'),
                subtitle: Text(
                  coordinator.preferences.dietaryRestrictions.isEmpty
                      ? 'None set'
                      : coordinator.preferences.dietaryRestrictions.join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDietaryRestrictionsDialog(context, coordinator),
              ),
              ListTile(
                leading: const Icon(Icons.warning),
                title: const Text('Allergies'),
                subtitle: Text(
                  coordinator.preferences.allergies.isEmpty
                      ? 'None set'
                      : coordinator.preferences.allergies.join(', '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAllergiesDialog(context, coordinator),
              ),

              const Divider(height: 32),

              // Location
              _SectionHeader(title: 'Location'),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Location Services'),
                subtitle: coordinator.currentPosition != null
                    ? const Text('Enabled - Finding nearby stores')
                    : const Text('Disabled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  coordinator.requestLocationPermission();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking location permissions...'),
                    ),
                  );
                },
              ),

              const Divider(height: 32),

              // App info
              _SectionHeader(title: 'About'),
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show privacy policy
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Show terms
                },
              ),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Report a Bug'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Open bug report
                },
              ),

              const SizedBox(height: 32),

              // Danger zone
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () => _showResetDialog(context, coordinator),
                  icon: const Icon(Icons.restart_alt, color: Colors.red),
                  label: const Text(
                    'Reset All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  void _showClearInventoryDialog(
    BuildContext context,
    AppCoordinator coordinator,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Inventory?'),
        content: Text(
          'This will remove all ${coordinator.inventory.length} items from your fridge. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              coordinator.clearInventory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showWarningDaysDialog(
    BuildContext context,
    AppCoordinator coordinator,
  ) {
    final currentDays = coordinator.preferences.expiryWarningDays;
    int selectedDays = currentDays;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Expiry Warning Days'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Get notified when items will expire in:'),
                  const SizedBox(height: 16),
                  Slider(
                    value: selectedDays.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$selectedDays days',
                    onChanged: (value) {
                      setState(() => selectedDays = value.round());
                    },
                  ),
                  Text(
                    '$selectedDays days',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrefs = UserPreferences(
                      dietaryRestrictions: coordinator.preferences.dietaryRestrictions,
                      allergies: coordinator.preferences.allergies,
                      dislikedIngredients: coordinator.preferences.dislikedIngredients,
                      notifyExpiringSoon: coordinator.preferences.notifyExpiringSoon,
                      expiryWarningDays: selectedDays,
                      preferredUnits: coordinator.preferences.preferredUnits,
                    );
                    coordinator.updatePreferences(newPrefs);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDietaryRestrictionsDialog(
    BuildContext context,
    AppCoordinator coordinator,
  ) {
    final options = [
      'Vegetarian',
      'Vegan',
      'Gluten-Free',
      'Dairy-Free',
      'Keto',
      'Paleo',
      'Halal',
      'Kosher',
    ];

    final selected = List<String>.from(coordinator.preferences.dietaryRestrictions);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Dietary Restrictions'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((option) {
                    return CheckboxListTile(
                      value: selected.contains(option),
                      title: Text(option),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selected.add(option);
                          } else {
                            selected.remove(option);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrefs = UserPreferences(
                      dietaryRestrictions: selected,
                      allergies: coordinator.preferences.allergies,
                      dislikedIngredients: coordinator.preferences.dislikedIngredients,
                      notifyExpiringSoon: coordinator.preferences.notifyExpiringSoon,
                      expiryWarningDays: coordinator.preferences.expiryWarningDays,
                      preferredUnits: coordinator.preferences.preferredUnits,
                    );
                    coordinator.updatePreferences(newPrefs);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllergiesDialog(
    BuildContext context,
    AppCoordinator coordinator,
  ) {
    final controller = TextEditingController();
    final allergies = List<String>.from(coordinator.preferences.allergies);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Allergies'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Add allergy',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            setState(() {
                              allergies.add(controller.text);
                              controller.clear();
                            });
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          allergies.add(value);
                          controller.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ...allergies.map((allergy) => Chip(
                        label: Text(allergy),
                        onDeleted: () {
                          setState(() => allergies.remove(allergy));
                        },
                      )),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrefs = UserPreferences(
                      dietaryRestrictions: coordinator.preferences.dietaryRestrictions,
                      allergies: allergies,
                      dislikedIngredients: coordinator.preferences.dislikedIngredients,
                      notifyExpiringSoon: coordinator.preferences.notifyExpiringSoon,
                      expiryWarningDays: coordinator.preferences.expiryWarningDays,
                      preferredUnits: coordinator.preferences.preferredUnits,
                    );
                    coordinator.updatePreferences(newPrefs);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, AppCoordinator coordinator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete:\n'
          '• All inventory items\n'
          '• Shopping list\n'
          '• Preferences\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              coordinator.clearInventory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data has been reset')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE SECTION
// ============================================================================
class _ProfileSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anonymous User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free Plan',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit profile
            },
          ),
        ],
      ),
    );
  }
}
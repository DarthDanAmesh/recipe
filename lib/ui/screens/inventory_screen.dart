// inventory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/app_coordinator.dart';
import '../../models/models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

enum _SortOption { name, expiry, category }

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  _SortOption? _currentSortOption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Fridge'),
        actions: [
          Consumer<AppCoordinator>(
            builder: (context, coordinator, child) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: coordinator.expiringCount > 0,
                  label: Text('${coordinator.expiringCount}'),
                  child: const Icon(Icons.warning_amber),
                ),
                onPressed: () => _showExpiringItems(context, coordinator),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
      body: Consumer<AppCoordinator>(
        builder: (context, coordinator, child) {
          if (coordinator.inventory.isEmpty) {
            return _EmptyState(
              onScan: () {
                // Navigate to scan tab (index 0)
                DefaultTabController.of(context)?.animateTo(0);
              },
            );
          }

          final categories = ['All', ...coordinator.inventory
              .map((item) => item.category)
              .toSet()
              .toList()
            ..sort()];

          final filtered = _processInventory(coordinator.inventory);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search ingredients...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // Category chips
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedCategory = category);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              // Inventory list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No items match your search',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _IngredientCard(
                            ingredient: filtered[index],
                            onDelete: () {
                              coordinator.removeIngredient(filtered[index].id);
                            },
                            onEdit: () {
                              _showEditDialog(context, filtered[index], coordinator);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  List<Ingredient> _processInventory(List<Ingredient> inventory) {
    var processed = inventory;

    // Apply Category Filter
    if (_selectedCategory != 'All') {
      processed = processed.where((item) => item.category == _selectedCategory).toList();
    }

    // Apply Search Filter
    if (_searchQuery.isNotEmpty) {
      processed = processed
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply Sorting
    if (_currentSortOption != null) {
      switch (_currentSortOption) {
        case _SortOption.name:
          processed.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
        case _SortOption.expiry:
          processed.sort((a, b) {
            final dateA = a.expiryDate;
            final dateB = b.expiryDate;
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1; // Items without expiry go to the end
            if (dateB == null) return -1;
            return dateA.compareTo(dateB); // Soonest expiring first
          });
          break;
        case _SortOption.category:
          processed.sort((a, b) => a.category.toLowerCase().compareTo(b.category.toLowerCase()));
          break;
        case null:
          break;
      }
    }

    return processed;
  }

  void _showExpiringItems(BuildContext context, AppCoordinator coordinator) {
    final expiring = coordinator.expiringIngredients;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text(
                    'Expiring Soon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...expiring.map((item) => ListTile(
                    leading: const Icon(Icons.circle, size: 12),
                    title: Text(item.name),
                    subtitle: Text(
                      'Expires ${DateFormat.yMd().format(item.expiryDate!)}',
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Sort by Name'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentSortOption = _SortOption.name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sort by Expiry Date'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentSortOption = _SortOption.expiry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Sort by Category'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _currentSortOption = _SortOption.category);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    DateTime? expiryDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Ingredient'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      expiryDate == null
                          ? 'Set Expiry Date'
                          : 'Expires: ${DateFormat.yMd().format(expiryDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => expiryDate = date);
                      }
                    },
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
                    if (nameController.text.isNotEmpty) {
                      context.read<AppCoordinator>().addIngredient(
                            nameController.text,
                            expiryDate: expiryDate,
                          );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext context,
    Ingredient ingredient,
    AppCoordinator coordinator,
  ) {
    final nameController = TextEditingController(text: ingredient.name);
    DateTime? expiryDate = ingredient.expiryDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Ingredient'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      expiryDate == null
                          ? 'Set Expiry Date'
                          : 'Expires: ${DateFormat.yMd().format(expiryDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: expiryDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => expiryDate = date);
                      }
                    },
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
                    ingredient.name = nameController.text;
                    ingredient.expiryDate = expiryDate;
                    coordinator.updateIngredient(ingredient);
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
}

// ============================================================================
// INGREDIENT CARD
// ============================================================================
class _IngredientCard extends StatelessWidget {
  final Ingredient ingredient;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _IngredientCard({
    required this.ingredient,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isExpiring = ingredient.willExpireSoon;
    final isExpired = ingredient.isExpired;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isExpired
                ? Colors.red
                : isExpiring
                    ? Colors.orange
                    : Colors.green,
            child: Icon(
              _getCategoryIcon(ingredient.category),
              color: Colors.white,
              size: 20,
            ),
          ),
          title: Text(
            ingredient.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ingredient.category),
              if (ingredient.expiryDate != null)
                Text(
                  'Expires: ${DateFormat.yMd().format(ingredient.expiryDate!)}',
                  style: TextStyle(
                    color: isExpired
                        ? Colors.red
                        : isExpiring
                            ? Colors.orange
                            : null,
                  ),
                ),
            ],
          ),
          trailing: isExpiring || isExpired
              ? Icon(
                  Icons.warning_amber,
                  color: isExpired ? Colors.red : Colors.orange,
                )
              : null,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dairy':
        return Icons.water_drop;
      case 'protein':
        return Icons.set_meal;
      case 'fruits':
        return Icons.apple;
      case 'vegetables':
        return Icons.eco;
      case 'grains':
        return Icons.grain;
      default:
        return Icons.fastfood;
    }
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  final VoidCallback onScan;

  const _EmptyState({required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.kitchen_outlined,
              size: 120,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Fridge is Empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan a receipt or add items manually to get started',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Receipt'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
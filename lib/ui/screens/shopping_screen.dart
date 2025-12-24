import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/app_coordinator.dart';
import '../../models/models.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  bool _showPurchased = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          IconButton(
            icon: Icon(
              _showPurchased ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() => _showPurchased = !_showPurchased);
            },
            tooltip: _showPurchased ? 'Hide purchased' : 'Show purchased',
          ),
          Consumer<AppCoordinator>(
            builder: (context, coordinator, child) {
              final hasPurchased = coordinator.shoppingList
                  .any((item) => item.isPurchased);
              
              return PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: hasPurchased,
                    child: const Row(
                      children: [
                        Icon(Icons.delete_sweep),
                        SizedBox(width: 8),
                        Text('Clear Purchased'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(
                        const Duration(milliseconds: 100),
                        () => coordinator.clearPurchasedItems(),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Share List'),
                      ],
                    ),
                    onTap: () {
                      // TODO: Implement sharing
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<AppCoordinator>(
        builder: (context, coordinator, child) {
          if (coordinator.shoppingList.isEmpty) {
            return _EmptyState();
          }

          final items = _showPurchased
              ? coordinator.shoppingList
              : coordinator.unpurchasedItems;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 120,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'All Done!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You\'ve purchased everything',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by category
          final grouped = <String, List<ShoppingItem>>{};
          for (var item in items) {
            grouped.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats card
              _StatsCard(coordinator: coordinator),

              const SizedBox(height: 16),

              // Nearby stores (if available)
              if (coordinator.nearbyStores.isNotEmpty)
                _NearbyStoresCard(coordinator: coordinator),

              const SizedBox(height: 16),

              // Shopping list by category
              ...grouped.entries.map((entry) {
                return _CategorySection(
                  category: entry.key,
                  items: entry.value,
                  onToggle: (id) => coordinator.toggleShoppingItemPurchased(id),
                  onDelete: (id) => coordinator.removeShoppingItem(id),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Shopping Item'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  context.read<AppCoordinator>().addShoppingItem(
                        nameController.text,
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
  }
}

// ============================================================================
// STATS CARD
// ============================================================================
class _StatsCard extends StatelessWidget {
  final AppCoordinator coordinator;

  const _StatsCard({required this.coordinator});

  @override
  Widget build(BuildContext context) {
    final total = coordinator.shoppingList.length;
    final purchased = coordinator.shoppingList
        .where((item) => item.isPurchased)
        .length;
    final remaining = total - purchased;
    final progress = total > 0 ? purchased / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Total',
                  value: '$total',
                  color: Colors.blue,
                ),
                _StatItem(
                  label: 'Remaining',
                  value: '$remaining',
                  color: Colors.orange,
                ),
                _StatItem(
                  label: 'Purchased',
                  value: '$purchased',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}% Complete',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// NEARBY STORES CARD
// ============================================================================
class _NearbyStoresCard extends StatelessWidget {
  final AppCoordinator coordinator;

  const _NearbyStoresCard({required this.coordinator});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.store,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Nearby Stores',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...coordinator.nearbyStores.take(3).map((store) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: store.isOpen
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Icon(
                  Icons.store,
                  color: store.isOpen
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
              ),
              title: Text(store.name),
              subtitle: Text(
                '${store.distance?.toStringAsFixed(1)} km • ${store.isOpen ? "Open" : "Closed"}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.directions),
                onPressed: () {
                  // TODO: Open maps
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================================
// CATEGORY SECTION
// ============================================================================
class _CategorySection extends StatelessWidget {
  final String category;
  final List<ShoppingItem> items;
  final Function(String) onToggle;
  final Function(String) onDelete;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${items.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        ...items.map((item) => _ShoppingItemCard(
              item: item,
              onToggle: () => onToggle(item.id),
              onDelete: () => onDelete(item.id),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ============================================================================
// SHOPPING ITEM CARD
// ============================================================================
class _ShoppingItemCard extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ShoppingItemCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
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
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: item.isPurchased,
          onChanged: (_) => onToggle(),
          title: Text(
            item.name,
            style: TextStyle(
              decoration: item.isPurchased
                  ? TextDecoration.lineThrough
                  : null,
              color: item.isPurchased ? Colors.grey : null,
            ),
          ),
          subtitle: Text(
            '${item.quantity} ${item.unit}',
            style: TextStyle(
              color: item.isPurchased
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
          ),
          secondary: Icon(
            _getCategoryIcon(item.category),
            color: item.isPurchased
                ? Colors.grey.shade400
                : Theme.of(context).colorScheme.primary,
          ),
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
        return Icons.shopping_basket;
    }
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 120,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            const Text(
              'No Shopping List',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add items manually or generate from a recipe',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
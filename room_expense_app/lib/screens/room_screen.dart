import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/app_provider.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Refresh room data when Summary tab is opened
      if (_tabController.index == 2) {
        context.read<AppProvider>().refreshRoom();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave(BuildContext context, AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Room?'),
        content: const Text(
          'You will be removed from this room and your cart will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await provider.leaveRoom();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Room?'),
        content: const Text(
          'This will permanently delete the room, all items, and all cart data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await provider.deleteRoom();
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final room = provider.currentRoom;
    if (room == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.name, style: const TextStyle(fontSize: 16)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: room.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room code copied!')),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Code: ${room.code}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.copy,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'leave') _confirmLeave(context, provider);
              if (value == 'delete') _confirmDelete(context, provider);
            },
            itemBuilder: (ctx) => [
              if (room.createdBy != provider.currentUser?.id)
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app),
                      SizedBox(width: 12),
                      Text('Leave Room'),
                    ],
                  ),
                ),
              if (room.createdBy == provider.currentUser?.id)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete Room', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt), text: 'Items'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'My Cart'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ItemsTab(), _CartTab(), _SummaryTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Items Tab
// ─────────────────────────────────────────────────────────
class _ItemsTab extends StatelessWidget {
  const _ItemsTab();

  void _showAddItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add Item'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    autofocus: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter item name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (৳)',
                      border: OutlineInputBorder(),
                      prefixText: '৳ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter price';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      if (double.parse(v) <= 0) return 'Must be greater than 0';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isLoading = true);
                        try {
                          await context.read<AppProvider>().addItem(
                            nameCtrl.text,
                            double.parse(priceCtrl.text),
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final room = provider.currentRoom!;
    final items = room.items.values.toList();

    return Scaffold(
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text('No items yet'),
                  const SizedBox(height: 4),
                  Text(
                    'Tap + to add items',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _ItemCard(item: items[i]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ItemModel item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final qty = provider.cartQuantityOf(item.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '৳ ${item.unitPrice.toStringAsFixed(2)} / unit',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (qty == 0)
              OutlinedButton.icon(
                onPressed: () => provider.addToCart(item.id, 1),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Add'),
              )
            else
              Row(
                children: [
                  IconButton(
                    onPressed: () => provider.addToCart(item.id, qty - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Text(
                    '$qty',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    onPressed: () => provider.addToCart(item.id, qty + 1),
                    icon: const Icon(Icons.add_circle_outline),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Cart Tab
// ─────────────────────────────────────────────────────────
class _CartTab extends StatelessWidget {
  const _CartTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser!;
    final cartItems = user.cart.values.toList();
    final theme = Theme.of(context);

    return cartItems.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                const Text('Your cart is empty'),
                const SizedBox(height: 4),
                Text(
                  'Add items from the Items tab',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final ci = cartItems[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ci.item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '৳ ${ci.item.unitPrice.toStringAsFixed(2)} × ${ci.quantity}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '৳ ${ci.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => provider.addToCart(
                                    ci.item.id,
                                    ci.quantity - 1,
                                  ),
                                  icon: const Icon(Icons.remove_circle_outline),
                                  iconSize: 20,
                                ),
                                Text(
                                  '${ci.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => provider.addToCart(
                                    ci.item.id,
                                    ci.quantity + 1,
                                  ),
                                  icon: const Icon(Icons.add_circle_outline),
                                  iconSize: 20,
                                ),
                                IconButton(
                                  onPressed: () =>
                                      provider.removeFromCart(ci.item.id),
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 20,
                                  color: theme.colorScheme.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Total',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '৳ ${user.cartTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }
}

// ─────────────────────────────────────────────────────────
// Summary Tab
// ─────────────────────────────────────────────────────────
class _SummaryTab extends StatefulWidget {
  const _SummaryTab();

  @override
  State<_SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends State<_SummaryTab> {
  bool _membersListExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final room = provider.currentRoom!;
    final members = room.members.values.toList();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Members count card – tap to expand/collapse member list
          Card(
            color: theme.colorScheme.primaryContainer,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  setState(() => _membersListExpanded = !_membersListExpanded),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${members.length} member${members.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _membersListExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                  if (_membersListExpanded) ...[
                    Divider(
                      height: 1,
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    ...members.map(
                      (m) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            m.name[0].toUpperCase(),
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        title: Text(
                          m.name,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: room.createdBy == m.id
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Items summary - total quantity per item across all members
          Builder(
            builder: (context) {
              // Aggregate: itemId -> {item, totalQty}
              final Map<String, _ItemSummary> itemMap = {};
              for (final member in members) {
                for (final ci in member.cart.values) {
                  if (itemMap.containsKey(ci.item.id)) {
                    itemMap[ci.item.id]!.totalQty += ci.quantity;
                  } else {
                    itemMap[ci.item.id] = _ItemSummary(
                      name: ci.item.name,
                      unitPrice: ci.item.unitPrice,
                      totalQty: ci.quantity,
                    );
                  }
                }
              }
              // Also include items that exist in the room but nobody ordered yet
              for (final item in room.items.values) {
                itemMap.putIfAbsent(
                  item.id,
                  () => _ItemSummary(
                    name: item.name,
                    unitPrice: item.unitPrice,
                    totalQty: 0,
                  ),
                );
              }
              final summaryItems = itemMap.values.toList();
              if (summaryItems.isEmpty) return const SizedBox.shrink();

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: theme.colorScheme.tertiaryContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Items Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // table header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 4,
                            child: Text(
                              'Item',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'Unit Price',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Total',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...summaryItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final s = entry.value;
                      final isEven = idx % 2 == 0;
                      return Container(
                        color: isEven
                            ? null
                            : theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                s.name,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                s.totalQty == 0 ? '—' : '${s.totalQty}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: s.totalQty == 0
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface,
                                  fontWeight: s.totalQty > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '৳ ${s.unitPrice.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                s.totalQty == 0
                                    ? '—'
                                    : '৳ ${(s.unitPrice * s.totalQty).toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: s.totalQty > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: s.totalQty > 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Grand total row
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            flex: 8,
                            child: Text(
                              'Grand Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '৳ ${room.grandTotal.toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Per-member breakdown cards
          ...members.where((m) => m.cart.isNotEmpty).map((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    member.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Text(
                    '৳ ${member.cartTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: member.cart.values.map((ci) {
                    return ListTile(
                      dense: true,
                      title: Text(ci.item.name),
                      subtitle: Text(
                        '৳ ${ci.item.unitPrice.toStringAsFixed(2)} × ${ci.quantity}',
                      ),
                      trailing: Text(
                        '৳ ${ci.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ItemSummary {
  final String name;
  final double unitPrice;
  int totalQty;

  _ItemSummary({
    required this.name,
    required this.unitPrice,
    required this.totalQty,
  });
}

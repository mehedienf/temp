import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/item_model.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import 'session_history_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _financeTabKey = GlobalKey<_FinanceTabState>();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // Refresh room data when Summary tab is opened
      if (_tabController.index == 2) {
        context.read<AppProvider>().refreshRoom();
      }
    });
    // Auto-refresh room data every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) context.read<AppProvider>().refreshRoom();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
              if (value == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionHistoryScreen(
                      roomId: room.id,
                      roomName: room.name,
                      isAdmin: room.createdBy == provider.currentUser?.id,
                      adminId: provider.currentUser?.id ?? '',
                    ),
                  ),
                ).then((_) {
                  if (mounted) _financeTabKey.currentState?._loadBalance();
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 12),
                    Text('History'),
                  ],
                ),
              ),
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
            Tab(icon: Icon(Icons.people_outline), text: 'Members'),
            Tab(icon: Icon(Icons.list_alt), text: 'Items'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Summary'),
            Tab(
              icon: Icon(Icons.account_balance_wallet_outlined),
              text: 'Finance',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _MembersTab(),
          const _ItemsTab(),
          const _SummaryTab(),
          _FinanceTab(key: _financeTabKey),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Items Tab
// ─────────────────────────────────────────────────────────
class _ItemsTab extends StatefulWidget {
  const _ItemsTab();

  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  // Which user's cart to manage (admin can switch; defaults to current user)
  String? _forUserId;

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
    final currentUser = provider.currentUser!;
    final isAdmin = room.createdBy == currentUser.id;
    final items = room.items.values.toList();
    // Only active (non-left) members shown in dropdown / counted
    final members = room.members.values.where((m) => !m.isLeft).toList();

    // Default to current user; if admin changed selection keep it valid
    final effectiveUserId =
        (_forUserId != null && room.members.containsKey(_forUserId))
        ? _forUserId!
        : currentUser.id;

    return Scaffold(
      body: Column(
        children: [
          // ── Admin: user selector ────────────────────────────────────────
          if (isAdmin && members.length > 1)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adding items for',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: effectiveUserId,
                            isDense: true,
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            icon: Icon(
                              Icons.expand_more,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            items: members
                                .map(
                                  (m) => DropdownMenuItem<String>(
                                    value: m.id,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.primaryContainer,
                                          child: Text(
                                            m.name[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(m.name),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _forUserId = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // ── Confirmed banner ────────────────────────────────────────────
          if (room.isConfirmed)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cart is locked — session confirmed',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // ── Items list ──────────────────────────────────────────────────
          Expanded(
            child: items.isEmpty
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
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _ItemCard(
                      item: items[i],
                      targetUserId: effectiveUserId,
                      isCurrentUser: effectiveUserId == currentUser.id,
                      isConfirmed: room.isConfirmed,
                    ),
                  ),
          ),
        ],
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
  final String targetUserId;
  final bool isCurrentUser;
  final bool isConfirmed;

  const _ItemCard({
    required this.item,
    required this.targetUserId,
    required this.isCurrentUser,
    required this.isConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final qty = isCurrentUser
        ? provider.cartQuantityOf(item.id)
        : provider.cartQuantityOfUser(targetUserId, item.id);

    Future<void> setQty(int newQty) async {
      if (isCurrentUser) {
        provider.addToCart(item.id, newQty);
      } else {
        try {
          await provider.addToCartForUser(targetUserId, item.id, newQty);
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
    }

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
            if (isConfirmed)
              Text(
                qty > 0 ? '$qty in cart' : '—',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              )
            else if (qty == 0)
              OutlinedButton.icon(
                onPressed: () => setQty(1),
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Add'),
              )
            else
              Row(
                children: [
                  IconButton(
                    onPressed: () => setQty(qty - 1),
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
                    onPressed: () => setQty(qty + 1),
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
// ─────────────────────────────────────────────────────────
// Members Tab
// ─────────────────────────────────────────────────────────
class _MembersTab extends StatefulWidget {
  const _MembersTab();

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  Future<void> _showAddMemberDialog() async {
    final provider = context.read<AppProvider>();
    final room = provider.currentRoom!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final usernameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Member'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                hintText: 'Enter their username',
                prefixIcon: Icon(Icons.person_outline),
              ),
              autofocus: true,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setS(() => loading = true);
                      try {
                        final result = await ApiService.addMember(
                          room.id,
                          provider.currentUser!.id,
                          usernameCtrl.text.trim(),
                        );
                        await provider.refreshRoom();
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        final alreadyMember = result['alreadyMember'] == true;
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              alreadyMember
                                  ? '\'${usernameCtrl.text.trim()}\' is already a member.'
                                  : '\'${usernameCtrl.text.trim()}\' added!',
                            ),
                          ),
                        );
                      } catch (e) {
                        setS(() => loading = false);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              child: loading
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
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(
    BuildContext context,
    String roomId,
    String memberId,
    String memberName,
    String adminId,
  ) async {
    final provider = context.read<AppProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text(
          'Remove "$memberName" from the room?\n\nTheir deposit and expense history will still be visible in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ApiService.leaveRoom(roomId, memberId, requesterId: adminId);
      await provider.refreshRoom();
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
    final room = provider.currentRoom!;
    final currentUser = provider.currentUser!;
    final isAdmin = room.createdBy == currentUser.id;
    // All members (including left) for Members tab
    final allMembers = room.members.values.toList()
      ..sort((a, b) {
        if (a.isLeft == b.isLeft) return 0;
        return a.isLeft ? 1 : -1; // left members go to bottom
      });
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: allMembers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: cs.onSurface.withValues(alpha: 0.25),
                  ),
                  const SizedBox(height: 12),
                  const Text('No members yet'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: allMembers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final m = allMembers[i];
                final isMemberAdmin = m.id == room.createdBy;
                final isCurrentUser = m.id == currentUser.id;
                return Opacity(
                  opacity: m.isLeft ? 0.5 : 1.0,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: m.isLeft
                                ? cs.surfaceContainerHighest
                                : cs.primaryContainer,
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: m.isLeft
                                    ? cs.onSurfaceVariant
                                    : cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (isMemberAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.tertiary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Admin',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onTertiary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (isCurrentUser) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.primary,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'You',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (m.isLeft) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'left',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: cs.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (isAdmin && !isMemberAdmin)
                            IconButton(
                              icon: Icon(
                                Icons.person_remove_outlined,
                                color: Colors.red.shade400,
                              ),
                              tooltip: m.isLeft ? 'Delete member data' : 'Remove member',
                              onPressed: () => _confirmRemoveMember(
                                context,
                                room.id,
                                m.id,
                                m.name,
                                currentUser.id,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _showAddMemberDialog,
              tooltip: 'Add Member',
              child: const Icon(Icons.person_add_alt_1_outlined),
            )
          : null,
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
    // Only active members in Summary
    final members = room.members.values.where((m) => !m.isLeft).toList();
    final theme = Theme.of(context);

    final isAdmin = room.createdBy == provider.currentUser?.id;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Admin: Confirm / New session buttons ────────────────────────
          if (isAdmin) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (provider.isLoading)
                        ? null
                        : () async {
                            try {
                              await provider.lockRoom();
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          },
                    icon: Icon(
                      room.isConfirmed
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                    ),
                    label: Text(room.isConfirmed ? 'Locked':'Unlocked' ),
                    style: FilledButton.styleFrom(
                      backgroundColor: room.isConfirmed
                          // ? theme.colorScheme.secondary
                          ? Colors.redAccent
                          // : theme.colorScheme.primary,
                          : Colors.green
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (provider.isLoading || room.grandTotal == 0)
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Save Session?'),
                                content: const Text(
                                  'This will save the current summary and clear all carts to start fresh.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              await provider.newSession();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Session saved & carts cleared!',
                                  ),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  ),
                                  backgroundColor: theme.colorScheme.error,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
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

// ─────────────────────────────────────────────────────────
// Finance Tab
// ─────────────────────────────────────────────────────────

class _FinanceTab extends StatefulWidget {
  const _FinanceTab({super.key});

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> {
  List<Map<String, dynamic>> _balance = [];
  bool _loading = true;
  String? _error;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    // Auto-refresh balance every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadBalance();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roomId = context.read<AppProvider>().currentRoom!.id;
      final data = await ApiService.getBalance(roomId);
      if (mounted) {
        setState(() {
          _balance = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _showSplitExpenseDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<AppProvider>();
    final activeMembers = provider.currentRoom!.members.values
        .where((m) => !m.isLeft)
        .toList();
    // All active members pre-selected
    final selectedIds = <String>{...activeMembers.map((m) => m.id)};

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final totalAmount = double.tryParse(amountCtrl.text) ?? 0.0;
          final count = selectedIds.length;
          final perMember = count > 0 ? totalAmount / count : 0.0;
          return AlertDialog(
            title: const Text('Add Split Expense'),
            content: SizedBox(
              width: double.maxFinite,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Expense Name',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      autofocus: true,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (৳)',
                        border: OutlineInputBorder(),
                        prefixText: '৳ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setS(() {}),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Enter amount';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Member checkboxes
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: activeMembers.map((m) {
                          return CheckboxListTile(
                            dense: true,
                            title: Text(m.name, style: const TextStyle(fontSize: 14)),
                            value: selectedIds.contains(m.id),
                            onChanged: (checked) => setS(() {
                              if (checked == true) {
                                selectedIds.add(m.id);
                              } else {
                                selectedIds.remove(m.id);
                              }
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        }).toList(),
                      ),
                    ),
                    if (totalAmount > 0 && count > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people_outline, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '৳${perMember.toStringAsFixed(2)} per person ($count selected)',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selectedIds.isEmpty ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  try {
                    await ApiService.addSplitExpense(
                      provider.currentRoom!.id,
                      provider.currentUser!.id,
                      nameCtrl.text.trim(),
                      double.parse(amountCtrl.text),
                      memberIds: selectedIds.toList(),
                    );
                    await _loadBalance();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Split expense added!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddDepositDialog() {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final provider = context.read<AppProvider>();
    final room = provider.currentRoom!;
    final currentUser = provider.currentUser!;
    final isAdmin = room.createdBy == currentUser.id;
    // Only active members in deposit dropdown
    final members = room.members.values.where((m) => !m.isLeft).toList();
    String selectedUserId = currentUser.id;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Add Deposit'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAdmin) ...[
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Member',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedUserId,
                          isExpanded: true,
                          isDense: true,
                          items: members
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Theme.of(
                                          ctx,
                                        ).colorScheme.primary,
                                        child: Text(
                                          m.name.isNotEmpty
                                              ? m.name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(m.name),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setS(() => selectedUserId = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount (৳)',
                      border: OutlineInputBorder(),
                      prefixText: '৳ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: !isAdmin,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter amount';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Invalid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. Cash, bKash, Bank transfer...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  try {
                    await ApiService.addDeposit(
                      room.id,
                      currentUser.id,
                      selectedUserId,
                      double.parse(amountCtrl.text),
                      noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    );
                    await _loadBalance();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Deposit recorded!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save'),
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
    final isAdmin = room.createdBy == provider.currentUser?.id;
    final currentUserId = provider.currentUser?.id ?? '';

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadBalance, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Text(
                'Member Balances',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadBalance,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _balance.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No data yet.\nConfirm a session or add a split expense to see balances.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  itemCount: _balance.length,
                  itemBuilder: (_, i) => _BalanceCard(
                    data: _balance[i],
                    isCurrentUser:
                        (_balance[i]['userId'] as String) == currentUserId,
                    adminId: room.createdBy ?? '',
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                if (isAdmin) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showSplitExpenseDialog,
                      icon: const Icon(Icons.call_split, size: 18),
                      label: const Text('Split Expense'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (isAdmin) ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showAddDepositDialog,
                      icon: const Icon(Icons.savings_outlined, size: 18),
                      label: const Text('Add Deposit'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// Balance Card
// ─────────────────────────────────────────────────────────

class _BalanceCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isCurrentUser;
  final String adminId;

  const _BalanceCard({
    required this.data,
    required this.isCurrentUser,
    required this.adminId,
  });

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _expanded = false;

  String _fmt(num v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final name = d['name'] as String;
    final balance = (d['balance'] as num).toDouble();
    final totalExpense = (d['totalExpense'] as num).toDouble();
    final totalDeposited = (d['totalDeposited'] as num).toDouble();
    final cartExpenses = List<Map<String, dynamic>>.from(
      d['cartExpenses'] as List? ?? [],
    );
    final splitExpenses = List<Map<String, dynamic>>.from(
      d['splitExpenses'] as List? ?? [],
    );
    final deposits = List<Map<String, dynamic>>.from(
      d['deposits'] as List? ?? [],
    );

    final balanceColor = balance > 0
        ? Colors.green.shade700
        : balance < 0
        ? Colors.red.shade700
        : Colors.grey.shade600;

    final cs = Theme.of(context).colorScheme;
    final isAdminMember = widget.adminId == (d['userId'] as String);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: widget.isCurrentUser ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: widget.isCurrentUser
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isAdminMember) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.tertiary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onTertiary,
                                  ),
                                ),
                              ),
                            ],
                            if (widget.isCurrentUser) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'You',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          balance >= 0
                              ? 'Credit: ৳${_fmt(balance)}'
                              : 'Owes: ৳${_fmt(balance.abs())}',
                          style: TextStyle(
                            color: balanceColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _MiniStatChip(
                  label: 'Expense',
                  value: totalExpense,
                  icon: Icons.remove_circle_outline,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                _MiniStatChip(
                  label: 'Deposited',
                  value: totalDeposited,
                  icon: Icons.add_circle_outline,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 6),
                _MiniStatChip(
                  label: 'Balance',
                  value: balance,
                  icon: balance >= 0
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: balanceColor,
                  showSign: true,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cartExpenses.isNotEmpty) ...[
                    _finSectionLabel(
                      'Cart Expenses (by Session)',
                      Icons.receipt_long_outlined,
                    ),
                    const SizedBox(height: 6),
                    ...cartExpenses.map(
                      (e) => _DetailRow(
                        label: 'Session #${e['sessionNumber']}',
                        value: (e['amount'] as num).toDouble(),
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (splitExpenses.isNotEmpty) ...[
                    _finSectionLabel('Split Expenses', Icons.call_split),
                    const SizedBox(height: 6),
                    ...splitExpenses.map(
                      (e) => _DetailRow(
                        label: e['itemName'] as String,
                        value: (e['amount'] as num).toDouble(),
                        color: Colors.deepPurple.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (deposits.isNotEmpty) ...[
                    _finSectionLabel('Deposits', Icons.savings_outlined),
                    const SizedBox(height: 6),
                    ...deposits.map(
                      (e) => _DetailRow(
                        label: (e['note'] as String?)?.isNotEmpty == true
                            ? e['note'] as String
                            : 'Deposit',
                        value: (e['amount'] as num).toDouble(),
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                  if (cartExpenses.isEmpty &&
                      splitExpenses.isEmpty &&
                      deposits.isEmpty)
                    const Text(
                      'No transactions yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _finSectionLabel(String text, IconData icon) => Row(
  children: [
    Icon(icon, size: 14, color: Colors.grey.shade600),
    const SizedBox(width: 6),
    Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    ),
  ],
);

class _MiniStatChip extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool showSign;

  const _MiniStatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.showSign = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = showSign && value < 0
        ? '-৳${value.abs().toStringAsFixed(0)}'
        : '৳${value.abs().toStringAsFixed(0)}';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              display,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            '৳${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

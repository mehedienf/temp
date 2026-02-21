import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SessionHistoryScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isAdmin;
  final String adminId;

  const SessionHistoryScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isAdmin = false,
    this.adminId = '',
  });

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>>? _sessions;
  List<Map<String, dynamic>> _deposits = [];
  List<Map<String, dynamic>> _splitExpenses = [];
  String? _error;
  bool _loading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getSessions(widget.roomId),
        ApiService.getFinanceHistory(widget.roomId),
      ]);
      final sessions = results[0] as List<Map<String, dynamic>>;
      final financeData = results[1] as Map<String, dynamic>;
      setState(() {
        _sessions = sessions;
        _deposits = (financeData['deposits'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _splitExpenses = (financeData['splitExpenses'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('History', style: TextStyle(fontSize: 16)),
            Text(
              widget.roomName,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Sessions'),
            Tab(icon: Icon(Icons.savings_outlined), text: 'Deposits'),
            Tab(icon: Icon(Icons.call_split), text: 'Split'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(_error!),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsTab(theme),
                _buildDepositsTab(theme),
                _buildSplitExpensesTab(theme),
              ],
            ),
    );
  }

  Widget _buildSessionsTab(ThemeData theme) {
    final sessions = _sessions!;
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            const Text('No sessions yet'),
            const SizedBox(height: 4),
            Text(
              'Completed sessions will appear here',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => _SessionCard(
        session: sessions[i],
        isAdmin: widget.isAdmin,
        adminId: widget.adminId,
        roomId: widget.roomId,
        onDelete: _load,
      ),
    );
  }

  Widget _buildDepositsTab(ThemeData theme) {
    if (_deposits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.savings_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            const Text('No deposits yet'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _deposits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _DepositHistoryCard(
        deposit: _deposits[i],
        isAdmin: widget.isAdmin,
        adminId: widget.adminId,
        roomId: widget.roomId,
        onDeleted: _load,
      ),
    );
  }

  Widget _buildSplitExpensesTab(ThemeData theme) {
    if (_splitExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.call_split,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            const Text('No split expenses yet'),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _splitExpenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final exp = _splitExpenses[i];
        // Try to find a matching deposit: same amount and note equal to itemName
        String? payerName;
        final expName = exp['itemName'] as String? ?? '';
        final expAmount = (exp['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final match = _deposits.firstWhere(
          (d) => (d['note'] as String? ?? '') == expName && ((d['amount'] as num?)?.toDouble() ?? 0.0) == expAmount,
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) payerName = match['userName'] as String? ?? '';
        return _SplitExpenseHistoryCard(
          expense: exp,
          isAdmin: widget.isAdmin,
          adminId: widget.adminId,
          roomId: widget.roomId,
          onDeleted: _load,
          paidByName: payerName,
        );
      },
    );
  }
}

class _SessionCard extends StatefulWidget {
  final Map<String, dynamic> session;
  final bool isAdmin;
  final String adminId;
  final String roomId;
  final VoidCallback? onDelete;

  const _SessionCard({
    required this.session,
    this.isAdmin = false,
    this.adminId = '',
    this.roomId = '',
    this.onDelete,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.session;
    final sessionNumber = s['sessionNumber'] as int;
    final grandTotal = (s['grandTotal'] as num).toDouble();
    final members = (s['members'] as List<dynamic>?) ?? [];
    final createdAt = s['createdAt'] != null
        ? DateTime.tryParse(s['createdAt'].toString())
        : null;

    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#$sessionNumber',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session $sessionNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '৳ ${grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.isAdmin)
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade400,
                      ),
                      tooltip: 'Delete session',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Session?'),
                            content: Text(
                              'Delete Session #$sessionNumber? This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        try {
                          final sessionId =
                              widget.session['id'] as String? ?? '';
                          await ApiService.deleteSession(
                            widget.roomId,
                            widget.adminId,
                            sessionId,
                          );
                          widget.onDelete?.call();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                        }
                      },
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // ── Expanded member breakdown ────────────────────────────────────
          if (_expanded) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            ...members.asMap().entries.map((entry) {
              final idx = entry.key;
              final m = entry.value as Map<String, dynamic>;
              final name = m['name'] as String? ?? '';
              final total = (m['total'] as num?)?.toDouble() ?? 0.0;
              final items = (m['items'] as List<dynamic>?) ?? [];
              final isEven = idx % 2 == 0;

              return Container(
                color: isEven
                    ? null
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.4,
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '৳ ${total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: total > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...items.map((it) {
                      final itMap = it as Map<String, dynamic>;
                      final iName = itMap['name'] as String? ?? '';
                      final qty = itMap['quantity'] as int? ?? 0;
                      final price =
                          (itMap['unitPrice'] as num?)?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(44, 2, 16, 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                iName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Text(
                              '$qty×',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '৳ ${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            }),
            // Grand total footer
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Grand Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '৳ ${grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
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

// ── Deposit history card ──────────────────────────────────────────────────────

class _DepositHistoryCard extends StatelessWidget {
  final Map<String, dynamic> deposit;
  final bool isAdmin;
  final String adminId;
  final String roomId;
  final VoidCallback? onDeleted;

  const _DepositHistoryCard({
    required this.deposit,
    this.isAdmin = false,
    this.adminId = '',
    this.roomId = '',
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depositId = deposit['id'] as String? ?? '';
    final amount = (deposit['amount'] as num).toDouble();
    final userName = deposit['userName'] as String? ?? '';
    final note = deposit['note'] as String? ?? '';
    final addedBy = deposit['addedByName'] as String? ?? '';
    final createdAt = deposit['createdAt'] != null
        ? DateTime.tryParse(deposit['createdAt'].toString())
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.savings_outlined,
                color: Colors.blue.shade700,
                size: 22,
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
                          'For $userName',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (addedBy.isNotEmpty && addedBy != userName) ...[
                        Text(
                          '  ·  by $addedBy',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '+৳${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.blue.shade700,
              ),
            ),
            if (isAdmin && depositId.isNotEmpty) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Colors.red.shade400,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                tooltip: 'Delete deposit',
                onPressed: () async {
                  final label = note.isNotEmpty ? note : 'For $userName';
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Deposit?'),
                      content: Text('Delete "$label"? This cannot be undone.'),
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
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm != true || !context.mounted) return;
                  try {
                    await ApiService.deleteDeposit(roomId, adminId, depositId);
                    onDeleted?.call();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Split expense history card ────────────────────────────────────────────────

class _SplitExpenseHistoryCard extends StatefulWidget {
  final Map<String, dynamic> expense;
  final bool isAdmin;
  final String adminId;
  final String roomId;
  final VoidCallback? onDeleted;
  final String? paidByName;

  const _SplitExpenseHistoryCard({
    required this.expense,
    this.isAdmin = false,
    this.adminId = '',
    this.roomId = '',
    this.onDeleted,
    this.paidByName,
  });

  @override
  State<_SplitExpenseHistoryCard> createState() =>
      _SplitExpenseHistoryCardState();
}

class _SplitExpenseHistoryCardState extends State<_SplitExpenseHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expense = widget.expense;
    final expenseId = expense['id'] as String? ?? '';
    final itemName = expense['itemName'] as String? ?? '';
    final totalAmount = (expense['totalAmount'] as num).toDouble();
    final perMember = (expense['perMemberAmount'] as num).toDouble();
    final memberCount = expense['memberCount'] as int? ?? 0;
    final members = (expense['members'] as List<dynamic>? ?? [])
        .map((m) => m as Map<String, dynamic>)
        .toList();
    final createdAt = expense['createdAt'] != null
        ? DateTime.tryParse(expense['createdAt'].toString())
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/'
              '${createdAt.month.toString().padLeft(2, '0')}/'
              '${createdAt.year}  '
              '${createdAt.hour.toString().padLeft(2, '0')}:'
              '${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row (always visible) ──────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.call_split,
                      color: Colors.deepPurple.shade600,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if ((widget.paidByName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Paid by ${widget.paidByName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          '৳${perMember.toStringAsFixed(2)} × $memberCount members',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '৳${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.deepPurple.shade600,
                    ),
                  ),
                  if (widget.isAdmin && expenseId.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade400,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      tooltip: 'Delete split expense',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Split Expense?'),
                            content: Text(
                              'Delete "$itemName"? This cannot be undone.',
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
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        try {
                          await ApiService.deleteSplitExpense(
                            widget.roomId,
                            widget.adminId,
                            expenseId,
                          );
                          widget.onDeleted?.call();
                        } catch (e) {
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
                    ),
                  ],
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          // ── Expandable member list ────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Split among',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (members.isEmpty)
                        Text(
                          'No member data available',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        ...members.map((m) {
                          final name = m['name'] as String? ?? '';
                          final amount =
                              (m['amount'] as num?)?.toDouble() ?? perMember;
                          final isLeft = name.endsWith('(left)');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isLeft
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                      : theme.colorScheme.primaryContainer,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isLeft
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isLeft
                                          ? theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5)
                                          : null,
                                    ),
                                  ),
                                ),
                                Text(
                                  '৳${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Colors.deepPurple.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

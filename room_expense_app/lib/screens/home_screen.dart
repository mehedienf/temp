import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/room_model.dart';
import '../providers/app_provider.dart';
import 'auth_screen.dart';
import 'room_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadUserRooms();
    });
  }

  Future<void> _openRoom(RoomModel room) async {
    try {
      await context.read<AppProvider>().openRoom(room.id);
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const RoomScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showCreateRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Create Room'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. Trip to Cox\'s Bazar',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a room name'
                    : null,
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
                          await context.read<AppProvider>().createRoom(
                            controller.text,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RoomScreen(),
                            ),
                          );
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
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showJoinRoomDialog(BuildContext context) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Join Room'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Room Code',
                  hintText: 'Enter 6-character code',
                  border: const OutlineInputBorder(),
                  errorText: errorMsg,
                ),
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                maxLength: 6,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a room code'
                    : null,
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
                        setState(() {
                          isLoading = true;
                          errorMsg = null;
                        });
                        try {
                          await context.read<AppProvider>().joinRoom(
                            controller.text,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RoomScreen(),
                            ),
                          );
                        } catch (e) {
                          setState(() {
                            isLoading = false;
                            errorMsg = 'Room not found. Check the code.';
                          });
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
                    : const Text('Join'),
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
    final user = provider.currentUser;
    final rooms = provider.userRooms;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Expense'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              provider.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // User card
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(user?.name ?? ''),
                subtitle: Text('@${user?.username ?? ''}'),
              ),
            ),

            // Rooms section
            if (rooms.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Text(
                    'My Rooms',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${rooms.length}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...rooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _RoomCard(room: room, onTap: () => _openRoom(room)),
                ),
              ),
            ],

            const SizedBox(height: 28),
            Text(
              'What do you want to do?',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              icon: Icons.add_home_outlined,
              title: 'Create a Room',
              subtitle: 'Start a new expense group and invite others',
              color: theme.colorScheme.primaryContainer,
              onTap: () => _showCreateRoomDialog(context),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.door_front_door_outlined,
              title: 'Join a Room',
              subtitle: 'Enter a room code to join an existing group',
              color: theme.colorScheme.secondaryContainer,
              onTap: () => _showJoinRoomDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Room Card ────────────────────────────────────────────────────────────────

class _RoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.meeting_room_outlined,
                  size: 22,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.code,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSecondaryContainer,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

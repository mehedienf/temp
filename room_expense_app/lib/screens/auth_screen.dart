import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'home_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.meeting_room_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Room Expense',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track shared expenses with your group',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Theme.of(context).colorScheme.onPrimary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Login'),
                      Tab(text: 'Sign Up'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: TabBarView(children: [_LoginTab(), _SignupTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Login Tab ────────────────────────────────────────────────────────────────

class _LoginTab extends StatefulWidget {
  const _LoginTab();

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.text,
              autocorrect: false,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your username'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _loading ? null : _login,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Login', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sign Up Tab ──────────────────────────────────────────────────────────────

class _SignupTab extends StatefulWidget {
  const _SignupTab();

  @override
  State<_SignupTab> createState() => _SignupTabState();
}

class _SignupTabState extends State<_SignupTab> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AppProvider>().signup(
        _usernameCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Choose a unique username',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a username';
                if (v.trim().length < 3) return 'At least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'Your full name or nickname',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _signup(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirm your password';
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _loading ? null : _signup,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

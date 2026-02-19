import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/auth_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const RoomExpenseApp(),
    ),
  );
}

class RoomExpenseApp extends StatelessWidget {
  const RoomExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Room Expense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6AF5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 1),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6AF5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(elevation: 1),
      ),
      themeMode: ThemeMode.system,
      home: const AuthScreen(),
    );
  }
}

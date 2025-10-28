// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inventory_provider.dart';
import 'inventory_screen.dart';
import 'user_provider.dart';
import 'login_screen.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: MaterialApp(
        title: 'DEPO SUMBER BANGUNAN INVENTORY',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.teal,
          ),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // font family Poppins
        ),
        home: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            if (userProvider.activeUser != null) {
              return const InventoryScreen();
            } else {
              return const LoginScreen();
            }
          },
        ),
      ),
    );
  }
}

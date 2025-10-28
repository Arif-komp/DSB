// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'inventory_provider.dart';
import 'inventory_screen.dart';
import 'user_provider.dart';
import 'login_screen.dart'; // Asumsi: Anda memiliki halaman login

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
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Poppins', // Pastikan font Poppins tersedia atau hapus baris ini
        ),
        // Menggunakan Consumer untuk menentukan halaman mana yang harus ditampilkan (Login/Inventory)
        home: Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            // Jika user aktif ada, tampilkan InventoryScreen
            if (userProvider.activeUser != null) {
              return const InventoryScreen();
            } else {
              // Jika tidak ada user, arahkan ke LoginScreen
              return const LoginScreen(); // Ganti dengan widget login Anda
            }
          },
        ),
      ),
    );
  }
}


// Contoh sederhana Login Screen. Anda harus membuat file login_screen.dart
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Login User')),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Masukkan Nama User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: usernameController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Nama User (Contoh: BOBI)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (usernameController.text.trim().isNotEmpty) {
                  userProvider.login(usernameController.text);
                }
              },
              child: const Text('MASUK'),
            ),
          ],
        ),
      ),
    );
  }
}

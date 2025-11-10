import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/firebase_service.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);
  // Keep default Flutter colors; no custom palette required
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    // Light theme: white surfaces, indigo primary, amber accents.
    final base = ThemeData.light();
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.indigo,
        secondary: Colors.amber,
        background: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black87),
          titleTextStyle: const TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600)),
      cardTheme: base.cardTheme.copyWith(
          color: Colors.white,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.indigo),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.indigo,
            side: BorderSide(color: Colors.indigo.shade100)),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
          backgroundColor: Colors.amber[700], foregroundColor: Colors.black),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
      ),
      textTheme: base.textTheme
          .apply(bodyColor: Colors.black87, displayColor: Colors.black87),
    );

    return MaterialApp(
      title: 'BookSwap',
      theme: theme,
      home: authState.when(
        data: (user) {
          if (user == null) return LoginScreen();
          if (!user.emailVerified) return VerifyEmailScreen();
          return HomeScreen();
        },
        loading: () =>
            Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      ),
    );
  }
}

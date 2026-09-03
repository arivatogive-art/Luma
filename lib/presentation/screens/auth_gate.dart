// Pfad: lib/presentation/screens/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../features/shell/presentation/main_shell_screen.dart';
import 'start_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _AuthGateLoadingScreen();
        }

        final user = snapshot.data ?? FirebaseAuth.instance.currentUser;

        if (user == null) {
          return const StartScreen();
        }

        return const MainShellScreen();
      },
    );
  }
}

class _AuthGateLoadingScreen extends StatelessWidget {
  const _AuthGateLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFFCF8),
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFE58A2B),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:prosforagiftshop/home_page.dart';
import 'package:prosforagiftshop/login_page.dart';
import 'package:prosforagiftshop/gift_api.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (mockApiEnabled) return const HomePage();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const HomePage();
        }

        return const LoginPage();
      },
    );
  }
}

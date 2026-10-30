import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:prosforagiftshop/firebase_options.dart';
import 'package:prosforagiftshop/main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      routes: {'/login': (context) => const MainPage()},

      home: const MainPage(),
    );
  }
}

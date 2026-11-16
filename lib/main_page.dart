import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:prosforagiftshop/home_page.dart';
import 'package:prosforagiftshop/login_page.dart';

abstract final class GiftShopColors {
  static const lilacFizz = Color(0xFFB993B8);
  static const cottonCandy = Color(0xFFF1B5C2);
  static const mauvelous = Color(0xFFDE8A9B);
  static const polarSky = Color(0xFFAFBFD1);
  static const denim = Color(0xFF7F91B3);
  static const canvas = Color(0xFFF7F4F6);
  static const ink = Color(0xFF59485C);
  static const mutedInk = Color(0xFF596B8D);
}

ThemeData buildGiftShopTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: GiftShopColors.mauvelous,
    onPrimary: GiftShopColors.ink,
    secondary: GiftShopColors.denim,
    onSecondary: Colors.white,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: GiftShopColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: GiftShopColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: GiftShopColors.mauvelous,
      foregroundColor: GiftShopColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: GiftShopColors.lilacFizz.withAlpha(75)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: GiftShopColors.mauvelous),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: GiftShopColors.lilacFizz.withAlpha(100)),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: GiftShopColors.denim,
      unselectedLabelColor: GiftShopColors.mutedInk,
      indicatorColor: GiftShopColors.mauvelous,
      dividerColor: GiftShopColors.cottonCandy,
    ),
    chipTheme: const ChipThemeData(
      selectedColor: GiftShopColors.mauvelous,
      secondarySelectedColor: GiftShopColors.cottonCandy,
      backgroundColor: GiftShopColors.canvas,
      side: BorderSide(color: GiftShopColors.lilacFizz),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: GiftShopColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
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

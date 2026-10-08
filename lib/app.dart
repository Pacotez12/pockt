import 'package:flutter/material.dart';

class PocktApp extends StatelessWidget {
  const PocktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Pockt',
      themeMode: ThemeMode.system,
      home: Scaffold(
        backgroundColor: Colors.black,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pockt/core/design/theme.dart';

import 'package:pockt/features/entry/ui/entry_flow.dart';

class PocktApp extends StatelessWidget {
  const PocktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pockt',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.add, size: 48, color: Colors.white),
              onPressed: () => showEntryFlow(context),
            ),
          ),
        ),
      ),
    );
  }
}

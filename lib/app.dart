import 'package:flutter/material.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';

class PocktApp extends StatelessWidget {
  const PocktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pockt',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
    );
  }
}

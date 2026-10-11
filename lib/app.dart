import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/recurring/domain/suggestion_generator.dart';
import 'package:pockt/features/security/app_lock.dart';
import 'package:pockt/features/shell/ui/app_shell.dart';
import 'package:pockt/features/splash/ui/pockt_splash.dart';

class PocktApp extends ConsumerStatefulWidget {
  const PocktApp({super.key});

  @override
  ConsumerState<PocktApp> createState() => _PocktAppState();
}

class _PocktAppState extends ConsumerState<PocktApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSuggestionGenerator();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(appLockControllerProvider).onPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appLockControllerProvider).onResumed();
      _runSuggestionGenerator();
    }
  }

  void _runSuggestionGenerator() {
    unawaited(
      ref.read(suggestionGeneratorProvider).run().catchError((_) => 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appearanceProvider).value ?? ThemeMode.system;

    return MaterialApp(
      title: 'Pockt',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'PY'),
        Locale('es'),
      ],
      locale: const Locale('es', 'PY'),
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      home: const AppLockGate(
        child: PocktSplash(child: AppShell()),
      ),
    );
  }
}



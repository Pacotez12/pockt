import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/theme.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/capture/data/capture_service.dart';
import 'package:pockt/features/onboarding/domain/onboarding_check.dart';
import 'package:pockt/features/onboarding/ui/onboarding_flow.dart';
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
  StreamSubscription<RawSms>? _smsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _smsSub = ref.read(smsSourceProvider).incomingSms.listen((sms) async {
      final enabled = await ref
          .read(settingsRepositoryProvider)
          .get(SettingsKeys.captureSmsEnabled);
      if (enabled == 'true') {
        await ref.read(captureServiceProvider).ingest([sms]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSuggestionGenerator();
      _runSmsCaptureSync();
      _runBackupIfDue();
    });
  }

  @override
  void dispose() {
    _smsSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(appLockControllerProvider).onPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appLockControllerProvider).onResumed();
      ref.read(amountsRevealedProvider.notifier).reset();
      _runSuggestionGenerator();
      _runSmsCaptureSync();
      _runBackupIfDue();
    }
  }

  /// Backup automático en primer plano (spec §7): cada 48 h al abrir/volver.
  void _runBackupIfDue() {
    unawaited(
      ref.read(backupServiceProvider).backupIfDue().catchError((_) => null),
    );
  }

  void _runSuggestionGenerator() {
    unawaited(ref.read(suggestionGeneratorProvider).run().catchError((_) => 0));
  }

  void _runSmsCaptureSync() {
    unawaited(
      ref.read(captureServiceProvider).syncInbox().catchError((_) => 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appearanceProvider).value ?? ThemeMode.system;
    final reduceMotion = ref.watch(motionReduceProvider).value ?? false;

    return MaterialApp(
      title: 'Pockt',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        if (reduceMotion) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          );
        }
        return child;
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'PY'), Locale('es')],
      locale: const Locale('es', 'PY'),
      themeAnimationDuration: const Duration(milliseconds: 400),
      themeAnimationCurve: Curves.easeInOut,
      home: const AppLockGate(
        child: PocktSplash(child: OnboardingGate(child: AppShell())),
      ),
    );
  }
}

class OnboardingGate extends ConsumerWidget {
  final Widget child;

  const OnboardingGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showAsync = ref.watch(shouldShowOnboardingProvider);

    return showAsync.when(
      data: (show) {
        if (show) {
          return OnboardingFlow(
            onFinish: () {
              ref.invalidate(shouldShowOnboardingProvider);
            },
          );
        }
        return child;
      },
      loading: () => const ColoredBox(color: Colors.black),
      error: (e, st) => child,
    );
  }
}

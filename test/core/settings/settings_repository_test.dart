import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    );
    repo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsRepository', () {
    test('get devuelve null si la clave no existe', () async {
      final value = await repo.get('appearance');
      expect(value, isNull);
    });

    test('set guarda valor y get lo recupera', () async {
      await repo.set('appearance', 'dark');
      final value = await repo.get('appearance');
      expect(value, equals('dark'));
    });

    test('set sobreescribe valor existente', () async {
      await repo.set('appearance', 'light');
      expect(await repo.get('appearance'), equals('light'));

      await repo.set('appearance', 'dark');
      expect(await repo.get('appearance'), equals('dark'));
    });

    test('watch emite valor inicial y reacciona a cambios con set', () async {
      final stream = repo.watch('appearance');
      final expectation = expectLater(
        stream,
        emitsInOrder([
          null,
          'dark',
          'system',
        ]),
      );

      // Esperar brevemente a que el stream emita el inicial
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.set('appearance', 'dark');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.set('appearance', 'system');

      await expectation;
    });
  });

  group('appearanceProvider', () {
    test('sin valor en settings devuelve ThemeMode.system por defecto', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(appearanceProvider, (_, _) {});
      addTearDown(sub.close);

      final mode = await container.read(appearanceProvider.future);
      expect(mode, equals(ThemeMode.system));
    });

    test('con dark en settings devuelve ThemeMode.dark', () async {
      await repo.set('appearance', 'dark');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(appearanceProvider, (_, _) {});
      addTearDown(sub.close);

      final mode = await container.read(appearanceProvider.future);
      expect(mode, equals(ThemeMode.dark));
    });

    test('con light en settings devuelve ThemeMode.light', () async {
      await repo.set('appearance', 'light');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(appearanceProvider, (_, _) {});
      addTearDown(sub.close);

      final mode = await container.read(appearanceProvider.future);
      expect(mode, equals(ThemeMode.light));
    });
  });

  group('monthStartModeProvider', () {
    test('por defecto devuelve MonthStartMode.calendar', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(monthStartModeProvider, (_, _) {});
      addTearDown(sub.close);

      final mode = await container.read(monthStartModeProvider.future);
      expect(mode, equals(MonthStartMode.calendar));
    });

    test('con payday en settings devuelve MonthStartMode.payday', () async {
      await repo.set(SettingsKeys.periodMonthStart, 'payday');

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(monthStartModeProvider, (_, _) {});
      addTearDown(sub.close);

      final mode = await container.read(monthStartModeProvider.future);
      expect(mode, equals(MonthStartMode.payday));
    });
  });
}


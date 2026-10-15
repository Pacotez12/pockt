import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/safe_to_spend/domain/tone.dart';

void main() {
  group('Tono y Banco de mensajes ¿Lo compro?', () {
    test('ToneLevel parsea correctamente y usa normal por defecto', () {
      expect(parseToneLevel('soft'), equals(ToneLevel.soft));
      expect(parseToneLevel('normal'), equals(ToneLevel.normal));
      expect(parseToneLevel('spicy'), equals(ToneLevel.spicy));
      expect(parseToneLevel(null), equals(ToneLevel.normal));
      expect(parseToneLevel('otro'), equals(ToneLevel.normal));

      expect(ToneLevel.soft.key, equals('soft'));
      expect(ToneLevel.normal.key, equals('normal'));
      expect(ToneLevel.spicy.key, equals('spicy'));
    });

    test('determineBuySituation prioriza situaciones en el orden correcto', () {
      // 1. Rompe presupuesto: máxima prioridad de advertencia
      expect(
        determineBuySituation(
          safeToSpendAfter: 50000,
          budgetRemainingAfter: -20000,
          maxGoalDelayDays: 0,
        ),
        equals(BuySituation.breaksBudget),
      );

      // 2. Atrasar meta: si el presupuesto no se rompe pero se atrasa una meta
      expect(
        determineBuySituation(
          safeToSpendAfter: 50000,
          budgetRemainingAfter: 100000,
          maxGoalDelayDays: 4,
        ),
        equals(BuySituation.delaysGoal),
      );

      // 3. Pasa el día: podés gastar hoy después queda negativo
      expect(
        determineBuySituation(
          safeToSpendAfter: -30000,
          budgetRemainingAfter: null, // Sin presupuesto en la categoría
          maxGoalDelayDays: 0,
        ),
        equals(BuySituation.exceedsDay),
      );

      // 4. Dentro del día: todo en orden
      expect(
        determineBuySituation(
          safeToSpendAfter: 20000,
          budgetRemainingAfter: 50000,
          maxGoalDelayDays: 0,
        ),
        equals(BuySituation.withinDay),
      );
    });

    test('cada combinación de tono y situación tiene al menos 3 mensajes y no contienen emojis', () {
      final emojiRegex = RegExp(
        r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1FA00}-\u{1FAFF}]',
        unicode: true,
      );

      for (final tone in ToneLevel.values) {
        for (final situation in BuySituation.values) {
          final bank = getBuyMessagesBank(tone: tone, situation: situation);
          expect(
            bank.length,
            greaterThanOrEqualTo(3),
            reason:
                'Tono $tone y situación $situation debe tener al menos 3 variantes',
          );

          for (final msg in bank) {
            expect(msg.trim(), isNotEmpty);
            expect(
              emojiRegex.hasMatch(msg),
              isFalse,
              reason: 'El mensaje "$msg" no debe contener emojis',
            );
          }
        }
      }
    });

    test(
      'getBuyMessage selecciona variantes válidas según índice o aleatorio',
      () {
        final msg0 = getBuyMessage(
          tone: ToneLevel.spicy,
          situation: BuySituation.withinDay,
          variantIndex: 0,
        );
        final msg1 = getBuyMessage(
          tone: ToneLevel.spicy,
          situation: BuySituation.withinDay,
          variantIndex: 1,
        );
        expect(msg0, isNotEmpty);
        expect(msg1, isNotEmpty);
        expect(msg0, isNot(equals(msg1)));
      },
    );

    test('SettingsRepository almacena y lee tone.level', () async {
      final db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final repo = SettingsRepository(db);

      // Valor inicial: null en DB -> helper o provider da normal
      final initialVal = await repo.get(SettingsKeys.toneLevel);
      expect(initialVal, isNull);

      await repo.set(SettingsKeys.toneLevel, ToneLevel.spicy.key);
      final savedVal = await repo.get(SettingsKeys.toneLevel);
      expect(savedVal, equals('spicy'));
      expect(parseToneLevel(savedVal), equals(ToneLevel.spicy));

      await db.close();
    });
  });
}

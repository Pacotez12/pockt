import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/entry/domain/entry_form_logic.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

void main() {
  const foodCategory = Category(
    id: 'cat-food',
    name: 'Comida',
    icon: 'fork-knife',
    colorDark: 0xFFFF8A4C,
    colorLight: 0xFFE66A2C,
    kind: CategoryKind.expense,
    sortOrder: 0,
    archived: false,
  );

  const transportCategory = Category(
    id: 'cat-transport',
    name: 'Transporte',
    icon: 'car',
    colorDark: 0xFF4CA8FF,
    colorLight: 0xFF2C82E6,
    kind: CategoryKind.expense,
    sortOrder: 1,
    archived: false,
  );

  group('EntryKeypadSeed.fromArgs (armar estado inicial del movimiento)', () {
    test('usa datos del movimiento cuando se está editando', () {
      final now = DateTime(2026, 10, 16, 15, 30);
      final tx = Transaction(
        id: 'tx-1',
        type: TxType.expense,
        amount: 45000,
        currency: 'PYG',
        categoryId: foodCategory.id,
        merchant: 'Superseis',
        note: 'Almuerzo',
        loanId: 'loan-99',
        occurredAt: DateTime.utc(2026, 10, 14, 18, 0),
        createdAt: DateTime.utc(2026, 10, 14, 18, 0),
        updatedAt: DateTime.utc(2026, 10, 14, 18, 0),
        source: TxSource.manual,
        isExtra: false,
      );
      final editing = TxView(tx: tx, category: foodCategory);

      final seed = EntryKeypadSeed.fromArgs(
        category: foodCategory,
        editing: editing,
        nowLocal: now,
      );

      expect(seed.digits, '45000');
      expect(seed.merchant, 'Superseis');
      expect(seed.note, 'Almuerzo');
      expect(seed.loanId, 'loan-99');
    });

    test('usa valores iniciales o vacíos cuando es nuevo movimiento', () {
      final now = DateTime(2026, 10, 16, 15, 30);
      final customDate = DateTime(2026, 10, 15, 12, 0);

      final seedWithAmount = EntryKeypadSeed.fromArgs(
        category: foodCategory,
        initialAmount: 28500,
        initialDate: customDate,
        initialMerchant: 'Bolt',
        initialLoanId: 'loan-1',
        nowLocal: now,
      );

      expect(seedWithAmount.digits, '28500');
      expect(seedWithAmount.occurredAt, customDate);
      expect(seedWithAmount.merchant, 'Bolt');
      expect(seedWithAmount.note, isNull);
      expect(seedWithAmount.loanId, 'loan-1');

      final seedEmpty = EntryKeypadSeed.fromArgs(
        category: foodCategory,
        initialAmount: 0,
        nowLocal: now,
      );
      expect(seedEmpty.digits, '');
      expect(seedEmpty.occurredAt, now);
    });
  });

  group('formatEntryDateLabel y mergePickedDateWithTime (fecha y hora)', () {
    test('formatea Hoy con hora y minutos con cero a la izquierda', () {
      final now = DateTime(2026, 10, 16, 14, 30);
      final date = DateTime(2026, 10, 16, 8, 5);
      expect(formatEntryDateLabel(date, now), 'Hoy, 08:05');
    });

    test('formatea Ayer y fechas anteriores', () {
      final now = DateTime(2026, 10, 16, 14, 30);
      expect(formatEntryDateLabel(DateTime(2026, 10, 15, 20, 0), now), 'Ayer');
      expect(
        formatEntryDateLabel(DateTime(2026, 10, 2, 10, 0), now),
        '2/10/2026',
      );
    });

    test('mergePickedDateWithTime conserva la hora y minuto previos', () {
      final previous = DateTime(2026, 10, 16, 19, 45);
      final pickedDay = DateTime(2026, 10, 10);
      expect(
        mergePickedDateWithTime(pickedDay, previous),
        DateTime(2026, 10, 10, 19, 45),
      );
    });
  });

  group('resolveEntryNaturalProposal y helpers de texto natural', () {
    test(
      'retorna null con texto en blanco y resuelve propuesta con categoría',
      () {
        final now = DateTime(2026, 10, 16, 14, 0);
        final categories = [foodCategory, transportCategory];
        final keywordMap = {'bolt': transportCategory.id};

        expect(
          resolveEntryNaturalProposal(
            '   ',
            nowLocal: now,
            activeCategories: categories,
            keywordMap: keywordMap,
          ),
          isNull,
        );

        final resolved = resolveEntryNaturalProposal(
          'bolt 28.500 ayer',
          nowLocal: now,
          activeCategories: categories,
          keywordMap: keywordMap,
        );
        expect(resolved, isNotNull);
        expect(resolved!.entry.amount, 28500);
        expect(resolved.category?.id, transportCategory.id);
        expect(
          shouldShowProposalMerchant(resolved.entry, transportCategory),
          isTrue,
        );
      },
    );

    test('oculta comercio si coincide con el nombre de la categoría', () {
      final entry = ParsedEntry(
        amount: 35000,
        categoryId: foodCategory.id,
        merchant: 'Comida',
        occurredLocalDay: DateTime(2026, 10, 16),
      );
      expect(shouldShowProposalMerchant(entry, foodCategory), isFalse);
    });

    test('normalizeOptionalEntryField y shouldPromptForNote', () {
      expect(normalizeOptionalEntryField('  Superseis  '), 'Superseis');
      expect(normalizeOptionalEntryField('   '), isNull);
      expect(normalizeOptionalEntryField(null), isNull);

      expect(
        shouldPromptForNote(
          askNoteEnabled: true,
          alreadyPrompted: false,
          currentNote: null,
        ),
        isTrue,
      );
      expect(
        shouldPromptForNote(
          askNoteEnabled: true,
          alreadyPrompted: true,
          currentNote: null,
        ),
        isFalse,
      );
      expect(
        shouldPromptForNote(
          askNoteEnabled: true,
          alreadyPrompted: false,
          currentNote: 'Cena',
        ),
        isFalse,
      );
    });
  });
}

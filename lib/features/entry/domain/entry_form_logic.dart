import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/entry/domain/natural_parser.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';

/// Estado inicial puro para la pantalla de teclado de carga (`AmountKeypadScreen`).
class EntryKeypadSeed {
  final Category category;
  final String digits;
  final DateTime occurredAt;
  final String? merchant;
  final String? note;
  final String? loanId;

  const EntryKeypadSeed({
    required this.category,
    required this.digits,
    required this.occurredAt,
    required this.merchant,
    required this.note,
    required this.loanId,
  });

  factory EntryKeypadSeed.fromArgs({
    required Category category,
    TxView? editing,
    int? initialAmount,
    DateTime? initialDate,
    String? initialMerchant,
    String? initialLoanId,
    DateTime? nowLocal,
  }) {
    final loanId = initialLoanId ?? editing?.tx.loanId;
    if (editing != null) {
      return EntryKeypadSeed(
        category: category,
        digits: editing.tx.amount.toString(),
        occurredAt: toLocal(editing.tx.occurredAt),
        merchant: editing.tx.merchant,
        note: editing.tx.note,
        loanId: loanId,
      );
    }
    return EntryKeypadSeed(
      category: category,
      digits: initialAmount != null && initialAmount > 0
          ? initialAmount.toString()
          : '',
      occurredAt: initialDate ?? (nowLocal ?? DateTime.now()),
      merchant: initialMerchant,
      note: null,
      loanId: loanId,
    );
  }
}

/// Resultado de evaluar una entrada en lenguaje natural contra las categorías activas.
class ResolvedNaturalProposal {
  final ParsedEntry entry;
  final Category? category;

  const ResolvedNaturalProposal({required this.entry, required this.category});
}

/// Resuelve el texto natural en una propuesta y su categoría asociada, o `null` si está vacío.
ResolvedNaturalProposal? resolveEntryNaturalProposal(
  String text, {
  required DateTime nowLocal,
  required List<Category> activeCategories,
  required Map<String, String> keywordMap,
}) {
  if (text.trim().isEmpty) return null;
  final keywords = keywordMap.isNotEmpty
      ? keywordMap
      : buildKeywordToCategoryIdMap(activeCategories);
  final parsed = parseNaturalEntry(
    text,
    nowLocal: nowLocal,
    keywordToCategoryId: keywords,
  );
  if (parsed == null) return null;
  Category? proposedCategory;
  if (parsed.categoryId != null) {
    proposedCategory = activeCategories
        .where((c) => c.id == parsed.categoryId)
        .firstOrNull;
  }
  return ResolvedNaturalProposal(entry: parsed, category: proposedCategory);
}

/// Indica si en la tarjeta de propuesta rápida debe mostrarse el comercio debajo de la categoría.
bool shouldShowProposalMerchant(ParsedEntry proposal, Category category) {
  return proposal.merchant != null &&
      proposal.merchant!.toLowerCase() != category.name.toLowerCase();
}

/// Formatea la etiqueta del selector de fecha/hora en el teclado de carga.
String formatEntryDateLabel(DateTime date, DateTime now) {
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  final isYesterday =
      date.year == now.year &&
      date.month == now.month &&
      date.day == now.day - 1;

  if (isToday) {
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return 'Hoy, $hour:$min';
  } else if (isYesterday) {
    return 'Ayer';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Combina un día elegido en el calendario con la hora y minuto que ya tenía el movimiento.
DateTime mergePickedDateWithTime(
  DateTime pickedDay,
  DateTime previousDateTime,
) {
  return DateTime(
    pickedDay.year,
    pickedDay.month,
    pickedDay.day,
    previousDateTime.hour,
    previousDateTime.minute,
  );
}

/// Normaliza un campo opcional (comercio o nota): recorta espacios y devuelve `null` si queda vacío.
String? normalizeOptionalEntryField(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Determina si se debe abrir el diálogo de pedir nota antes de guardar.
bool shouldPromptForNote({
  required bool askNoteEnabled,
  required bool alreadyPrompted,
  required String? currentNote,
}) {
  return askNoteEnabled &&
      !alreadyPrompted &&
      (currentNote == null || currentNote.isEmpty);
}

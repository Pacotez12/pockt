import 'package:pockt/features/capture/domain/itau_sms_parser.dart';

enum CaptureClassificationKind {
  expense,
  recurringServicePayment,
  loanPayment,
  cardPaymentTransfer,
  confirmSalarySuggestion,
  salaryIncomeSuggestion,
  ignored,
  unrecognized,
}

class CaptureRecurringCandidate {
  const CaptureRecurringCandidate({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.categoryId,
    this.pendingSuggestionId,
  });

  final String id;
  final String name;
  final int amount;
  final DateTime dueDate;
  final String? categoryId;
  final String? pendingSuggestionId;
}

class CaptureLoanCandidate {
  const CaptureLoanCandidate({
    required this.id,
    required this.name,
    required this.installmentAmount,
  });

  final String id;
  final String name;
  final int installmentAmount;
}

class CaptureSalarySuggestionCandidate {
  const CaptureSalarySuggestionCandidate({
    required this.id,
    required this.amount,
    required this.occurredAt,
    this.categoryId,
  });

  final String id;
  final int amount;
  final DateTime occurredAt;
  final String? categoryId;
}

class CaptureClassification {
  const CaptureClassification({
    required this.kind,
    this.amount,
    this.merchant,
    this.merchantKey,
    this.categoryId,
    this.occurredAt,
    this.recurringRuleId,
    this.replacesSuggestionId,
    this.loanId,
    this.confirmSuggestionId,
    this.autoConfirm = false,
  });

  final CaptureClassificationKind kind;
  final int? amount;
  final String? merchant;
  final String? merchantKey;
  final String? categoryId;
  final DateTime? occurredAt;
  final String? recurringRuleId;
  final String? replacesSuggestionId;
  final String? loanId;
  final String? confirmSuggestionId;
  final bool autoConfirm;
}

final RegExp _cardPaymentRegex = RegExp(
  r'\bpago\s+de\s+tarjeta\b',
  caseSensitive: false,
);

final RegExp _loanPaymentRegex = RegExp(
  r'\bpago\s+de\s+pr[eé]stamos?\b',
  caseSensitive: false,
);

final RegExp _serviceBillRegex = RegExp(
  r'\bpago\s+de\s+factura\b',
  caseSensitive: false,
);

int _calendarDayDiff(DateTime a, DateTime b) {
  final da = DateTime.utc(a.year, a.month, a.day);
  final db = DateTime.utc(b.year, b.month, b.day);
  return da.difference(db).inDays.abs();
}

String? _lookupMerchantCategory(
  String merchantKey,
  String description,
  Map<String, String> merchantMemory,
) {
  if (merchantMemory.isEmpty) return null;

  final direct = merchantMemory[merchantKey];
  if (direct != null) return direct;

  final lowerKey = merchantKey.toLowerCase();
  final lowerDesc = description.toLowerCase();

  String? bestCat;
  var bestLen = 0;
  for (final entry in merchantMemory.entries) {
    final k = entry.key.trim().toLowerCase();
    if (k.isEmpty) continue;
    if (lowerKey == k) return entry.value;
    if ((lowerKey.contains(k) || lowerDesc.contains(k)) && k.length > bestLen) {
      bestLen = k.length;
      bestCat = entry.value;
    }
  }
  return bestCat;
}

CaptureClassification classifyCapture(
  CaptureResult capture, {
  Map<String, String> merchantMemory = const {},
  Set<String> autoConfirmMerchants = const {},
  List<CaptureRecurringCandidate> recurringRules = const [],
  List<CaptureLoanCandidate> activeLoans = const [],
  List<CaptureSalarySuggestionCandidate> pendingSalarySuggestions = const [],
  int? expectedSalaryAmount,
  String? salaryCategoryId,
  String? loansCategoryId,
  String? cardsCategoryId,
}) {
  switch (capture.kind) {
    case CaptureKind.ignored:
      return const CaptureClassification(
        kind: CaptureClassificationKind.ignored,
      );
    case CaptureKind.unrecognized:
      return const CaptureClassification(
        kind: CaptureClassificationKind.unrecognized,
      );
    case CaptureKind.salaryCredit:
      final occurredAt = capture.occurredAt!;
      CaptureSalarySuggestionCandidate? bestMatch;
      var bestDays = 999;
      for (final sug in pendingSalarySuggestions) {
        final days = _calendarDayDiff(occurredAt, sug.occurredAt);
        if (days <= 3 && days < bestDays) {
          bestDays = days;
          bestMatch = sug;
        }
      }
      if (bestMatch != null) {
        return CaptureClassification(
          kind: CaptureClassificationKind.confirmSalarySuggestion,
          confirmSuggestionId: bestMatch.id,
          amount: bestMatch.amount,
          categoryId: bestMatch.categoryId ?? salaryCategoryId,
          merchant: 'Cobro',
          occurredAt: occurredAt,
          autoConfirm: true,
        );
      }
      return CaptureClassification(
        kind: CaptureClassificationKind.salaryIncomeSuggestion,
        amount: expectedSalaryAmount ?? 0,
        categoryId: salaryCategoryId,
        merchant: 'Cobro',
        occurredAt: occurredAt,
        autoConfirm: false,
      );

    case CaptureKind.debit:
      final amount = capture.amount!;
      final description = capture.description ?? '';
      final merchantKey =
          capture.merchantKey ?? extractMerchantKey(description);
      final occurredAt = capture.occurredAt!;

      // 1. Pago de tarjeta -> gasto en Tarjetas (spec §4.3)
      if (_cardPaymentRegex.hasMatch(description)) {
        final categoryId =
            cardsCategoryId ??
            _lookupMerchantCategory(merchantKey, description, merchantMemory);
        final normalizedAuto = autoConfirmMerchants
            .map((e) => e.trim().toLowerCase())
            .toSet();
        final shouldAutoConfirm =
            categoryId != null && normalizedAuto.contains(merchantKey);

        return CaptureClassification(
          kind: CaptureClassificationKind.expense,
          amount: amount,
          merchant: description,
          merchantKey: merchantKey,
          categoryId: categoryId,
          occurredAt: occurredAt,
          autoConfirm: shouldAutoConfirm,
        );
      }

      // 2. Pago de préstamo -> busca préstamo activo con cuota ±5%
      if (_loanPaymentRegex.hasMatch(description)) {
        CaptureLoanCandidate? matchedLoan;
        var bestRatio = 1.0;
        final lowerDesc = description.toLowerCase();
        for (final loan in activeLoans) {
          if (loan.installmentAmount <= 0) continue;
          final diff = (amount - loan.installmentAmount).abs();
          final ratio = diff / loan.installmentAmount;
          if (ratio <= 0.0500001) {
            final nameBonus = lowerDesc.contains(loan.name.toLowerCase())
                ? -0.01
                : 0.0;
            if (matchedLoan == null || (ratio + nameBonus) < bestRatio) {
              bestRatio = ratio + nameBonus;
              matchedLoan = loan;
            }
          }
        }
        if (matchedLoan != null) {
          return CaptureClassification(
            kind: CaptureClassificationKind.loanPayment,
            amount: amount,
            merchant: description,
            merchantKey: merchantKey,
            categoryId: loansCategoryId,
            loanId: matchedLoan.id,
            occurredAt: occurredAt,
          );
        }
        return CaptureClassification(
          kind: CaptureClassificationKind.expense,
          amount: amount,
          merchant: description,
          merchantKey: merchantKey,
          categoryId: loansCategoryId,
          occurredAt: occurredAt,
        );
      }

      // 3. Pago de factura -> busca recurrente con monto ±10% y fecha ±5 días
      if (_serviceBillRegex.hasMatch(description)) {
        CaptureRecurringCandidate? matchedRule;
        var bestScore = 999.0;
        final lowerDesc = description.toLowerCase();
        for (final rule in recurringRules) {
          if (rule.amount <= 0) continue;
          final days = _calendarDayDiff(occurredAt, rule.dueDate);
          if (days > 5) continue;
          final diff = (amount - rule.amount).abs();
          final ratio = diff / rule.amount;
          if (ratio <= 0.1000001) {
            final nameBonus = lowerDesc.contains(rule.name.toLowerCase())
                ? -0.5
                : 0.0;
            final score = ratio + (days * 0.01) + nameBonus;
            if (matchedRule == null || score < bestScore) {
              bestScore = score;
              matchedRule = rule;
            }
          }
        }
        if (matchedRule != null) {
          return CaptureClassification(
            kind: CaptureClassificationKind.recurringServicePayment,
            amount: amount,
            merchant: description,
            merchantKey: merchantKey,
            categoryId: matchedRule.categoryId,
            recurringRuleId: matchedRule.id,
            replacesSuggestionId: matchedRule.pendingSuggestionId,
            occurredAt: occurredAt,
          );
        }
      }

      // 4. Comercio estándar
      final categoryId = _lookupMerchantCategory(
        merchantKey,
        description,
        merchantMemory,
      );
      final normalizedAuto = autoConfirmMerchants
          .map((e) => e.trim().toLowerCase())
          .toSet();
      final shouldAutoConfirm =
          categoryId != null && normalizedAuto.contains(merchantKey);

      return CaptureClassification(
        kind: CaptureClassificationKind.expense,
        amount: amount,
        merchant: description,
        merchantKey: merchantKey,
        categoryId: categoryId,
        occurredAt: occurredAt,
        autoConfirm: shouldAutoConfirm,
      );
  }
}

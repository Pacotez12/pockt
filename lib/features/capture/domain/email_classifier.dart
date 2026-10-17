import 'package:pockt/core/db/tables.dart';
import 'package:pockt/features/capture/domain/capture_classifier.dart';
import 'package:pockt/features/capture/domain/itau_email_parser.dart';
import 'package:pockt/features/capture/domain/itau_sms_parser.dart';

enum EmailOutcomeKind {
  autoApply,
  inbox,
  serviceClassified,
  ignored,
  unrecognized,
}

class EmailRuleView {
  const EmailRuleView({
    required this.action,
    this.categoryId,
    this.loanId,
    required this.autoApply,
  });

  final CounterpartyAction action;
  final String? categoryId;
  final String? loanId;
  final bool autoApply;
}

class EmailClassification {
  const EmailClassification({
    required this.kind,
    this.suggestedAction,
    this.categoryId,
    this.loanId,
    this.service,
  });

  final EmailOutcomeKind kind;
  final CounterpartyAction? suggestedAction;
  final String? categoryId;
  final String? loanId;
  final CaptureClassification? service; // solo servicePayment
}

EmailClassification classifyEmail(
  EmailCapture c, {
  EmailRuleView? rule,
  Set<String> activeLoanIds = const {},
  String? ownerNameKey,
  Map<String, String> merchantMemory = const {},
  Set<String> autoConfirmMerchants = const {},
  List<CaptureRecurringCandidate> recurringRules = const [],
  List<CaptureLoanCandidate> activeLoans = const [],
  String? loansCategoryId,
  String? cardsCategoryId,
}) {
  switch (c.kind) {
    case EmailCaptureKind.ignored:
      return const EmailClassification(kind: EmailOutcomeKind.ignored);

    case EmailCaptureKind.unrecognized:
      return const EmailClassification(kind: EmailOutcomeKind.unrecognized);

    case EmailCaptureKind.servicePayment:
      final description =
          (c.concept ?? c.entity ?? '').replaceAll(' - ', ' ');
      final captureResult = CaptureResult(
        kind: CaptureKind.debit,
        amount: c.amount,
        description: description,
        merchantKey: extractMerchantKey(description),
        occurredAt: c.occurredAt,
        sanitizedRawText: c.sanitizedRawText,
      );
      final serviceResult = classifyCapture(
        captureResult,
        merchantMemory: merchantMemory,
        autoConfirmMerchants: autoConfirmMerchants,
        recurringRules: recurringRules,
        activeLoans: activeLoans,
        loansCategoryId: loansCategoryId,
        cardsCategoryId: cardsCategoryId,
      );
      return EmailClassification(
        kind: EmailOutcomeKind.serviceClassified,
        service: serviceResult,
        categoryId: serviceResult.categoryId,
        loanId: serviceResult.loanId,
      );

    case EmailCaptureKind.transferIn:
    case EmailCaptureKind.transferOut:
      final isTransferIn = c.kind == EmailCaptureKind.transferIn;

      // Transferencia entre cuentas propias
      final normalizedCounterparty =
          c.counterparty != null ? normalizePersonKey(c.counterparty!) : null;
      if (ownerNameKey != null &&
          ownerNameKey.isNotEmpty &&
          normalizedCounterparty != null &&
          normalizedCounterparty == ownerNameKey) {
        return const EmailClassification(
          kind: EmailOutcomeKind.inbox,
          suggestedAction: CounterpartyAction.ignore,
        );
      }

      if (isTransferIn) {
        if (rule == null) {
          return const EmailClassification(
            kind: EmailOutcomeKind.inbox,
            suggestedAction: CounterpartyAction.income,
          );
        }

        final isLoanAction =
            rule.action == CounterpartyAction.loanRepayment ||
            rule.action == CounterpartyAction.loanPayment;
        final isLoanInvalid = isLoanAction &&
            (rule.loanId == null || !activeLoanIds.contains(rule.loanId));

        if (isLoanInvalid) {
          return const EmailClassification(
            kind: EmailOutcomeKind.inbox,
            suggestedAction: CounterpartyAction.income,
          );
        }

        if (rule.autoApply) {
          return EmailClassification(
            kind: EmailOutcomeKind.autoApply,
            suggestedAction: rule.action,
            categoryId: rule.categoryId,
            loanId: rule.loanId,
          );
        }

        return EmailClassification(
          kind: EmailOutcomeKind.inbox,
          suggestedAction: rule.action,
          categoryId: rule.categoryId,
          loanId: rule.loanId,
        );
      } else {
        // transferOut: siempre a la bandeja
        if (rule == null) {
          return const EmailClassification(
            kind: EmailOutcomeKind.inbox,
            suggestedAction: CounterpartyAction.expense,
          );
        }

        final isLoanAction =
            rule.action == CounterpartyAction.loanPayment ||
            rule.action == CounterpartyAction.loanRepayment;
        final isLoanInvalid = isLoanAction &&
            (rule.loanId == null || !activeLoanIds.contains(rule.loanId));

        if (isLoanInvalid) {
          return const EmailClassification(
            kind: EmailOutcomeKind.inbox,
            suggestedAction: CounterpartyAction.expense,
          );
        }

        return EmailClassification(
          kind: EmailOutcomeKind.inbox,
          suggestedAction: rule.action,
          categoryId: rule.categoryId,
          loanId: rule.loanId,
        );
      }
  }
}

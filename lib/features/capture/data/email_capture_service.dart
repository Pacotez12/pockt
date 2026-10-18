import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/capture/data/counterparty_rules_repository.dart';
import 'package:pockt/features/capture/data/email_source.dart';
import 'package:pockt/features/capture/domain/capture_classifier.dart';
import 'package:pockt/features/capture/domain/email_classifier.dart';
import 'package:pockt/features/capture/domain/itau_email_parser.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/keywords_repository.dart';
import 'package:pockt/features/transactions/data/transactions_repository.dart';
import 'package:uuid/uuid.dart';

class EmailCaptureService {
  EmailCaptureService({
    required AppDatabase db,
    required Notifier notifier,
    required EmailSource source,
    SuggestionsRepository? suggestionsRepository,
    TransactionsRepository? transactionsRepository,
    LoansRepository? loansRepository,
    CounterpartyRulesRepository? counterpartyRulesRepository,
    SettingsRepository? settingsRepository,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _db = db,
       _notifier = notifier, // ignore: prefer_initializing_formals
       _source = source, // ignore: prefer_initializing_formals
       _suggestionsRepo =
           suggestionsRepository ?? SuggestionsRepository(db, clock: clock),
       _txRepo = transactionsRepository ?? TransactionsRepository(db),
       _loansRepo = loansRepository ?? LoansRepository(db),
       _rulesRepo =
           counterpartyRulesRepository ?? CounterpartyRulesRepository(db),
       _settingsRepo = settingsRepository ?? SettingsRepository(db),
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Notifier _notifier;
  final EmailSource _source;
  final SuggestionsRepository _suggestionsRepo;
  final TransactionsRepository _txRepo;
  final LoansRepository _loansRepo;
  final CounterpartyRulesRepository _rulesRepo;
  final SettingsRepository _settingsRepo;
  final DateTime Function() _clock;
  final Uuid _uuid;

  Future<int>? _inFlightSync;

  static const _kPrestamosCatId = '018f0000-0000-7000-8000-000000000014';
  static const _kOtrosCatId = '018f0000-0000-7000-8000-000000000010';
  static const _kTarjetasCatId = '018f0000-0000-7000-8000-000000000015';

  Future<bool> connect({required DateTime since}) async {
    final ok = await _source.authorize();
    if (!ok) return false;
    await _settingsRepo.set(SettingsKeys.captureEmailEnabled, 'true');
    await _settingsRepo.set(
      SettingsKeys.captureEmailSince,
      since.toIso8601String(),
    );
    await _settingsRepo.set(SettingsKeys.captureEmailNeedsReconnect, 'false');
    return true;
  }

  Future<void> disconnect() async {
    await _source.disconnect();
    await _settingsRepo.set(SettingsKeys.captureEmailEnabled, 'false');
  }

  Future<int> sync({bool notify = true}) {
    final current = _inFlightSync;
    if (current != null) return current;
    final future = _syncOnce(notify: notify).catchError((Object e) {
      // Los llamadores silencian el error; queda en logcat para diagnosticar (sin datos del correo).
      debugPrint('Captura por correo falló: $e');
      throw e;
    }).whenComplete(() {
      _inFlightSync = null;
    });
    _inFlightSync = future;
    return future;
  }

  Future<int> _syncOnce({required bool notify}) async {
    final enabledStr = await _settingsRepo.get(SettingsKeys.captureEmailEnabled);
    if (enabledStr != 'true') return 0;

    final sinceDate = await _readSinceDate();
    final lastAtStr = await _settingsRepo.get(SettingsKeys.captureEmailLastAt);
    final lastAt = lastAtStr != null ? DateTime.tryParse(lastAtStr) : null;

    final queryFrom = (lastAt != null && lastAt.isAfter(sinceDate))
        ? lastAt
        : sinceDate;

    List<RawEmail> rawEmails;
    try {
      rawEmails = await _source.fetchSince(queryFrom);
    } on GmailReconnectRequired {
      final alreadyNeeds =
          await _settingsRepo.get(SettingsKeys.captureEmailNeedsReconnect) ==
          'true';
      if (!alreadyNeeds) {
        await _settingsRepo.set(
          SettingsKeys.captureEmailNeedsReconnect,
          'true',
        );
        if (notify) {
          await _notifier.show(
            'Pockt',
            'Volvé a conectar Gmail',
            payload: 'settings/capture',
          );
        }
      }
      return 0;
    }

    if (rawEmails.isEmpty) return 0;
    return ingest(rawEmails, notify: notify);
  }

  Future<DateTime> _readSinceDate() async {
    final raw = await _settingsRepo.get(SettingsKeys.captureEmailSince);
    final parsed = raw != null ? DateTime.tryParse(raw) : null;
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return DateTime(2026, 10, 1);
  }

  Future<int> ingest(List<RawEmail> emails, {bool notify = true}) async {
    if (emails.isEmpty) return 0;

    final sinceDate = await _readSinceDate();
    final sorted = List.of(emails)
      ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    var pendingCreatedCount = 0;
    DateTime? latestProcessedAt;
    final prevLastStr = await _settingsRepo.get(SettingsKeys.captureEmailLastAt);
    final prevLastAt = prevLastStr != null
        ? DateTime.tryParse(prevLastStr)
        : null;

    var ownerNameKey = await _settingsRepo.get(
      SettingsKeys.captureEmailOwnerName,
    );

    for (final email in sorted) {
      final parsed = parseItauEmail(
        messageId: email.id,
        subject: email.subject,
        bodyText: email.bodyText,
        receivedAt: email.receivedAt,
      );

      final effectiveTime = parsed.occurredAt ?? email.receivedAt;
      if (effectiveTime.isBefore(sinceDate)) {
        continue;
      }

      if (latestProcessedAt == null ||
          email.receivedAt.isAfter(latestProcessedAt)) {
        latestProcessedAt = email.receivedAt;
      }

      if (parsed.kind == EmailCaptureKind.ignored) {
        continue;
      }

      if (parsed.kind == EmailCaptureKind.unrecognized) {
        if (prevLastAt == null || email.receivedAt.isAfter(prevLastAt)) {
          final curStr = await _settingsRepo.get(
            SettingsKeys.captureEmailUnrecognized,
          );
          final cur = int.tryParse(curStr ?? '') ?? 0;
          await _settingsRepo.set(
            SettingsKeys.captureEmailUnrecognized,
            (cur + 1).toString(),
          );
        }
        continue;
      }

      // Primera enviada fija el titular si estaba vacío
      if (parsed.kind == EmailCaptureKind.transferOut &&
          parsed.payer != null &&
          parsed.payer!.trim().isNotEmpty) {
        if (ownerNameKey == null || ownerNameKey.trim().isEmpty) {
          ownerNameKey = normalizePersonKey(parsed.payer!);
          await _settingsRepo.set(
            SettingsKeys.captureEmailOwnerName,
            ownerNameKey,
          );
        }
      }

      final fingerprint = parsed.fingerprint;

      // 1. Deduplicación por fingerprint de correo
      final existingByFp =
          await (_db.select(_db.suggestedTransactions)
                ..where((s) => s.fingerprint.equals(fingerprint))
                ..limit(1))
              .getSingleOrNull();
      if (existingByFp != null) {
        continue;
      }

      final amount = parsed.amount ?? 0;
      final occurredUtc = effectiveTime.toUtc();
      final occurredLocal = effectiveTime.toLocal();
      final dayStart = DateTime(
        occurredLocal.year,
        occurredLocal.month,
        occurredLocal.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));

      // 2. Unión SMS↔correo: si existe sugerencia o movimiento de SMS con mismo monto y mismo día local
      if (amount > 0) {
        final existingSmsSugs = await (_db.select(_db.suggestedTransactions)
              ..where(
                (s) =>
                    s.amount.equals(amount) &
                    s.occurredAt.isBiggerOrEqualValue(dayStart) &
                    s.occurredAt.isSmallerThanValue(dayEnd),
              ))
            .get();

        final matchedSmsSug = existingSmsSugs
            .where(
              (s) =>
                  (s.fingerprint?.startsWith('sms:') ?? false) ||
                  (s.captureMeta != null &&
                      s.captureMeta!.contains('"channel":"sms"')),
            )
            .firstOrNull;

        if (matchedSmsSug != null) {
          // Completar captureMeta con operationId y concept
          Map<String, dynamic> metaMap = {};
          if (matchedSmsSug.captureMeta != null &&
              matchedSmsSug.captureMeta!.trim().isNotEmpty) {
            try {
              metaMap =
                  jsonDecode(matchedSmsSug.captureMeta!)
                      as Map<String, dynamic>;
            } catch (_) {}
          }
          if (parsed.operationId != null) {
            metaMap['operationId'] = parsed.operationId;
          }
          if (parsed.concept != null) {
            metaMap['concept'] = parsed.concept;
          }
          await (_db.update(_db.suggestedTransactions)
                ..where((s) => s.id.equals(matchedSmsSug.id)))
              .write(
                SuggestedTransactionsCompanion(
                  captureMeta: Value(jsonEncode(metaMap)),
                ),
              );
          continue;
        }

        final existingSmsTxs = await (_db.select(_db.transactions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.amount.equals(amount) &
                    t.occurredAt.isBiggerOrEqualValue(dayStart) &
                    t.occurredAt.isSmallerThanValue(dayEnd) &
                    t.source.equalsValue(TxSource.capture),
              ))
            .get();
        if (existingSmsTxs.isNotEmpty) {
          continue;
        }
      }

      // 3. Regla por persona
      EmailRuleView? ruleView;
      if (parsed.counterparty != null &&
          parsed.counterparty!.trim().isNotEmpty) {
        final normKey = normalizePersonKey(parsed.counterparty!);
        final direction = parsed.kind == EmailCaptureKind.transferIn
            ? TransferDirection.incoming
            : TransferDirection.outgoing;
        final rule = await _rulesRepo.find(normKey, direction);
        if (rule != null) {
          ruleView = EmailRuleView(
            action: rule.action,
            categoryId: rule.categoryId,
            loanId: rule.loanId,
            autoApply: rule.autoApply,
          );
        }
      }

      // 4. Préstamos activos
      final activeLoansRows = await (_db.select(_db.loans)
            ..where((l) => l.closedAt.isNull()))
          .get();
      final activeLoanIds = activeLoansRows.map((l) => l.id).toSet();

      // 5. Contexto para servicio
      Map<String, String> keywordMap = const {};
      List<CaptureRecurringCandidate> recurringCandidates = const [];
      List<CaptureLoanCandidate> loanCandidates = const [];
      Set<String> autoConfirmSet = const {};

      if (parsed.kind == EmailCaptureKind.servicePayment) {
        keywordMap = await KeywordsRepository(_db).keywordMap();
        final memRows = await _db.select(_db.merchantMemory).get();
        autoConfirmSet = {
          for (final m in memRows)
            if (m.autoConfirm) m.merchantKey.trim().toLowerCase(),
        };

        final activeRules = await (_db.select(_db.recurringRules)
              ..where(
                (r) =>
                    r.active.equals(true) & r.type.equalsValue(TxType.expense),
              ))
            .get();
        final pendingRecSugs = await (_db.select(_db.suggestedTransactions)
              ..where(
                (s) =>
                    s.status.equals('pending') &
                    s.source.equalsValue(TxSource.recurring),
              ))
            .get();
        final pendingByRule = <String, SuggestedTransaction>{
          for (final s in pendingRecSugs)
            if (s.sourceRef != null) s.sourceRef!: s,
        };
        recurringCandidates = activeRules.map((r) {
          final pendingSug = pendingByRule[r.id];
          return CaptureRecurringCandidate(
            id: r.id,
            name: r.name,
            amount: r.amount,
            dueDate: pendingSug?.occurredAt ?? r.nextDueDate,
            categoryId: r.categoryId,
            pendingSuggestionId: pendingSug?.id,
          );
        }).toList();

        final oweLoans = activeLoansRows.where(
          (l) => l.direction == LoanDirection.owe,
        );
        loanCandidates = oweLoans
            .where((l) => (l.installmentAmount ?? 0) > 0)
            .map(
              (l) => CaptureLoanCandidate(
                id: l.id,
                name: l.name,
                installmentAmount: l.installmentAmount!,
              ),
            )
            .toList();
      }

      final classification = classifyEmail(
        parsed,
        rule: ruleView,
        activeLoanIds: activeLoanIds,
        ownerNameKey: ownerNameKey,
        merchantMemory: keywordMap,
        autoConfirmMerchants: autoConfirmSet,
        recurringRules: recurringCandidates,
        activeLoans: loanCandidates,
        loansCategoryId: _kPrestamosCatId,
        cardsCategoryId: _kTarjetasCatId,
      );

      final isIncome = parsed.kind == EmailCaptureKind.transferIn;
      final txType = isIncome ? TxType.income : TxType.expense;

      // 6. Detección de duplicado manual
      final dupTx = await _findManualDuplicate(
        type: txType,
        amount: amount,
        occurred: effectiveTime,
        hasTime: parsed.hasTime,
      );

      final metaMap = {
        'channel': 'email',
        'kind': parsed.kind.name,
        if (parsed.counterparty != null) 'counterparty': parsed.counterparty,
        if (parsed.operationId != null) 'operationId': parsed.operationId,
        if (parsed.concept != null) 'concept': parsed.concept,
        if (parsed.entity != null) 'entity': parsed.entity,
      };
      final captureMetaJson = jsonEncode(metaMap);

      switch (classification.kind) {
        case EmailOutcomeKind.ignored:
        case EmailOutcomeKind.unrecognized:
          break;

        case EmailOutcomeKind.autoApply:
          final now = _clock();
          if (classification.suggestedAction == CounterpartyAction.income) {
            await _txRepo.add(
              type: TxType.income,
              amount: amount,
              categoryId: classification.categoryId ?? _kOtrosCatId,
              occurredAt: occurredUtc,
              merchant: parsed.counterparty,
              note: parsed.concept,
            );
          } else if (classification.suggestedAction ==
              CounterpartyAction.loanRepayment) {
            await _loansRepo.recordPayment(
              loanId: classification.loanId!,
              amount: amount,
              date: occurredUtc,
              note: parsed.concept,
            );
          }

          // Guardar sugerencia confirmada para que quede fingerprint
          await _db.into(_db.suggestedTransactions).insert(
            SuggestedTransactionsCompanion.insert(
              id: _uuid.v4(),
              type: txType,
              amount: amount,
              categoryId: Value(classification.categoryId ?? _kOtrosCatId),
              merchant: Value(parsed.counterparty),
              occurredAt: occurredUtc,
              source: TxSource.capture,
              status: 'confirmed',
              rawText: Value(parsed.sanitizedRawText),
              fingerprint: Value(fingerprint),
              captureMeta: Value(captureMetaJson),
              createdAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );

          if (notify) {
            final formatted = formatGs(amount);
            final person = parsed.counterparty ?? '';
            await _notifier.show(
              'Pockt',
              'Ingreso registrado: $person $formatted',
              payload: 'inbox',
            );
          }
          break;

        case EmailOutcomeKind.inbox:
          final sourceRef = dupTx != null
              ? 'dup:${dupTx.id}'
              : (classification.loanId != null
                  ? 'loan:${classification.loanId}'
                  : null);
          final created = await _suggestionsRepo.createIfAbsent(
            type: txType,
            amount: amount,
            categoryId: classification.categoryId,
            merchant: parsed.counterparty,
            occurredAt: occurredUtc,
            source: TxSource.capture,
            sourceRef: sourceRef,
            rawText: parsed.sanitizedRawText,
            fingerprint: fingerprint,
            captureMeta: captureMetaJson,
          );
          if (created) pendingCreatedCount++;
          break;

        case EmailOutcomeKind.serviceClassified:
          final svc = classification.service!;
          switch (svc.kind) {
            case CaptureClassificationKind.ignored:
            case CaptureClassificationKind.unrecognized:
            case CaptureClassificationKind.confirmSalarySuggestion:
            case CaptureClassificationKind.salaryIncomeSuggestion:
              break;

            case CaptureClassificationKind.recurringServicePayment:
              if (svc.replacesSuggestionId != null) {
                await (_db.delete(_db.suggestedTransactions)
                      ..where((s) => s.id.equals(svc.replacesSuggestionId!)))
                    .go();
              }
              final sourceRef = dupTx != null
                  ? 'dup:${dupTx.id}'
                  : (svc.recurringRuleId != null
                      ? 'rule:${svc.recurringRuleId}'
                      : null);
              final created = await _suggestionsRepo.createIfAbsent(
                type: TxType.expense,
                amount: amount,
                categoryId: svc.categoryId,
                merchant: svc.merchant,
                occurredAt: occurredUtc,
                source: TxSource.capture,
                sourceRef: sourceRef,
                rawText: parsed.sanitizedRawText,
                fingerprint: fingerprint,
                captureMeta: captureMetaJson,
              );
              if (created) pendingCreatedCount++;
              break;

            case CaptureClassificationKind.loanPayment:
              final sourceRef = dupTx != null
                  ? 'dup:${dupTx.id}'
                  : (svc.loanId != null ? 'loan:${svc.loanId}' : null);
              final created = await _suggestionsRepo.createIfAbsent(
                type: TxType.expense,
                amount: amount,
                categoryId: svc.categoryId,
                merchant: svc.merchant,
                occurredAt: occurredUtc,
                source: TxSource.capture,
                sourceRef: sourceRef,
                rawText: parsed.sanitizedRawText,
                fingerprint: fingerprint,
                captureMeta: captureMetaJson,
              );
              if (created) pendingCreatedCount++;
              break;

            case CaptureClassificationKind.cardPaymentTransfer:
            case CaptureClassificationKind.expense:
              if (dupTx == null &&
                  svc.autoConfirm &&
                  svc.categoryId != null) {
                final sugId = _uuid.v4();
                final now = _clock();
                await _db.into(_db.suggestedTransactions).insert(
                  SuggestedTransactionsCompanion.insert(
                    id: sugId,
                    type: TxType.expense,
                    amount: amount,
                    categoryId: Value(svc.categoryId),
                    merchant: Value(svc.merchant),
                    occurredAt: occurredUtc,
                    source: TxSource.capture,
                    status: 'pending',
                    rawText: Value(parsed.sanitizedRawText),
                    fingerprint: Value(fingerprint),
                    captureMeta: Value(captureMetaJson),
                    createdAt: now,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
                await _suggestionsRepo.confirm(
                  sugId,
                  occurredAt: occurredUtc,
                );
              } else {
                final created = await _suggestionsRepo.createIfAbsent(
                  type: TxType.expense,
                  amount: amount,
                  categoryId: svc.categoryId,
                  merchant: svc.merchant,
                  occurredAt: occurredUtc,
                  source: TxSource.capture,
                  sourceRef: dupTx != null ? 'dup:${dupTx.id}' : null,
                  rawText: parsed.sanitizedRawText,
                  fingerprint: fingerprint,
                  captureMeta: captureMetaJson,
                );
                if (created) pendingCreatedCount++;
              }
              break;
          }
          break;
      }
    }

    if (latestProcessedAt != null) {
      if (prevLastAt == null || latestProcessedAt.isAfter(prevLastAt)) {
        await _settingsRepo.set(
          SettingsKeys.captureEmailLastAt,
          latestProcessedAt.toIso8601String(),
        );
      }
    }

    if (notify && pendingCreatedCount >= 1) {
      final body = pendingCreatedCount == 1
          ? 'Tenés 1 movimiento por confirmar'
          : 'Tenés $pendingCreatedCount movimientos por confirmar';
      await _notifier.show('Pockt', body, payload: 'inbox');
    }

    return pendingCreatedCount;
  }

  Future<Transaction?> _findManualDuplicate({
    required TxType type,
    required int amount,
    required DateTime occurred,
    required bool hasTime,
  }) async {
    if (amount <= 0) return null;
    final occurredUtc = occurred.toUtc();
    final DateTime from;
    final DateTime to;

    if (hasTime) {
      from = occurredUtc.subtract(const Duration(hours: 2));
      to = occurredUtc.add(const Duration(hours: 2));
    } else {
      final local = occurred.toLocal();
      from = DateTime.utc(local.year, local.month, local.day);
      to = from.add(const Duration(days: 1));
    }

    final rows = await (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.type.equalsValue(type) &
                t.amount.equals(amount) &
                t.occurredAt.isBiggerOrEqualValue(from) &
                t.occurredAt.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }
}

final emailSourceProvider = Provider<EmailSource>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST') || !Platform.isAndroid) {
    return FakeEmailSource();
  }
  return const AndroidEmailSource();
});

final emailCaptureServiceProvider = Provider<EmailCaptureService>((ref) {
  return EmailCaptureService(
    db: ref.watch(databaseProvider),
    notifier: ref.watch(notifierProvider),
    source: ref.watch(emailSourceProvider),
    suggestionsRepository: ref.watch(suggestionsRepositoryProvider),
    transactionsRepository: ref.watch(transactionsRepositoryProvider),
    loansRepository: ref.watch(loansRepositoryProvider),
    counterpartyRulesRepository: ref.watch(counterpartyRulesRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

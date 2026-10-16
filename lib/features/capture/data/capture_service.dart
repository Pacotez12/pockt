import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/providers.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/notifications/notifier.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/capture/data/android_sms_source.dart';
import 'package:pockt/features/capture/domain/capture_classifier.dart';
import 'package:pockt/features/capture/domain/itau_sms_parser.dart';
import 'package:pockt/features/income/domain/pay_split.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';
import 'package:pockt/features/recurring/data/suggestions_repository.dart';
import 'package:pockt/features/transactions/data/keywords_repository.dart';
import 'package:uuid/uuid.dart';

class RawSms {
  const RawSms({
    required this.sender,
    required this.body,
    required this.receivedAt,
  });

  final String sender;
  final String body;
  final DateTime receivedAt;
}

abstract class SmsSource {
  Future<bool> hasPermissions();
  Future<bool> requestPermissions();
  Future<List<RawSms>> readInboxSince(DateTime since);
  Stream<RawSms> get incomingSms;
}

class FakeSmsSource implements SmsSource {
  FakeSmsSource({this.permissionsGranted = true, List<RawSms> inbox = const []})
    : _inbox = List.of(inbox);

  bool permissionsGranted;
  int requestPermissionCalls = 0;
  final List<RawSms> _inbox;
  final _incomingController = StreamController<RawSms>.broadcast();

  void setInbox(List<RawSms> messages) {
    _inbox
      ..clear()
      ..addAll(messages);
  }

  void emitIncoming(RawSms sms) {
    _incomingController.add(sms);
  }

  @override
  Future<bool> hasPermissions() async => permissionsGranted;

  @override
  Future<bool> requestPermissions() async {
    requestPermissionCalls++;
    return permissionsGranted;
  }

  @override
  Future<List<RawSms>> readInboxSince(DateTime since) async {
    return _inbox.where((m) => !m.receivedAt.isBefore(since)).toList();
  }

  @override
  Stream<RawSms> get incomingSms => _incomingController.stream;

  void dispose() {
    _incomingController.close();
  }
}

class CaptureService {
  CaptureService({
    required AppDatabase db,
    required Notifier notifier,
    required SmsSource smsSource,
    SuggestionsRepository? suggestionsRepository,
    SettingsRepository? settingsRepository,
    DateTime Function()? clock,
    Uuid? uuid,
  }) : _db = db,
       _notifier = notifier, // ignore: prefer_initializing_formals
       _smsSource = smsSource, // ignore: prefer_initializing_formals
       _suggestionsRepo =
           suggestionsRepository ?? SuggestionsRepository(db, clock: clock),
       _settingsRepo = settingsRepository ?? SettingsRepository(db),
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Notifier _notifier;
  final SmsSource _smsSource;
  final SuggestionsRepository _suggestionsRepo;
  final SettingsRepository _settingsRepo;
  final DateTime Function() _clock;
  final Uuid _uuid;

  Future<int>? _inFlightSync;

  static const _kPrestamosCatId = '018f0000-0000-7000-8000-000000000014';
  static const _kSueldoCatId = '018f0000-0000-7000-8000-000000000011';
  static const _kOtrosCatId = '018f0000-0000-7000-8000-000000000010';
  static const _kTarjetasCatId = '018f0000-0000-7000-8000-000000000015';

  /// Relee el buzón de SMS desde `max(capture.since, capture.lastSmsAt)` solo si
  /// `capture.smsEnabled` está activo y hay permisos concedidos.
  Future<int> syncInbox({bool notify = true}) {
    final current = _inFlightSync;
    if (current != null) return current;
    final future = _syncInboxOnce(notify: notify).whenComplete(() {
      _inFlightSync = null;
    });
    _inFlightSync = future;
    return future;
  }

  Future<int> _syncInboxOnce({required bool notify}) async {
    final enabledStr = await _settingsRepo.get(SettingsKeys.captureSmsEnabled);
    if (enabledStr != 'true') return 0;

    final permitted = await _smsSource.hasPermissions();
    if (!permitted) return 0;

    final sinceDate = await _readSinceDate();
    final lastSmsAtStr = await _settingsRepo.get(SettingsKeys.captureLastSmsAt);
    final lastSmsAt = lastSmsAtStr != null
        ? DateTime.tryParse(lastSmsAtStr)
        : null;

    final queryFrom = (lastSmsAt != null && lastSmsAt.isAfter(sinceDate))
        ? lastSmsAt
        : sinceDate;

    final rawMessages = await _smsSource.readInboxSince(queryFrom);
    if (rawMessages.isEmpty) return 0;
    return ingest(rawMessages, notify: notify);
  }

  Future<DateTime> _readSinceDate() async {
    final raw = await _settingsRepo.get(SettingsKeys.captureSince);
    final parsed = raw != null ? DateTime.tryParse(raw) : null;
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return DateTime(2026, 10, 15);
  }

  /// Procesa una lista de SMS del remitente 4828: parsea, clasifica, deduplica,
  /// crea sugerencias o auto-confirma, actualiza `capture.lastSmsAt` y notifica.
  Future<int> ingest(List<RawSms> messages, {bool notify = true}) async {
    if (messages.isEmpty) return 0;

    final sinceDate = await _readSinceDate();
    final filtered =
        messages
            .where(
              (m) =>
                  m.sender.trim() == '4828' || m.sender.trim().endsWith('4828'),
            )
            .toList()
          ..sort((a, b) => a.receivedAt.compareTo(b.receivedAt));

    if (filtered.isEmpty) return 0;

    var pendingCreatedCount = 0;
    DateTime? latestProcessedAt;
    final prevLastStr = await _settingsRepo.get(SettingsKeys.captureLastSmsAt);
    final prevLastAt = prevLastStr != null
        ? DateTime.tryParse(prevLastStr)
        : null;

    for (final sms in filtered) {
      final parsed = parseItauSms(sms.body);
      final effectiveTime = parsed.occurredAt ?? sms.receivedAt;

      if (effectiveTime.isBefore(sinceDate)) {
        continue;
      }

      if (latestProcessedAt == null ||
          sms.receivedAt.isAfter(latestProcessedAt)) {
        latestProcessedAt = sms.receivedAt;
      }

      if (parsed.kind == CaptureKind.ignored) {
        continue;
      }

      if (parsed.kind == CaptureKind.unrecognized) {
        if (prevLastAt == null || sms.receivedAt.isAfter(prevLastAt)) {
          final curStr = await _settingsRepo.get(
            SettingsKeys.captureUnrecognizedCount,
          );
          final cur = int.tryParse(curStr ?? '') ?? 0;
          await _settingsRepo.set(
            SettingsKeys.captureUnrecognizedCount,
            (cur + 1).toString(),
          );
        }
        continue;
      }

      final fingerprint = parsed.fingerprint;
      if (fingerprint == null) continue;

      // 1. Deduplicación por fingerprint
      final existingByFp =
          await (_db.select(_db.suggestedTransactions)
                ..where((s) => s.fingerprint.equals(fingerprint))
                ..limit(1))
              .getSingleOrNull();
      if (existingByFp != null) {
        continue;
      }

      // 2. Cargar contexto para clasificar
      final keywordMap = await KeywordsRepository(_db).keywordMap();
      final memRows = await _db.select(_db.merchantMemory).get();
      final autoConfirmSet = <String>{
        for (final m in memRows)
          if (m.autoConfirm) m.merchantKey.trim().toLowerCase(),
      };

      final activeRules =
          await (_db.select(_db.recurringRules)..where(
                (r) =>
                    r.active.equals(true) & r.type.equalsValue(TxType.expense),
              ))
              .get();
      final pendingRecSugs =
          await (_db.select(_db.suggestedTransactions)..where(
                (s) =>
                    s.status.equals('pending') &
                    s.source.equalsValue(TxSource.recurring),
              ))
              .get();
      final pendingByRule = <String, SuggestedTransaction>{
        for (final s in pendingRecSugs)
          if (s.sourceRef != null) s.sourceRef!: s,
      };
      final recurringCandidates = activeRules.map((r) {
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

      final activeLoansRows =
          await (_db.select(_db.loans)..where(
                (l) =>
                    l.closedAt.isNull() &
                    l.direction.equalsValue(LoanDirection.owe),
              ))
              .get();
      final loanCandidates = activeLoansRows
          .where((l) => (l.installmentAmount ?? 0) > 0)
          .map(
            (l) => CaptureLoanCandidate(
              id: l.id,
              name: l.name,
              installmentAmount: l.installmentAmount!,
            ),
          )
          .toList();

      final pendingSalaryRows =
          await (_db.select(_db.suggestedTransactions)..where(
                (s) =>
                    s.status.equals('pending') &
                    s.source.equalsValue(TxSource.incomeSchedule),
              ))
              .get();
      final salaryCandidates = pendingSalaryRows
          .map(
            (s) => CaptureSalarySuggestionCandidate(
              id: s.id,
              amount: s.amount,
              occurredAt: s.occurredAt,
              categoryId: s.categoryId,
            ),
          )
          .toList();

      final currentSchedule =
          await (_db.select(_db.incomeSchedules)
                ..orderBy([(t) => OrderingTerm.desc(t.effectiveFrom)])
                ..limit(1))
              .getSingleOrNull();
      int? expectedSalaryAmount;
      String salaryCatId = currentSchedule?.categoryId ?? _kSueldoCatId;
      if (currentSchedule?.monthlyAmount != null) {
        final payDaysList = (jsonDecode(currentSchedule!.payDays) as List)
            .map((e) => (e as num).toInt())
            .toList();
        final splits = parsePaySplitPercents(
          currentSchedule.paySplitPercents,
          count: payDaysList.length,
        );
        final deductions = await (_db.select(
          _db.salaryDeductions,
        )..where((d) => d.scheduleId.equals(currentSchedule.id))).get();
        final amounts = safeNetPayAmounts(
          currentSchedule.monthlyAmount!,
          splits,
          deductions,
        );
        if (amounts.isNotEmpty) {
          expectedSalaryAmount = amounts.first;
        }
      }

      final classification = classifyCapture(
        parsed,
        merchantMemory: keywordMap,
        autoConfirmMerchants: autoConfirmSet,
        recurringRules: recurringCandidates,
        activeLoans: loanCandidates,
        pendingSalarySuggestions: salaryCandidates,
        expectedSalaryAmount: expectedSalaryAmount,
        salaryCategoryId: salaryCatId,
        loansCategoryId: _kPrestamosCatId,
        cardsCategoryId: _kTarjetasCatId,
      );

      switch (classification.kind) {
        case CaptureClassificationKind.ignored:
        case CaptureClassificationKind.unrecognized:
          break;

        case CaptureClassificationKind.confirmSalarySuggestion:
          final sugId = classification.confirmSuggestionId!;
          final occurredUtc = classification.occurredAt!.toUtc();
          await (_db.update(
            _db.suggestedTransactions,
          )..where((s) => s.id.equals(sugId))).write(
            SuggestedTransactionsCompanion(
              fingerprint: Value(fingerprint),
              rawText: Value(parsed.sanitizedRawText),
              occurredAt: Value(occurredUtc),
            ),
          );
          await _suggestionsRepo.confirm(sugId, occurredAt: occurredUtc);
          break;

        case CaptureClassificationKind.salaryIncomeSuggestion:
          final occurredUtc = classification.occurredAt!.toUtc();
          final dupTx = await _findManualDuplicate(
            type: TxType.income,
            amount: classification.amount ?? 0,
            occurredUtc: occurredUtc,
          );
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.income,
            amount: classification.amount ?? 0,
            categoryId: classification.categoryId,
            merchant: classification.merchant ?? 'Cobro',
            occurredAt: occurredUtc,
            source: TxSource.capture,
            sourceRef: dupTx != null ? 'dup:${dupTx.id}' : null,
            rawText: parsed.sanitizedRawText,
            fingerprint: fingerprint,
          );
          if (created) pendingCreatedCount++;
          break;

        case CaptureClassificationKind.cardPaymentTransfer:
          final occurredUtc = classification.occurredAt!.toUtc();
          final dupTx = await _findManualDuplicate(
            type: TxType.transfer,
            amount: classification.amount!,
            occurredUtc: occurredUtc,
          );
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.transfer,
            amount: classification.amount!,
            categoryId: _kOtrosCatId,
            merchant: classification.merchant,
            occurredAt: occurredUtc,
            source: TxSource.capture,
            sourceRef: dupTx != null ? 'dup:${dupTx.id}' : null,
            rawText: parsed.sanitizedRawText,
            fingerprint: fingerprint,
          );
          if (created) pendingCreatedCount++;
          break;

        case CaptureClassificationKind.recurringServicePayment:
          final occurredUtc = classification.occurredAt!.toUtc();
          if (classification.replacesSuggestionId != null) {
            await (_db.delete(_db.suggestedTransactions)..where(
                  (s) => s.id.equals(classification.replacesSuggestionId!),
                ))
                .go();
          }
          final dupTx = await _findManualDuplicate(
            type: TxType.expense,
            amount: classification.amount!,
            occurredUtc: occurredUtc,
          );
          final sourceRef = dupTx != null
              ? 'dup:${dupTx.id}'
              : (classification.recurringRuleId != null
                    ? 'rule:${classification.recurringRuleId}'
                    : null);
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.expense,
            amount: classification.amount!,
            categoryId: classification.categoryId,
            merchant: classification.merchant,
            occurredAt: occurredUtc,
            source: TxSource.capture,
            sourceRef: sourceRef,
            rawText: parsed.sanitizedRawText,
            fingerprint: fingerprint,
          );
          if (created) pendingCreatedCount++;
          break;

        case CaptureClassificationKind.loanPayment:
          final occurredUtc = classification.occurredAt!.toUtc();
          final dupTx = await _findManualDuplicate(
            type: TxType.expense,
            amount: classification.amount!,
            occurredUtc: occurredUtc,
          );
          final sourceRef = dupTx != null
              ? 'dup:${dupTx.id}'
              : (classification.loanId != null
                    ? 'loan:${classification.loanId}'
                    : null);
          final created = await _suggestionsRepo.createIfAbsent(
            type: TxType.expense,
            amount: classification.amount!,
            categoryId: classification.categoryId,
            merchant: classification.merchant,
            occurredAt: occurredUtc,
            source: TxSource.capture,
            sourceRef: sourceRef,
            rawText: parsed.sanitizedRawText,
            fingerprint: fingerprint,
          );
          if (created) pendingCreatedCount++;
          break;

        case CaptureClassificationKind.expense:
          final occurredUtc = classification.occurredAt!.toUtc();
          final dupTx = await _findManualDuplicate(
            type: TxType.expense,
            amount: classification.amount!,
            occurredUtc: occurredUtc,
          );

          if (dupTx == null &&
              classification.autoConfirm &&
              classification.categoryId != null) {
            final sugId = _uuid.v4();
            final now = _clock();
            await _db
                .into(_db.suggestedTransactions)
                .insert(
                  SuggestedTransactionsCompanion.insert(
                    id: sugId,
                    type: TxType.expense,
                    amount: classification.amount!,
                    categoryId: Value(classification.categoryId),
                    merchant: Value(classification.merchant),
                    occurredAt: occurredUtc,
                    source: TxSource.capture,
                    status: 'pending',
                    rawText: Value(parsed.sanitizedRawText),
                    fingerprint: Value(fingerprint),
                    createdAt: now,
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            await _suggestionsRepo.confirm(sugId, occurredAt: occurredUtc);
          } else {
            final created = await _suggestionsRepo.createIfAbsent(
              type: TxType.expense,
              amount: classification.amount!,
              categoryId: classification.categoryId,
              merchant: classification.merchant,
              occurredAt: occurredUtc,
              source: TxSource.capture,
              sourceRef: dupTx != null ? 'dup:${dupTx.id}' : null,
              rawText: parsed.sanitizedRawText,
              fingerprint: fingerprint,
            );
            if (created) pendingCreatedCount++;
          }
          break;
      }
    }

    if (latestProcessedAt != null) {
      if (prevLastAt == null || latestProcessedAt.isAfter(prevLastAt)) {
        await _settingsRepo.set(
          SettingsKeys.captureLastSmsAt,
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

  /// Busca un movimiento existente no borrado con el mismo [type] y [amount]
  /// exacto entre 2 horas antes y 2 horas después de [occurredUtc] (§4.4).
  Future<Transaction?> _findManualDuplicate({
    required TxType type,
    required int amount,
    required DateTime occurredUtc,
  }) async {
    if (amount <= 0) return null;
    final from = occurredUtc.subtract(const Duration(hours: 2));
    final to = occurredUtc.add(const Duration(hours: 2));
    final rows =
        await (_db.select(_db.transactions)
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

final smsSourceProvider = Provider<SmsSource>((ref) {
  if (Platform.environment.containsKey('FLUTTER_TEST') || !Platform.isAndroid) {
    return FakeSmsSource();
  }
  return AndroidSmsSource();
});

final captureServiceProvider = Provider<CaptureService>((ref) {
  return CaptureService(
    db: ref.watch(databaseProvider),
    notifier: ref.watch(notifierProvider),
    smsSource: ref.watch(smsSourceProvider),
    suggestionsRepository: ref.watch(suggestionsRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

/// Cantidad de capturas (sugerencias con `source = capture`) creadas en el mes actual.
final capturedThisMonthCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final nextMonth = DateTime(now.year, now.month + 1, 1);
  final countCol = db.suggestedTransactions.id.count();
  final query = db.selectOnly(db.suggestedTransactions)
    ..addColumns([countCol])
    ..where(
      db.suggestedTransactions.source.equalsValue(TxSource.capture) &
          db.suggestedTransactions.occurredAt.isBiggerOrEqualValue(monthStart) &
          db.suggestedTransactions.occurredAt.isSmallerThanValue(nextMonth),
    );
  return query.watchSingle().map((r) => r.read(countCol) ?? 0);
});

class AutoConfirmMerchantView {
  const AutoConfirmMerchantView({
    required this.merchantKey,
    required this.category,
  });

  final String merchantKey;
  final Category category;
}

/// Lista de comercios con confirmación automática activada (§4.6).
final autoConfirmMerchantsProvider =
    StreamProvider<List<AutoConfirmMerchantView>>((ref) {
      final db = ref.watch(databaseProvider);
      final query =
          db.select(db.merchantMemory).join([
              innerJoin(
                db.categories,
                db.categories.id.equalsExp(db.merchantMemory.categoryId),
              ),
            ])
            ..where(db.merchantMemory.autoConfirm.equals(true))
            ..orderBy([OrderingTerm.asc(db.merchantMemory.merchantKey)]);

      return query.watch().map((rows) {
        return rows.map((row) {
          final mem = row.readTable(db.merchantMemory);
          final cat = row.readTable(db.categories);
          return AutoConfirmMerchantView(
            merchantKey: mem.merchantKey,
            category: cat,
          );
        }).toList();
      });
    });

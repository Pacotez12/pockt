enum CaptureKind { debit, salaryCredit, ignored, unrecognized }

class CaptureResult {
  const CaptureResult({
    required this.kind,
    required this.sanitizedRawText,
    this.amount,
    this.description,
    this.merchantKey,
    this.occurredAt,
  });

  final CaptureKind kind;
  final int? amount;
  final String? description;
  final String? merchantKey;
  final DateTime? occurredAt;
  final String sanitizedRawText;

  String? get fingerprint {
    final ts = occurredAt;
    if (ts == null) return null;
    return 'sms:${ts.toIso8601String()}:${amount ?? 0}';
  }
}

final RegExp _debitPrefixRegex = RegExp(
  r'^\s*Ita[uú]\s+informa:\s*Registramos\s+un\s+d[eé]bito',
  caseSensitive: false,
);

final RegExp _debitRegex = RegExp(
  r'^\s*Ita[uú]\s+informa:\s*Registramos\s+un\s+d[eé]bito\s+en\s+tu\s+Cuenta\s+\S+\s+de\s+Gs\.?\s*[*]*([0-9.]+)\s+por\s+(.+?)\s+al\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})\s*$',
  caseSensitive: false,
);

final RegExp _salaryRegex = RegExp(
  r'^\s*Ita[uú]\s+le\s+informa:\s*Su\s+empresa\s+realiz[oó]\s+una\s+acreditaci[oó]n\s+en\s+su\s+cuenta\s+\S+\s+en\s+Gs\.\s+al\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})',
  caseSensitive: false,
);

final RegExp _trailingNumericRefRegex = RegExp(
  r'\s+(?:[A-Z]{1,4})?\d{8,}\s*$',
  caseSensitive: false,
);

final RegExp _vposSuffixRegex = RegExp(
  r'(?:\s*-\s*vpos)+\s*$',
  caseSensitive: false,
);

final RegExp _accountNumberMaskRegex = RegExp(
  r'\b(cuenta)\s+\S+',
  caseSensitive: false,
);

String sanitizeSmsRawText(String raw) {
  return raw.replaceAllMapped(_accountNumberMaskRegex, (match) {
    final word = match.group(1) ?? 'Cuenta';
    return '$word ****';
  });
}

String cleanSmsDescription(String rawDescription) {
  final withoutRef = rawDescription.replaceFirst(_trailingNumericRefRegex, '');
  return withoutRef.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String extractMerchantKey(String cleanedDescription) {
  return cleanedDescription
      .replaceFirst(_vposSuffixRegex, '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
}

DateTime? _parseSmsDateTime(String raw) {
  final parts = raw.trim().split(RegExp(r'\s+'));
  if (parts.length != 2) return null;
  final dateParts = parts[0].split('/');
  final timeParts = parts[1].split(':');
  if (dateParts.length != 3 || timeParts.length != 3) return null;

  final day = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final year = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  final second = int.tryParse(timeParts[2]);

  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null ||
      second == null) {
    return null;
  }
  return DateTime(year, month, day, hour, minute, second);
}

CaptureResult parseItauSms(String body) {
  final sanitized = sanitizeSmsRawText(body.trim());

  final debitMatch = _debitRegex.firstMatch(body.trim());
  if (debitMatch != null) {
    final amountStr = debitMatch.group(1)!.replaceAll('.', '');
    final amount = int.tryParse(amountStr);
    final rawDesc = debitMatch.group(2)!;
    final dateStr = debitMatch.group(3)!;
    final occurredAt = _parseSmsDateTime(dateStr);

    if (amount != null && occurredAt != null) {
      final description = cleanSmsDescription(rawDesc);
      final merchantKey = extractMerchantKey(description);
      return CaptureResult(
        kind: CaptureKind.debit,
        amount: amount,
        description: description,
        merchantKey: merchantKey,
        occurredAt: occurredAt,
        sanitizedRawText: sanitized,
      );
    }
  }

  if (_debitPrefixRegex.hasMatch(body)) {
    return CaptureResult(
      kind: CaptureKind.unrecognized,
      sanitizedRawText: sanitized,
    );
  }

  final salaryMatch = _salaryRegex.firstMatch(body.trim());
  if (salaryMatch != null) {
    final occurredAt = _parseSmsDateTime(salaryMatch.group(1)!);
    if (occurredAt != null) {
      return CaptureResult(
        kind: CaptureKind.salaryCredit,
        occurredAt: occurredAt,
        sanitizedRawText: sanitized,
      );
    }
  }

  return CaptureResult(kind: CaptureKind.ignored, sanitizedRawText: sanitized);
}

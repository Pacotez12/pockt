import 'package:pockt/core/format/money.dart';

class ParsedInstallment {
  final int number;
  final DateTime dueDate;
  final int amount;

  const ParsedInstallment({
    required this.number,
    required this.dueDate,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedInstallment &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          dueDate.year == other.dueDate.year &&
          dueDate.month == other.dueDate.month &&
          dueDate.day == other.dueDate.day &&
          amount == other.amount;

  @override
  int get hashCode => Object.hash(number, dueDate.year, dueDate.month, dueDate.day, amount);
}

class InstallmentScheduleParseResult {
  final List<ParsedInstallment> installments;
  final Map<int, String> lineErrors; // 1-based line number -> error message

  const InstallmentScheduleParseResult({
    required this.installments,
    required this.lineErrors,
  });

  bool get isValid => lineErrors.isEmpty && installments.isNotEmpty;
  int get totalAmount => installments.fold<int>(0, (sum, i) => sum + i.amount);
}

InstallmentScheduleParseResult parseInstallmentSchedule(String text) {
  final lines = text.split('\n');
  final installments = <ParsedInstallment>[];
  final lineErrors = <int, String>{};

  int expectedNumber = 1;

  for (int i = 0; i < lines.length; i++) {
    final lineNumber = i + 1;
    final rawLine = lines[i].trim();
    if (rawLine.isEmpty) continue;

    // Normalizar prefijo de moneda: 'Gs.', 'Gs', 'gs.', 'gs', '$'
    final lineWithoutCurrency = rawLine.replaceAll(
      RegExp(r'(?:gs\.?|\$)\s*', caseSensitive: false),
      '',
    );

    // Dividir por espacios
    final parts = lineWithoutCurrency.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) {
      lineErrors[lineNumber] =
          'Formato no válido. Usá: número fecha monto (ej: 1 02/01/2027 905.000)';
      continue;
    }

    final number = int.tryParse(parts[0]);
    if (number == null || number <= 0) {
      lineErrors[lineNumber] = 'Número de cuota no válido: "${parts[0]}"';
      continue;
    }

    final dueDate = _parseDate(parts[1]);
    if (dueDate == null) {
      lineErrors[lineNumber] = 'Fecha no válida: "${parts[1]}" (usá dd/mm/aaaa)';
      continue;
    }

    final amountStr = parts[2].replaceAll('.', '').replaceAll(',', '').replaceAll(' ', '');
    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      lineErrors[lineNumber] = 'Monto no válido: "${parts[2]}"';
      continue;
    }

    if (number != expectedNumber) {
      if (expectedNumber == 1) {
        lineErrors[lineNumber] = 'La primera cuota debe ser 1 (se encontró $number)';
      } else {
        lineErrors[lineNumber] =
            'Se esperaba cuota $expectedNumber pero se encontró $number';
      }
      expectedNumber = number + 1;
    } else {
      expectedNumber++;
    }

    installments.add(ParsedInstallment(
      number: number,
      dueDate: dueDate,
      amount: amount,
    ));
  }

  return InstallmentScheduleParseResult(
    installments: installments,
    lineErrors: lineErrors,
  );
}

DateTime? _parseDate(String str) {
  // dd/MM/yyyy o dd-MM-yyyy
  final dmyMatch = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(str);
  if (dmyMatch != null) {
    final day = int.parse(dmyMatch.group(1)!);
    final month = int.parse(dmyMatch.group(2)!);
    final year = int.parse(dmyMatch.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  // yyyy-MM-dd o yyyy/MM/dd
  final ymdMatch = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(str);
  if (ymdMatch != null) {
    final year = int.parse(ymdMatch.group(1)!);
    final month = int.parse(ymdMatch.group(2)!);
    final day = int.parse(ymdMatch.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  return null;
}

String formatInstallmentSchedule(List<ParsedInstallment> installments) {
  final buffer = StringBuffer();
  for (final inst in installments) {
    final d = inst.dueDate.day.toString().padLeft(2, '0');
    final m = inst.dueDate.month.toString().padLeft(2, '0');
    final y = inst.dueDate.year.toString();
    final amountFormatted = formatGs(inst.amount, symbol: false);
    buffer.writeln('${inst.number} $d/$m/$y $amountFormatted');
  }
  return buffer.toString().trimRight();
}

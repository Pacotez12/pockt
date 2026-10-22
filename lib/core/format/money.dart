import 'dart:math';

import 'package:flutter/services.dart';

const int kMaxAmountDigits = 12;

String formatGs(int amount, {bool symbol = true}) {
  final prefix = amount < 0 ? '−' : '';
  final formatted = _formatThousands(amount.abs());
  if (symbol) {
    return '${prefix}Gs. $formatted';
  }
  return '$prefix$formatted';
}

String keypadAppend(String digits, String key) {
  final current = digits.replaceFirst(RegExp(r'^0+'), '');

  if (key == '⌫') {
    if (current.isEmpty) return '';
    return current.substring(0, current.length - 1);
  }

  if (current.isEmpty) {
    if (key == '0' || key == '000' || key == '00') {
      return '';
    }
    if (key.length == 1 && key.compareTo('1') >= 0 && key.compareTo('9') <= 0) {
      return key;
    }
    return '';
  }

  final available = kMaxAmountDigits - current.length;
  if (available <= 0) {
    return current;
  }

  if (key == '000') {
    final count = min(3, available);
    return current + ('0' * count);
  }

  if (key == '00') {
    final count = min(2, available);
    return current + ('0' * count);
  }

  if (key.length == 1 && key.compareTo('0') >= 0 && key.compareTo('9') <= 0) {
    return current + key;
  }

  return current;
}

int keypadValue(String digits) {
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

String _formatThousands(int value) {
  final str = value.toString();
  final buffer = StringBuffer();
  final len = str.length;
  for (int i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return buffer.toString();
}

/// Muestra el monto con puntos de miles mientras se escribe (10.000.000).
/// Quien lea el campo debe quitar los puntos antes de convertir a número.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final text = formatGs(int.parse(digits), symbol: false);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

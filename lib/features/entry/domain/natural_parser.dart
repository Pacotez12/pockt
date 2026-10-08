import 'dart:math';
import 'package:pockt/core/db/app_database.dart';

/// Resultado del parseo de una entrada en lenguaje natural.
class ParsedEntry {
  final int amount;
  final String? categoryId;
  final DateTime occurredLocalDay;
  final String? merchant;

  const ParsedEntry({
    required this.amount,
    this.categoryId,
    required this.occurredLocalDay,
    this.merchant,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedEntry &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          categoryId == other.categoryId &&
          occurredLocalDay == other.occurredLocalDay &&
          merchant == other.merchant;

  @override
  int get hashCode => Object.hash(amount, categoryId, occurredLocalDay, merchant);

  @override
  String toString() =>
      'ParsedEntry(amount: $amount, categoryId: $categoryId, occurredLocalDay: $occurredLocalDay, merchant: $merchant)';
}

/// Normaliza texto para búsqueda: minúsculas, sin espacios en extremos y sin tildes.
String normalizeKeyword(String text) {
  var s = text.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'[áàäâ]'), 'a');
  s = s.replaceAll(RegExp(r'[éèëê]'), 'e');
  s = s.replaceAll(RegExp(r'[íìïî]'), 'i');
  s = s.replaceAll(RegExp(r'[óòöô]'), 'o');
  s = s.replaceAll(RegExp(r'[úùüû]'), 'u');
  return s;
}

String _normalize(String text) => normalizeKeyword(text);

/// Distancia de Damerau-Levenshtein (inserción, borrado, sustitución y transposición).
int damerauLevenshtein(String a, String b) {
  final la = a.length;
  final lb = b.length;
  if (la == 0) return lb;
  if (lb == 0) return la;

  final d = List.generate(la + 1, (_) => List<int>.filled(lb + 1, 0));

  for (var i = 0; i <= la; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= lb; j++) {
    d[0][j] = j;
  }

  for (var i = 1; i <= la; i++) {
    for (var j = 1; j <= lb; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      d[i][j] = min(
        min(d[i - 1][j] + 1, d[i][j - 1] + 1),
        d[i - 1][j - 1] + cost,
      );
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1);
      }
    }
  }

  return d[la][lb];
}

/// Diccionario curado inicial de palabras clave por categoría del seed.
const Map<String, List<String>> kSeedCategoryKeywords = {
  'Comida': [
    'café',
    'cafe',
    'almuerzo',
    'cena',
    'delivery',
    'pedidosya',
    'desayuno',
    'merienda',
    'restaurante',
    'bar',
    'comida',
    'empanada',
    'pizza',
    'hamburguesa',
  ],
  'Transporte': [
    'bolt',
    'uber',
    'nafta',
    'combustible',
    'peaje',
    'estacionamiento',
    'colectivo',
    'bus',
    'pasaje',
    'taxi',
  ],
  'Hogar': [
    'super',
    'superseis',
    'stock',
    'biggie',
    'ferretería',
    'ferreteria',
    'alquiler',
    'expensas',
    'muebles',
    'limpieza',
  ],
  'Salud': [
    'farmacia',
    'médico',
    'medico',
    'dentista',
    'remedio',
    'consulta',
    'análisis',
    'analisis',
    'óptica',
    'optica',
  ],
  'Ocio': [
    'cine',
    'salida',
    'juegos',
    'concierto',
    'viaje',
    'hotel',
    'fiesta',
    'teatro',
    'steam',
    'boliche',
  ],
  'Servicios': [
    'ande',
    'essap',
    'tigo',
    'personal',
    'claro',
    'netflix',
    'spotify',
    'internet',
    'luz',
    'agua',
    'teléfono',
    'telefono',
  ],
  'Educación': [
    'facultad',
    'colegio',
    'universidad',
    'curso',
    'libros',
    'cuota',
  ],
  'Regalos': [
    'regalo',
    'regalos',
    'cumpleaños',
    'cumpleanos',
    'aniversario',
  ],
  'Ropa': [
    'ropa',
    'zapatos',
    'championes',
    'tienda',
    'zapatillas',
    'remera',
    'pantalon',
  ],
  'Otros': [
    'varios',
    'otros',
  ],
  'Sueldo': [
    'sueldo',
    'salario',
    'pago',
  ],
  'Extra': [
    'extra',
    'honorarios',
    'freelance',
    'bonus',
  ],
  'Otros ingresos': [
    'transferencia',
    'devolución',
    'devolucion',
  ],
};

/// Construye un mapa keyword -> categoryId a partir de las categorías dadas.
Map<String, String> buildKeywordToCategoryIdMap(List<Category> categories) {
  final map = <String, String>{};
  for (final cat in categories) {
    map[cat.name] = cat.id;
    final keywords = kSeedCategoryKeywords[cat.name];
    if (keywords != null) {
      for (final kw in keywords) {
        map[kw] = cat.id;
      }
    }
  }
  return map;
}

DateTime _targetWeekdayDate(DateTime nowLocal, int targetWeekday) {
  var diff = (nowLocal.weekday - targetWeekday) % 7;
  if (diff < 0) diff += 7;
  return DateTime(nowLocal.year, nowLocal.month, nowLocal.day - diff);
}

/// Parsea una entrada de texto natural (monto, categoría, fecha y comercio).
/// Retorna `null` si no se encuentra un monto.
ParsedEntry? parseNaturalEntry(
  String input, {
  required DateTime nowLocal,
  required Map<String, String> keywordToCategoryId,
}) {
  final trimmedInput = input.trim();
  if (trimmedInput.isEmpty) return null;

  // 1. Detectar el monto
  final amountRegex = RegExp(
    r'(?:gs\.?\s*)?(\d{1,3}(?:\.\d{3})+|\d+)(?:[.,](\d+))?\s*(mil(?:es)?|k)?\b',
    caseSensitive: false,
  );

  final amountMatch = amountRegex.firstMatch(trimmedInput);
  if (amountMatch == null) return null;

  final numStr = amountMatch.group(1)!;
  final decStr = amountMatch.group(2);
  final multStr = amountMatch.group(3)?.toLowerCase();

  int amount = 0;
  if (multStr != null) {
    double base = double.tryParse(numStr.replaceAll('.', '')) ?? 0;
    if (decStr != null) {
      base = base + (double.tryParse('0.$decStr') ?? 0);
    }
    amount = (base * 1000).round();
  } else {
    final cleanNum = numStr.replaceAll('.', '');
    amount = int.tryParse(cleanNum) ?? 0;
  }

  if (amount <= 0) return null;

  // 2. Detectar fecha relativa o día de la semana
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  DateTime occurredLocalDay = today;

  final norm = _normalize(trimmedInput);

  int? dateMatchStart;
  int? dateMatchEnd;

  final anteayerRegex = RegExp(r'\banteayer\b');
  final ayerRegex = RegExp(r'\bayer\b');
  final hoyRegex = RegExp(r'\bhoy\b');
  final weekdayRegex = RegExp(
    r'\b(?:el\s+)?(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b',
  );

  final anteayerMatch = anteayerRegex.firstMatch(norm);
  if (anteayerMatch != null) {
    occurredLocalDay = today.subtract(const Duration(days: 2));
    dateMatchStart = anteayerMatch.start;
    dateMatchEnd = anteayerMatch.end;
  } else {
    final ayerMatch = ayerRegex.firstMatch(norm);
    if (ayerMatch != null) {
      occurredLocalDay = today.subtract(const Duration(days: 1));
      dateMatchStart = ayerMatch.start;
      dateMatchEnd = ayerMatch.end;
    } else {
      final weekdayMatch = weekdayRegex.firstMatch(norm);
      if (weekdayMatch != null) {
        final dayName = weekdayMatch.group(1)!;
        const weekdayMap = {
          'lunes': DateTime.monday,
          'martes': DateTime.tuesday,
          'miercoles': DateTime.wednesday,
          'jueves': DateTime.thursday,
          'viernes': DateTime.friday,
          'sabado': DateTime.saturday,
          'domingo': DateTime.sunday,
        };
        final targetW = weekdayMap[dayName]!;
        occurredLocalDay = _targetWeekdayDate(nowLocal, targetW);
        dateMatchStart = weekdayMatch.start;
        dateMatchEnd = weekdayMatch.end;
      } else {
        final hoyMatch = hoyRegex.firstMatch(norm);
        if (hoyMatch != null) {
          occurredLocalDay = today;
          dateMatchStart = hoyMatch.start;
          dateMatchEnd = hoyMatch.end;
        }
      }
    }
  }

  // 3. Extraer el merchant (texto restante sin monto ni fecha, con capitalización original)
  final runes = trimmedInput.runes.toList();
  final mask = List<bool>.filled(runes.length, true);

  for (var i = amountMatch.start; i < amountMatch.end && i < mask.length; i++) {
    mask[i] = false;
  }

  if (dateMatchStart != null && dateMatchEnd != null) {
    for (var i = dateMatchStart; i < dateMatchEnd && i < mask.length; i++) {
      mask[i] = false;
    }
  }

  final remainingBuffer = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    if (mask[i]) {
      remainingBuffer.writeCharCode(runes[i]);
    }
  }

  var remaining = remainingBuffer.toString().trim();
  remaining = remaining.replaceAll(RegExp(r'^[,\-\s]+|[,\-\s]+$'), '').trim();
  final merchant = remaining.isEmpty ? null : remaining;

  // 4. Detectar categoría mediante palabras clave
  String? categoryId;

  // 4a. Coincidencia EXACTA primero
  final sortedKeywords = keywordToCategoryId.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  for (final kw in sortedKeywords) {
    final normKw = _normalize(kw);
    final pattern = RegExp(r'\b' + RegExp.escape(normKw) + r'\b');
    if (pattern.hasMatch(norm)) {
      categoryId = keywordToCategoryId[kw];
      break;
    }
  }

  // 4b. Coincidencia DIFUSA si no hubo exacta: tolerancia con Damerau-Levenshtein
  // Tolerancia: distancia <= 1 para 4..6 letras, <= 2 para 7+, menos de 4 solo exacta.
  // Ante empate gana la de mayor prioridad del mapa (orden de iteración en keywordToCategoryId).
  if (categoryId == null && remaining.isNotEmpty) {
    final words = RegExp(r'[a-zA-Z0-9áéíóúÁÉÍÓÚñÑ]+')
        .allMatches(remaining)
        .map((m) => _normalize(m.group(0)!))
        .where((w) => w.length >= 4)
        .toList();

    int bestDistance = 999;
    String? bestCategory;

    for (final entry in keywordToCategoryId.entries) {
      final kw = _normalize(entry.key);
      if (kw.length < 4) continue;

      for (final w in words) {
        final maxDist = (w.length <= 6 && kw.length <= 6) ? 1 : 2;
        if ((w.length - kw.length).abs() > maxDist) continue;

        final dist = damerauLevenshtein(w, kw);
        if (dist <= maxDist) {
          if (dist < bestDistance) {
            bestDistance = dist;
            bestCategory = entry.value;
          }
        }
      }
    }

    if (bestCategory != null) {
      categoryId = bestCategory;
    }
  }

  return ParsedEntry(
    amount: amount,
    categoryId: categoryId,
    occurredLocalDay: occurredLocalDay,
    merchant: merchant,
  );
}

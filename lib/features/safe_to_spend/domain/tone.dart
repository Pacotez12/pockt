import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/settings/settings_repository.dart';

/// Nivel de tono para los avisos y el simulador ¿Lo compro? (spec §7d).
enum ToneLevel {
  soft('soft', 'Suave'),
  normal('normal', 'Normal'),
  spicy('spicy', 'Picante');

  final String key;
  final String label;

  const ToneLevel(this.key, this.label);
}

/// Parsea una cadena de texto al nivel de tono correspondiente (por defecto [ToneLevel.normal]).
ToneLevel parseToneLevel(String? val) {
  if (val == null) return ToneLevel.normal;
  switch (val.toLowerCase().trim()) {
    case 'soft':
      return ToneLevel.soft;
    case 'spicy':
      return ToneLevel.spicy;
    case 'normal':
    default:
      return ToneLevel.normal;
  }
}

/// Provider reactivo que vigila el ajuste `tone.level` en settings.
final toneLevelProvider = StreamProvider<ToneLevel>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watch(SettingsKeys.toneLevel).map(parseToneLevel);
});

/// Situación financiera evaluada por el simulador ¿Lo compro? (spec §7d).
enum BuySituation {
  /// El gasto cabe en lo que se puede gastar hoy, presupuesto ok, metas ok.
  withinDay,

  /// El gasto supera lo que se puede gastar hoy, pero no rompe presupuesto ni atrasa meta.
  exceedsDay,

  /// El gasto rompe el presupuesto asignado a la categoría.
  breaksBudget,

  /// El gasto atrasa al menos una meta de ahorro con fecha objetivo.
  delaysGoal,
}

/// Determina la situación de la compra según el impacto en el día, presupuesto y metas.
/// Jerarquía de advertencia: romper presupuesto > atrasar meta > exceder el día > dentro del día.
BuySituation determineBuySituation({
  required int safeToSpendAfter,
  int? budgetRemainingAfter,
  int maxGoalDelayDays = 0,
}) {
  if (budgetRemainingAfter != null && budgetRemainingAfter < 0) {
    return BuySituation.breaksBudget;
  }
  if (maxGoalDelayDays > 0) {
    return BuySituation.delaysGoal;
  }
  if (safeToSpendAfter < 0) {
    return BuySituation.exceedsDay;
  }
  return BuySituation.withinDay;
}

/// Banco curado de mensajes en español paraguayo natural para ¿Lo compro?
///
/// Variantes por nivel de tono y situación. Picante usa humor y modismos paraguayos sin insultos.
/// No contiene emojis (íconos visuales de Phosphor se usan en la UI).
const Map<ToneLevel, Map<BuySituation, List<String>>> _kBuyMessagesBank = {
  ToneLevel.soft: {
    BuySituation.withinDay: [
      'Tenés margen para este gasto hoy.',
      'Entra bien en lo que podés gastar hoy.',
      'Podés darte el gusto sin problema.',
      'Está dentro de tus posibilidades para hoy.',
    ],
    BuySituation.exceedsDay: [
      'Supera lo previsto para hoy, pero podés compensar mañana.',
      'Se pasa un poco de lo de hoy. Si podés esperar, mejor.',
      'Te vas a pasar de lo de hoy, pero con cuidado llegás al cobro.',
      'Un poco apretado para hoy, pero manejable con calma.',
    ],
    BuySituation.breaksBudget: [
      'Este gasto supera el presupuesto de la categoría.',
      'Se pasa del tope que le asignaste a esta categoría.',
      'Cuidado, vas a sobrepasar lo planificado para este rubro.',
    ],
    BuySituation.delaysGoal: [
      'Esta compra va a retrasar unos días tu meta.',
      'Tu meta se va a demorar un poco si hacés este gasto.',
      'Te aleja un poco de la fecha objetivo de tu meta.',
    ],
  },
  ToneLevel.normal: {
    BuySituation.withinDay: [
      'Metele nomás, da el cuero para hoy.',
      'Tranquilopa, entrás re bien en el día.',
      'Comprá sin culpa, estás dentro de lo tuyo.',
      'Entra holgado en el presupuesto de hoy.',
    ],
    BuySituation.exceedsDay: [
      'Chake, te comés parte de lo de mañana.',
      'Se te va la mano para hoy, vas a tener que apretar después.',
      'Pasa lo del día. Si no es urgente, mejor pensalo dos veces.',
      'Te vas a quedar corto para los próximos días.',
    ],
    BuySituation.breaksBudget: [
      'Rompés el presupuesto de la categoría. ¿Seguro que vale la pena?',
      'Te pasás del tope del mes en este rubro.',
      'Ya no queda saldo en esta categoría para este gasto.',
    ],
    BuySituation.delaysGoal: [
      'Tu meta se va a atrasar si comprás esto ahora.',
      'Le sacás días a tu meta de ahorro. Vos sabrás.',
      'Avanzabas tan bien con la meta... esto te frena un poco.',
    ],
  },
  ToneLevel.spicy: {
    BuySituation.withinDay: [
      'Metele con ganas, hoy no te fundís.',
      'El bolsillo no llora hoy, dale nomás.',
      'Aprobado por la junta del tereré. Date el gusto.',
      'Tenés luz verde. Aprovechá antes de que te arrepientas.',
    ],
    BuySituation.exceedsDay: [
      'Chake, después a fin de mes vamos a almorzar agua con hielo.',
      'Compralo y mañana desayunamos aire. Vos elegís.',
      'Tranqui nomás, total el sueldo crece en los árboles, ¿verdad?',
      'Se te fue la mano lindo. Mañana a pedalear para empatar.',
    ],
    BuySituation.breaksBudget: [
      'Rompiste todo el presupuesto. El autocontrol te mandó saludos.',
      'Ese presupuesto pedía auxilio y le diste el tiro de gracia.',
      'Voló el tope por los aires. Después no digas que nadie te avisó.',
    ],
    BuySituation.delaysGoal: [
      'Tu meta te está mirando con cara de decepción.',
      '¿La meta? Bien gracias, se fue de vacaciones más lejos todavía.',
      'Tu yo del futuro viendo cómo pateás la meta para adelante...',
    ],
  },
};

/// Devuelve la lista completa de mensajes disponibles para un [tone] y [situation].
List<String> getBuyMessagesBank({
  required ToneLevel tone,
  required BuySituation situation,
}) {
  return _kBuyMessagesBank[tone]?[situation] ??
      _kBuyMessagesBank[ToneLevel.normal]![situation]!;
}

/// Obtiene un mensaje del banco. Si se especifica [variantIndex], se selecciona
/// de forma determinista usando módulo; si no, se elige aleatoriamente.
String getBuyMessage({
  required ToneLevel tone,
  required BuySituation situation,
  int? variantIndex,
}) {
  final bank = getBuyMessagesBank(tone: tone, situation: situation);
  if (variantIndex != null) {
    return bank[variantIndex.abs() % bank.length];
  }
  final rnd = Random();
  return bank[rnd.nextInt(bank.length)];
}

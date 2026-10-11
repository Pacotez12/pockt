import 'package:pockt/features/income/domain/pay_split.dart';

/// Interfaz para cualquier elemento de descuento de sueldo.
abstract class SalaryDeductionLike {
  String get name;
  String get kind; // 'percent' | 'fixed'
  int get value;
}

/// Representación en memoria / dominio de un descuento del sueldo.
///
/// Para [kind] == 'percent', [value] se expresa en centésimas de punto
/// porcentual (ej. 900 = 9.00 %).
/// Para [kind] == 'fixed', [value] es el monto absoluto en guaraníes.
class SalaryDeductionItem implements SalaryDeductionLike {
  final String id;
  final String scheduleId;
  @override
  final String name;
  @override
  final String kind;
  @override
  final int value;

  const SalaryDeductionItem({
    this.id = '',
    this.scheduleId = '',
    required this.name,
    required this.kind,
    required this.value,
  });

  /// Monto efectivo en guaraníes que representa este descuento sobre el [gross].
  int amountForGross(int gross) {
    if (value < 0) {
      throw ArgumentError('El valor del descuento no puede ser negativo: $value');
    }
    if (kind == 'percent') {
      return (gross * (value / 10000.0)).round();
    } else if (kind == 'fixed') {
      return value;
    } else {
      throw ArgumentError('Tipo de descuento desconocido: $kind');
    }
  }

  SalaryDeductionItem copyWith({
    String? id,
    String? scheduleId,
    String? name,
    String? kind,
    int? value,
  }) {
    return SalaryDeductionItem(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      value: value ?? this.value,
    );
  }
}

/// Función pura que calcula los montos netos para cada cobro del mes.
///
/// [gross] es el sueldo bruto mensual.
/// [splitPercents] define el porcentaje correspondiente a cada cobro (ej. [30, 70]).
/// [deductions] es la lista de descuentos configurados.
///
/// Según la spec §7b, los descuentos se calculan sobre el bruto y se restan
/// del **último cobro del mes** (fin de mes).
/// Lanza [ArgumentError] si algún descuento deja el cobro en negativo.
List<int> netPayAmounts(
  int gross,
  List<int> splitPercents,
  Iterable<SalaryDeductionLike> deductions,
) {
  if (gross < 0) {
    throw ArgumentError('El sueldo bruto no puede ser negativo: $gross');
  }

  final splits = splitPercents.isEmpty ? const [100] : splitPercents;
  final grossList = splitAmounts(gross, splits);

  var totalDeductions = 0;
  for (final d in deductions) {
    if (d.value < 0) {
      throw ArgumentError('El valor del descuento no puede ser negativo: ${d.value}');
    }
    if (d.kind == 'percent') {
      totalDeductions += (gross * (d.value / 10000.0)).round();
    } else if (d.kind == 'fixed') {
      totalDeductions += d.value;
    } else {
      throw ArgumentError('Tipo de descuento desconocido: ${d.kind}');
    }
  }

  final lastGross = grossList.last;
  final lastNet = lastGross - totalDeductions;

  if (lastNet < 0) {
    throw ArgumentError(
      'Los descuentos ($totalDeductions) superan el último cobro ($lastGross). Neto negativo: $lastNet',
    );
  }

  if (grossList.length == 1) {
    return [lastNet];
  }

  return [
    ...grossList.sublist(0, grossList.length - 1),
    lastNet,
  ];
}

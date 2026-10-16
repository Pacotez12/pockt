import 'package:flutter/material.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/income/domain/pay_days.dart';
import 'package:pockt/features/income/domain/salary_deduction.dart';

Future<SalaryDeductionItem?> showSalaryDeductionDialog(
  BuildContext context, {
  SalaryDeductionItem? initial,
  int? index,
  required int? monthlyAmount,
  required PayMode mode,
  required int splitPercent1,
  required List<SalaryDeductionItem> currentDeductions,
}) async {
  final colors = context.pockt;
  final nameController = TextEditingController(text: initial?.name ?? '');
  String kind = initial?.kind ?? 'percent';
  String initialValueStr = '';
  if (initial != null) {
    if (initial.kind == 'percent') {
      final p = initial.value / 100.0;
      initialValueStr = p.toStringAsFixed(p.truncateToDouble() == p ? 0 : 2);
    } else {
      initialValueStr = initial.value.toString();
    }
  }
  final valueController = TextEditingController(text: initialValueStr);
  String? errorMessage;

  return showDialog<SalaryDeductionItem>(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          void validateAndSave() {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setDialogState(() => errorMessage = 'Ingresá un nombre');
              return;
            }

            final valStr = valueController.text.trim().replaceAll(',', '.');
            final parsed = double.tryParse(valStr);
            if (parsed == null || parsed <= 0) {
              setDialogState(
                () => errorMessage = 'Ingresá un valor válido mayor a 0',
              );
              return;
            }

            final int deductionValue;
            if (kind == 'percent') {
              deductionValue = (parsed * 100).round();
            } else {
              deductionValue = parsed.round();
            }

            final newDeduction = SalaryDeductionItem(
              id: initial?.id ?? '',
              scheduleId: initial?.scheduleId ?? '',
              name: name,
              kind: kind,
              value: deductionValue,
            );

            if (monthlyAmount != null && monthlyAmount > 0) {
              final simulatedList = List<SalaryDeductionItem>.from(
                currentDeductions,
              );
              if (index != null && index < simulatedList.length) {
                simulatedList[index] = newDeduction;
              } else {
                simulatedList.add(newDeduction);
              }

              final splits = mode == PayMode.biweekly
                  ? [splitPercent1, 100 - splitPercent1]
                  : const [100];

              try {
                netPayAmounts(monthlyAmount, splits, simulatedList);
              } catch (e) {
                setDialogState(() {
                  errorMessage =
                      'El descuento deja el cobro de fin de mes en negativo';
                });
                return;
              }
            }

            Haptics.tick();
            Navigator.of(dialogCtx).pop(newDeduction);
          }

          return AlertDialog(
            backgroundColor: colors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PocktRadii.xl),
              side: BorderSide(color: colors.glassBorder),
            ),
            title: Text(
              initial == null ? 'Agregar descuento' : 'Editar descuento',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo de descuento',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('deduction-kind-percent'),
                          onTap: () {
                            setDialogState(() {
                              kind = 'percent';
                              errorMessage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: kind == 'percent'
                                  ? colors.brandStart
                                  : colors.glassFill,
                              borderRadius: BorderRadius.circular(
                                PocktRadii.m,
                              ),
                              border: Border.all(
                                color: kind == 'percent'
                                    ? Colors.transparent
                                    : colors.glassBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Porcentaje (%)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kind == 'percent'
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Pressable(
                          key: const ValueKey('deduction-kind-fixed'),
                          onTap: () {
                            setDialogState(() {
                              kind = 'fixed';
                              errorMessage = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: kind == 'fixed'
                                  ? colors.brandStart
                                  : colors.glassFill,
                              borderRadius: BorderRadius.circular(
                                PocktRadii.m,
                              ),
                              border: Border.all(
                                color: kind == 'fixed'
                                    ? Colors.transparent
                                    : colors.glassBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Monto fijo (Gs.)',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kind == 'fixed'
                                    ? Colors.white
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nombre',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const ValueKey('deduction-name-input'),
                    controller: nameController,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ej: IPS, Seguro médico',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textTertiary,
                      ),
                      filled: true,
                      fillColor: colors.glassFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    kind == 'percent'
                        ? 'Porcentaje del sueldo bruto'
                        : 'Monto en Guaraníes',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const ValueKey('deduction-value-input'),
                    controller: valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: kind == 'percent' ? 'Ej: 9' : 'Ej: 40000',
                      hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        color: colors.textTertiary,
                      ),
                      filled: true,
                      fillColor: colors.glassFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PocktRadii.m),
                        borderSide: BorderSide(color: colors.glassBorder),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('save-deduction-dialog-button'),
                onPressed: validateAndSave,
                child: Text(
                  'Guardar',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: colors.brandStart,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

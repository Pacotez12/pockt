import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/features/home/ui/category_arc.dart';
import 'package:pockt/features/home/ui/today_arc.dart';
import 'package:pockt/features/safe_to_spend/domain/safe_to_spend.dart';

/// Encabezado principal de gasto en Inicio:
/// - Modo `monthSpent` (default): CategoryArc interactivo por categoría.
/// - Modo `safeToSpend`: Arco de hoy interactivo (Podés gastar hoy).
class HomeSpendingHeader extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;

  const HomeSpendingHeader({
    super.key,
    required this.year,
    required this.month,
    required this.nowLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headline =
        ref.watch(homeHeadlineProvider).value ?? HomeHeadline.monthSpent;

    if (headline == HomeHeadline.monthSpent) {
      return CategoryArc(
        year: year,
        month: month,
        nowLocal: nowLocal,
      );
    }

    final obscure = ref.watch(shouldObscureAmountsProvider);
    final safe = ref.watch(safeToSpendProvider).value;
    return Pressable(
      semanticLabel: 'Alternar ocultar montos',
      onTap: () => ref.read(amountsRevealedProvider.notifier).toggle(),
      child: TodayArc(
        allowance: safe?.todayAllowance ?? 0,
        spent: safe?.spentToday ?? 0,
        obscure: obscure,
        reduceMotion: ref.watch(motionReduceProvider).value ?? false,
        untilPayday: safe?.hasIncomeSchedule ?? true,
      ),
    );
  }
}

class _AnimatedMonthTotal extends StatefulWidget {
  final int total;
  final TextStyle style;

  const _AnimatedMonthTotal({
    required this.total,
    required this.style,
  });

  @override
  State<_AnimatedMonthTotal> createState() => _AnimatedMonthTotalState();
}

class _AnimatedMonthTotalState extends State<_AnimatedMonthTotal> {
  int _previousTotal = 0;

  @override
  void didUpdateWidget(_AnimatedMonthTotal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.total != widget.total) {
      _previousTotal = oldWidget.total;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: IntTween(
        begin: _previousTotal,
        end: widget.total,
      ),
      builder: (context, animatedValue, _) {
        return Text(
          formatGs(animatedValue),
          style: widget.style,
        );
      },
    );
  }
}

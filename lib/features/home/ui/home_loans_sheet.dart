import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/ui/loan_detail_screen.dart';
import 'package:pockt/features/loans/ui/loans_screen.dart';

/// Abre la hoja de Préstamos y cuotas con Hero desde la píldora superior.
Future<void> showHomeLoansSheet(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, _) =>
          HomeLoansSheet(routeAnimation: animation),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.disableAnimationsOf(context)) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: SpringCurve(spring: PocktSprings.soft),
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: RepaintBoundary(child: child),
        );
      },
    ),
  );
}

class HomeLoansSheet extends ConsumerStatefulWidget {
  final Animation<double>? routeAnimation;

  const HomeLoansSheet({
    super.key,
    this.routeAnimation,
  });

  @override
  ConsumerState<HomeLoansSheet> createState() => _HomeLoansSheetState();
}

class _HomeLoansSheetState extends ConsumerState<HomeLoansSheet> {
  Animation<double>? _anim;
  Animation<double>? _contentFadeAnim;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final anim = widget.routeAnimation ?? ModalRoute.of(context)?.animation;
    if (anim != null && anim != _anim) {
      _anim = anim;
      _contentFadeAnim = CurvedAnimation(
        parent: anim,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
        reverseCurve: const Interval(0.85, 1.0, curve: Curves.easeIn),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sheetHeight = min(MediaQuery.of(context).size.height * 0.85, 540.0);

    final loansAsync = ref.watch(activeLoansWithProgressProvider);

    Widget sheetBody = loansAsync.maybeWhen(
      data: (loans) => _buildContent(context, loans: loans, colors: colors, isDark: isDark),
      orElse: () => const SizedBox.shrink(),
    );

    if (_contentFadeAnim != null && !reduceMotion) {
      sheetBody = FadeTransition(
        opacity: _contentFadeAnim!,
        child: RepaintBoundary(child: sheetBody),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tocar fuera cierra la hoja
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: HeroMode(
              enabled: !reduceMotion,
              child: Hero(
                tag: 'home-pill-loans',
                createRectTween: (begin, end) =>
                    SpringRectTween(begin: begin, end: end),
                flightShuttleBuilder: (
                  flightContext,
                  animation,
                  flightDirection,
                  fromHeroContext,
                  toHeroContext,
                ) => buildDayDetailFlightShuttle(
                  flightContext,
                  animation,
                  flightDirection,
                  fromHeroContext,
                  toHeroContext,
                  colors,
                  isDark,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: sheetHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colors.sheetSurface.withValues(
                        alpha: isDark ? 0.96 : 0.98,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 1.0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: sheetBody,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<LoanWithProgress> loans,
    required PocktColors colors,
    required bool isDark,
  }) {
    final obscure = ref.watch(shouldObscureAmountsProvider);

    int totalOwe = 0;
    int totalLent = 0;
    final oweLoans = <LoanWithProgress>[];
    final lentLoans = <LoanWithProgress>[];

    for (final item in loans) {
      if (item.loan.direction == LoanDirection.owe) {
        totalOwe += item.progress.balance;
        oweLoans.add(item);
      } else {
        totalLent += item.progress.balance;
        lentLoans.add(item);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indicador de arrastre superior
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 120) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.20),
                ),
              ),
            ),
          ),
        ),
        // Cabecera: Título y "Ver todo ›"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Préstamos',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              Pressable(
                onTap: () {
                  Haptics.tick();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoansScreen()),
                  );
                },
                child: Text(
                  'Ver todo ›',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cuerpo desplazable
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sección Debés
                Text(
                  'DEBÉS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      obscure ? '••••' : formatGs(totalOwe),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.danger,
                      ),
                    ),
                    Text(
                      '${oweLoans.length} ${oweLoans.length == 1 ? "activo" : "activos"}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tarjetas de deudas
                for (final item in oweLoans) ...[
                  _buildOweItem(context, item: item, colors: colors, isDark: isDark, obscure: obscure),
                  const SizedBox(height: 8),
                ],

                // Sección Te deben (si aplica)
                if (totalLent > 0) ...[
                  const SizedBox(height: 14),
                  Text(
                    'TE DEBEN',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in lentLoans) ...[
                    _buildLentItem(context, item: item, colors: colors, isDark: isDark, obscure: obscure),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
        // Botón principal: "Registrar pago"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Pressable(
            key: const ValueKey('home-loans-sheet-action'),
            onTap: () {
              Haptics.tick();
              if (oweLoans.isEmpty) return;
              if (oweLoans.length == 1) {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => LoanPaymentSheet(
                    loan: oweLoans.first.loan,
                    progress: oweLoans.first.progress,
                    isExtra: false,
                  ),
                );
              } else {
                _showLoanPicker(context, oweLoans: oweLoans, colors: colors);
              }
            },
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [colors.brandStart, colors.brandEnd],
                ),
              ),
              child: const Center(
                child: Text(
                  'Registrar pago',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOweItem(
    BuildContext context, {
    required LoanWithProgress item,
    required PocktColors colors,
    required bool isDark,
    required bool obscure,
  }) {
    final loan = item.loan;
    final progress = item.progress;

    final dueBadge = loan.dueDay != null ? 'Día ${loan.dueDay}' : '';
    final installment = loan.installmentAmount ?? progress.balance;
    final ratio = progress.percent.clamp(0.0, 1.0);

    final subtext = (loan.installmentsTotal != null && loan.installmentsTotal! > 0)
        ? '${progress.installmentsPaid} de ${loan.installmentsTotal}'
        : 'Saldo ${obscure ? "••••" : formatGs(progress.balance)}';

    return Pressable(
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoanDetailScreen(loanId: loan.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.black.withValues(alpha: 0.035),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    loan.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dueBadge.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.glassFill,
                      border: Border.all(color: colors.glassBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dueBadge,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cuota ${obscure ? "••••" : formatGs(installment)}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            // Barrita de avance
            Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: colors.glassBorder.withValues(alpha: isDark ? 0.20 : 0.10),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [colors.brandStart, colors.brandEnd],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLentItem(
    BuildContext context, {
    required LoanWithProgress item,
    required PocktColors colors,
    required bool isDark,
    required bool obscure,
  }) {
    return Pressable(
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoanDetailScreen(loanId: item.loan.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isDark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.black.withValues(alpha: 0.035),
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                item.loan.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              obscure ? '••••' : formatGs(item.progress.balance),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.positive,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanPicker(
    BuildContext context, {
    required List<LoanWithProgress> oweLoans,
    required PocktColors colors,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.sheetSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Elegí el préstamo para registrar el pago',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            for (final item in oweLoans)
              ListTile(
                title: Text(item.loan.name),
                subtitle: Text('Saldo: ${formatGs(item.progress.balance)}'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => LoanPaymentSheet(
                      loan: item.loan,
                      progress: item.progress,
                      isExtra: false,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

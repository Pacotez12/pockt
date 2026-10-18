
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/goals/domain/goal_progress.dart';
import 'package:pockt/features/goals/ui/goal_detail_screen.dart';
import 'package:pockt/features/goals/ui/goals_screen.dart';
import 'package:pockt/features/home/ui/day_detail_sheet.dart';

/// Abre la hoja de Metas con Hero desde la píldora superior.
Future<void> showHomeGoalsSheet(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, _) =>
          HomeGoalsSheet(routeAnimation: animation),
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

class HomeGoalsSheet extends ConsumerStatefulWidget {
  final Animation<double>? routeAnimation;

  const HomeGoalsSheet({
    super.key,
    this.routeAnimation,
  });

  @override
  ConsumerState<HomeGoalsSheet> createState() => _HomeGoalsSheetState();
}

class _HomeGoalsSheetState extends ConsumerState<HomeGoalsSheet> {
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
    // La hoja crece con el contenido hasta el 85 % de la pantalla; después, scroll.
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    final goalsAsync = ref.watch(activeGoalsWithProgressProvider);

    Widget sheetBody = goalsAsync.maybeWhen(
      data: (goals) => _buildContent(context, goals: goals, colors: colors, isDark: isDark),
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
                tag: 'home-pill-goals',
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
                    key: const ValueKey('home-goals-sheet-surface'),
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
    required List<GoalWithProgress> goals,
    required PocktColors colors,
    required bool isDark,
  }) {
    final obscure = ref.watch(shouldObscureAmountsProvider);

    final totalSaved = goals.fold<int>(
      0,
      (sum, item) => sum + item.progress.saved,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                'Metas',
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
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
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
        Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sección Ahorrado
                Text(
                  'AHORRADO',
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
                      obscure ? '••••' : formatGs(totalSaved),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: colors.brandStart,
                      ),
                    ),
                    Text(
                      '${goals.length} ${goals.length == 1 ? "activa" : "activas"}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Tarjetas de metas
                for (final item in goals) ...[
                  _buildGoalItem(context, item: item, colors: colors, isDark: isDark, obscure: obscure),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        // Botón principal: "Aportar"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Pressable(
            key: const ValueKey('home-goals-sheet-action'),
            onTap: () {
              Haptics.tick();
              if (goals.isEmpty) return;
              if (goals.length == 1) {
                openGoalKeypad(context, goal: goals.first.goal, isWithdraw: false);
              } else {
                _showGoalPicker(context, goals: goals, colors: colors);
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
                  'Aportar',
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

  Widget _buildGoalItem(
    BuildContext context, {
    required GoalWithProgress item,
    required PocktColors colors,
    required bool isDark,
    required bool obscure,
  }) {
    final goal = item.goal;
    final progress = item.progress;

    final ratio = progress.percent.clamp(0.0, 1.0);
    final percentText = '${(progress.percent * 100).round()} %';

    final String? statusText;
    final Color? statusColor;
    switch (progress.status) {
      case GoalStatusOnTrack():
        statusText = 'a tiempo';
        statusColor = colors.positive;
      case GoalStatusLate(months: final m):
        statusText = '$m ${m == 1 ? "mes" : "meses"} tarde';
        statusColor = colors.warning;
      case GoalStatusNoDate():
        statusText = null;
        statusColor = null;
    }

    final amountText = '${obscure ? "••••" : formatGs(progress.saved)} de ${obscure ? "••••" : formatGs(goal.targetAmount)}';

    return Pressable(
      onTap: () {
        Haptics.tick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GoalDetailScreen(goalId: goal.id),
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
                    goal.name,
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
                  percentText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                if (statusText != null)
                  Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor ?? colors.textTertiary,
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

  void _showGoalPicker(
    BuildContext context, {
    required List<GoalWithProgress> goals,
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
                'Elegí la meta para aportar',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            for (final item in goals)
              ListTile(
                title: Text(item.goal.name),
                subtitle: Text('Ahorrado: ${formatGs(item.progress.saved)} de ${formatGs(item.goal.targetAmount)}'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  openGoalKeypad(context, goal: item.goal, isWithdraw: false);
                },
              ),
          ],
        ),
      ),
    );
  }
}

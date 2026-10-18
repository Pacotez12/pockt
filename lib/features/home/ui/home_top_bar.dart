import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/format/money.dart';
import 'package:pockt/core/settings/amounts_privacy.dart';
import 'package:pockt/features/goals/data/goals_repository.dart';
import 'package:pockt/features/home/ui/home_goals_sheet.dart';
import 'package:pockt/features/home/ui/home_loans_sheet.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/settings/ui/settings_screen.dart';

const List<String> kMonthNames = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const List<String> kMonthShortNames = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// Barra superior de Inicio: selector desplegable de mes, accesos rápidos a
/// Préstamos y Metas como píldoras colapsables con Hero, y botón de Ajustes.
class HomeTopBar extends ConsumerStatefulWidget {
  final int month;
  final ValueChanged<int> onMonthSelected;

  const HomeTopBar({
    super.key,
    required this.month,
    required this.onMonthSelected,
  });

  @override
  ConsumerState<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends ConsumerState<HomeTopBar>
    with TickerProviderStateMixin {
  late final AnimationController _pulseLoansController;
  late final AnimationController _pulseGoalsController;
  late final Animation<double> _pulseLoansAnimation;
  late final Animation<double> _pulseGoalsAnimation;

  Timer? _collapseTimer;
  bool _isExpanded = true;
  bool _initializedMotion = false;
  OverlayEntry? _tooltipOverlay;

  final GlobalKey _loansKey = GlobalKey();
  final GlobalKey _goalsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseLoansController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseGoalsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pulseLoansAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseLoansController);

    _pulseGoalsAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.05,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.05,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseGoalsController);

    _startCollapseTimer();
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isExpanded = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedMotion) {
      _initializedMotion = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _isExpanded = false;
        _collapseTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    _pulseLoansController.dispose();
    _pulseGoalsController.dispose();
    _removeTooltip();
    super.dispose();
  }

  void _onCountChanged({required bool isLoan}) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      if (isLoan) {
        _pulseLoansController.forward(from: 0.0);
      } else {
        _pulseGoalsController.forward(from: 0.0);
      }
      setState(() {
        _isExpanded = true;
      });
      _startCollapseTimer();
    }
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
  }

  void _showTooltip(
    BuildContext context, {
    required GlobalKey pillKey,
    required String title,
    required String subtitle,
  }) {
    _removeTooltip();
    final renderBox = pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _BalloonTooltip(
        title: title,
        subtitle: subtitle,
        targetOffset: targetOffset,
        targetSize: targetSize,
      ),
    );
    overlay.insert(entry);
    _tooltipOverlay = entry;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final obscure = ref.watch(shouldObscureAmountsProvider);

    final loansAsync = ref.watch(activeLoansWithProgressProvider);
    final goalsAsync = ref.watch(activeGoalsWithProgressProvider);

    final loans = loansAsync.value ?? const [];
    final goals = goalsAsync.value ?? const [];

    final loansCount = loans.length;
    final goalsCount = goals.length;

    ref.listen<AsyncValue<List<LoanWithProgress>>>(
      activeLoansWithProgressProvider,
      (prev, next) {
        final prevCount = prev?.value?.length;
        final nextCount = next.value?.length ?? 0;
        if (prevCount != null && prevCount != nextCount && nextCount > 0) {
          _onCountChanged(isLoan: true);
        }
      },
    );

    ref.listen<AsyncValue<List<GoalWithProgress>>>(
      activeGoalsWithProgressProvider,
      (prev, next) {
        final prevCount = prev?.value?.length;
        final nextCount = next.value?.length ?? 0;
        if (prevCount != null && prevCount != nextCount && nextCount > 0) {
          _onCountChanged(isLoan: false);
        }
      },
    );

    int totalOwe = 0;
    for (final l in loans) {
      if (l.loan.direction == LoanDirection.owe) {
        totalOwe += l.progress.balance.round();
      }
    }

    int totalSaved = 0;
    for (final g in goals) {
      totalSaved += g.progress.saved.round();
    }

    final hasActivePills = loansCount > 0 || goalsCount > 0;
    final showShortMonth = _isExpanded && hasActivePills;
    final monthLabel = showShortMonth
        ? '${kMonthShortNames[widget.month - 1]} ▾'
        : '${kMonthNames[widget.month - 1]} ▾';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<int>(
          initialValue: widget.month,
          tooltip: 'Elegir mes',
          onSelected: (m) {
            if (m != widget.month) {
              Haptics.tick();
              widget.onMonthSelected(m);
            }
          },
          itemBuilder: (context) => [
            for (int m = 1; m <= 12; m++)
              PopupMenuItem(
                value: m,
                child: Text(
                  kMonthNames[m - 1],
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: m == widget.month
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PocktRadii.l),
              color: colors.glassFill,
              border: Border.all(color: colors.glassBorder),
            ),
            // El ancho del chip acompaña el cambio "Oct" ↔ "Octubre".
            child: AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                // El texto que sale se va enseguida y el nuevo aparece mientras el
                // chip cambia de ancho: así "Oct" y "Octubre" no se superponen.
                switchOutCurve: const Threshold(1.0),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Text(
                  monthLabel,
                  key: ValueKey(monthLabel),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loansCount > 0) ...[
              _buildPill(
                key: const ValueKey('home-pill-loans'),
                pillGlobalKey: _loansKey,
                label: 'Préstamos',
                count: loansCount,
                icon: uiIcon('hand-coins'),
                color: colors.danger,
                heroTag: 'home-pill-loans',
                pulseAnimation: _pulseLoansAnimation,
                onTap: () {
                  Haptics.tick();
                  showHomeLoansSheet(context);
                },
                title:
                    'Préstamos · $loansCount ${loansCount == 1 ? "activo" : "activos"}',
                subtitle:
                    'Debés ${obscure ? "••••" : formatGs(totalOwe)} · tocá para ver',
                colors: colors,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(width: 6),
            ],
            if (goalsCount > 0) ...[
              _buildPill(
                key: const ValueKey('home-pill-goals'),
                pillGlobalKey: _goalsKey,
                label: 'Metas',
                count: goalsCount,
                icon: uiIcon('target'),
                color: colors.brandStart,
                heroTag: 'home-pill-goals',
                pulseAnimation: _pulseGoalsAnimation,
                onTap: () {
                  Haptics.tick();
                  showHomeGoalsSheet(context);
                },
                title:
                    'Metas · $goalsCount ${goalsCount == 1 ? "activa" : "activas"}',
                subtitle:
                    'Ahorrado ${obscure ? "••••" : formatGs(totalSaved)} · tocá para ver',
                colors: colors,
                reduceMotion: reduceMotion,
              ),
              const SizedBox(width: 6),
            ],
            Pressable(
              semanticLabel: 'Ajustes',
              key: const ValueKey('home-settings-button'),
              onTap: () {
                Haptics.tick();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.glassFill,
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Center(
                  child: Icon(
                    uiIcon('gear'),
                    size: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPill({
    required Key key,
    required GlobalKey pillGlobalKey,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required String heroTag,
    required Animation<double> pulseAnimation,
    required VoidCallback onTap,
    required String title,
    required String subtitle,
    required PocktColors colors,
    required bool reduceMotion,
  }) {
    final pillWidget = GestureDetector(
      key: pillGlobalKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (_) {
        Haptics.tick();
        _showTooltip(
          context,
          pillKey: pillGlobalKey,
          title: title,
          subtitle: subtitle,
        );
      },
      onLongPressEnd: (_) => _removeTooltip(),
      onLongPressCancel: () => _removeTooltip(),
      child: Semantics(
        button: true,
        label: label,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: colors.glassFill,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              // El nombre se desliza y se desvanece al achicarse (no de golpe).
              TweenAnimationBuilder<double>(
                tween: Tween(end: _isExpanded ? 1.0 : 0.0),
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) {
                  if (t == 0) return const SizedBox.shrink();
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: Opacity(opacity: t, child: child),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return KeyedSubtree(
      key: key,
      child: ScaleTransition(
        scale: reduceMotion
            ? const AlwaysStoppedAnimation(1.0)
            : pulseAnimation,
        child: HeroMode(
          enabled: !reduceMotion,
          child: Hero(
            tag: heroTag,
            child: Material(color: Colors.transparent, child: pillWidget),
          ),
        ),
      ),
    );
  }
}

class _BalloonTooltip extends StatelessWidget {
  final String title;
  final String subtitle;
  final Offset targetOffset;
  final Size targetSize;

  const _BalloonTooltip({
    required this.title,
    required this.subtitle,
    required this.targetOffset,
    required this.targetSize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final top = targetOffset.dy + targetSize.height + 8;
    final screenWidth = MediaQuery.of(context).size.width;
    final right = (screenWidth - (targetOffset.dx + targetSize.width)).clamp(
      16.0,
      screenWidth - 100,
    );

    return Positioned(
      top: top,
      right: right,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: colors.sheetSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

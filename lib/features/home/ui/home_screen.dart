import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/core/settings/settings_repository.dart';
import 'package:pockt/core/time/local_time.dart';
import 'package:pockt/features/backup/domain/backup_service.dart';
import 'package:pockt/features/home/data/home_providers.dart';
import 'package:pockt/features/home/domain/home_cards_config.dart';
import 'package:pockt/features/home/domain/home_period_summary.dart';
import 'package:pockt/features/home/ui/home_cards.dart';
import 'package:pockt/features/home/ui/home_month_card.dart';
import 'package:pockt/features/home/ui/home_spending_header.dart';
import 'package:pockt/features/home/ui/home_top_bar.dart';

export 'package:pockt/features/home/data/home_providers.dart';
export 'package:pockt/features/home/domain/home_period_summary.dart';
export 'package:pockt/features/home/ui/home_cards.dart';
export 'package:pockt/features/home/ui/home_month_card.dart';
export 'package:pockt/features/home/ui/home_spending_header.dart';
export 'package:pockt/features/home/ui/home_top_bar.dart';

/// Pantalla principal: Inicio con selector de mes, total animado,
/// resplandor ambiental, barra segmentada por categoría, calendario de calor
/// y últimos movimientos.
class HomeScreen extends ConsumerStatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final DateTime? nowLocal;

  const HomeScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.nowLocal,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _year;
  late int _month;
  late DateTime _nowLocal;

  @override
  void initState() {
    super.initState();
    _nowLocal = widget.nowLocal ?? toLocal(DateTime.now());
    _year = widget.initialYear ?? _nowLocal.year;
    _month = widget.initialMonth ?? _nowLocal.month;
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialYear != oldWidget.initialYear ||
        widget.initialMonth != oldWidget.initialMonth ||
        widget.nowLocal != oldWidget.nowLocal) {
      _nowLocal = widget.nowLocal ?? toLocal(DateTime.now());
      _year = widget.initialYear ?? _nowLocal.year;
      _month = widget.initialMonth ?? _nowLocal.month;
    }
  }

  void _changeMonth(int delta) {
    Haptics.tick();
    setState(() {
      var newMonth = _month + delta;
      var newYear = _year;
      if (newMonth > 12) {
        newMonth = 1;
        newYear++;
      } else if (newMonth < 1) {
        newMonth = 12;
        newYear--;
      }
      _month = newMonth;
      _year = newYear;
    });
  }

  void _handleHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v < -150) {
      _changeMonth(1);
    } else if (v > 150) {
      _changeMonth(-1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScreenContent(
      year: _year,
      month: _month,
      nowLocal: _nowLocal,
      onMonthSelected: (m) {
        setState(() {
          _month = m;
        });
      },
      onHorizontalSwipe: _handleHorizontalSwipe,
    );
  }
}

class _HomeScreenContent extends ConsumerWidget {
  final int year;
  final int month;
  final DateTime nowLocal;
  final ValueChanged<int> onMonthSelected;
  final GestureDragEndCallback onHorizontalSwipe;

  const _HomeScreenContent({
    required this.year,
    required this.month,
    required this.nowLocal,
    required this.onMonthSelected,
    required this.onHorizontalSwipe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final weekStart = ref.watch(weekStartProvider).value ?? WeekStart.monday;
    final cardsConfig =
        ref.watch(homeCardsConfigProvider).value ?? defaultHomeCards;
    final headline =
        ref.watch(homeHeadlineProvider).value ?? HomeHeadline.safeToSpend;
    final arcHome = headline == HomeHeadline.safeToSpend;

    final periodSummary = ref.watch(homePeriodSummaryProvider(nowLocal));

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Resplandor ambiental de mes en el fondo
          HomeGlowHost(year: year, month: month, nowLocal: nowLocal),
          // Contenido con scroll
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  HomeTopBar(
                    month: month,
                    onMonthSelected: onMonthSelected,
                  ),
                  const SizedBox(height: 20),
                  HomeSpendingHeader(
                    year: year,
                    month: month,
                    nowLocal: nowLocal,
                  ),
                  if (arcHome) ...[
                    const SizedBox(height: 14),
                    HomeMonthCard(
                      year: year,
                      month: month,
                      nowLocal: nowLocal,
                      periodLine: periodSummary.periodLine,
                      schedule: periodSummary.schedule,
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    CategorySegmentedBar(
                      year: year,
                      month: month,
                      nowLocal: nowLocal,
                    ),
                  ],
                  StreamBuilder<BackupStatus>(
                    stream: ref.watch(backupServiceProvider).watchStatus(),
                    builder: (context, snapshot) {
                      if (snapshot.data?.isOverdue == true) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: HomeOverdueBackupBanner(
                            never: snapshot.data!.lastSuccessAt == null,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  ...cardsConfig
                      .where((item) => item.visible)
                      .map(
                        (item) => _buildCardById(
                          item.id,
                          periodSummary: periodSummary,
                          weekStart: weekStart,
                          arcHome: arcHome,
                        ),
                      )
                      .whereType<Widget>(),
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildCardById(
    String id, {
    required HomePeriodSummary periodSummary,
    required WeekStart weekStart,
    required bool arcHome,
  }) {
    switch (id) {
      case 'period':
        return HomePeriodCard(
          periodLine: periodSummary.periodLine,
          payPeriodStart: periodSummary.payPeriodStart,
          schedule: periodSummary.schedule,
          arcHome: arcHome,
        );
      case 'loans':
        return const HomeLoansCard();
      case 'goals':
        return const HomeGoalsCard();
      case 'suggestions':
        return const HomePendingSuggestionsCard();
      case 'calendar':
        return HomeCalendarCard(
          year: year,
          month: month,
          todayLocal: nowLocal,
          weekStart: weekStart,
          onHorizontalSwipe: onHorizontalSwipe,
        );
      case 'recent':
        return HomeRecentTransactionsCard(nowLocal: nowLocal);
      default:
        return null;
    }
  }
}

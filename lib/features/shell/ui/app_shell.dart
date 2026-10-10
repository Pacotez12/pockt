import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/budgets/ui/budgets_screen.dart';
import 'package:pockt/features/entry/ui/entry_flow.dart';
import 'package:pockt/features/home/ui/home_screen.dart';
import 'package:pockt/features/reports/ui/reports_screen.dart';
import 'package:pockt/features/transactions/ui/transactions_screen.dart';
import 'package:pockt/features/widget/home_widget_bridge.dart';

/// Shell principal con barra flotante de vidrio y selector de pestañas:
/// Inicio · Movimientos · ＋ · Presupuestos · Reportes.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHomeWidgetLaunch();
    });
  }

  Future<void> _initHomeWidgetLaunch() async {
    final platform = ref.read(homeWidgetPlatformProvider);
    try {
      final initialUri = await platform.initiallyLaunchedUri();
      if (initialUri != null && mounted) {
        await handleWidgetLaunchUri(context, initialUri);
      }
    } catch (_) {}

    try {
      _widgetClickSub = platform.widgetClicks.listen(
        (uri) async {
          if (uri != null && mounted) {
            await handleWidgetLaunchUri(context, uri);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Pantallas activas
          IndexedStack(
            index: _currentIndex,
            children: const [
              HomeScreen(),
              TransactionsScreen(),
              BudgetsScreen(),
              ReportsScreen(),
            ],
          ),
          // Fade inferior para que el scroll pase suavemente detrás de la barra
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      colors.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Barra flotante de vidrio
          Positioned(
            left: 16,
            right: 16,
            bottom: 18 + bottomInset,
            child: GlassBar(
              borderRadius: BorderRadius.circular(32),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      label: 'Inicio',
                      iconKey: 'house',
                    ),
                    _buildNavItem(
                      key: const ValueKey('tab-movimientos'),
                      index: 1,
                      label: 'Movimientos',
                      iconKey: 'arrows-left-right',
                    ),
                    _buildCenterPlusButton(),
                    _buildNavItem(
                      index: 2,
                      label: 'Presupuestos',
                      iconKey: 'chart-pie-slice',
                    ),
                    _buildNavItem(
                      index: 3,
                      label: 'Reportes',
                      iconKey: 'chart-bar',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    Key? key,
    required int index,
    required String label,
    required String iconKey,
  }) {
    final isSelected = _currentIndex == index;
    final colors = context.pockt;

    return Expanded(
      child: Pressable(
        key: key,
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                uiIcon(iconKey, filled: isSelected),
                size: 20,
                color: isSelected ? colors.textPrimary : colors.textTertiary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.textPrimary : colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterPlusButton() {
    final colors = context.pockt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Pressable(
        key: const ValueKey('shell-plus-button'),
        onTap: () => showEntryFlow(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.brandStart, colors.brandEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.brandEnd.withValues(alpha: 0.40),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              uiIcon('plus'),
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

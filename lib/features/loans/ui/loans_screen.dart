import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pockt/core/db/app_database.dart';
import 'package:pockt/core/db/tables.dart';
import 'package:pockt/core/format/dates.dart';
import 'package:pockt/core/design/glass.dart';
import 'package:pockt/core/design/haptics.dart';
import 'package:pockt/core/design/icons.dart';
import 'package:pockt/core/design/motion.dart';
import 'package:pockt/core/design/tokens.dart';
import 'package:pockt/features/loans/data/loans_repository.dart';
import 'package:pockt/features/loans/domain/loan_progress.dart';
import 'package:pockt/features/loans/ui/loan_detail_screen.dart';
import 'package:pockt/features/loans/ui/loan_editor.dart';

enum LoansTab { owe, lent, closed }

class LoansScreen extends ConsumerStatefulWidget {
  const LoansScreen({super.key});

  @override
  ConsumerState<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends ConsumerState<LoansScreen> {
  LoansTab _currentTab = LoansTab.owe;

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final repo = ref.watch(loansRepositoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.glassFill,
                        border: Border.all(color: colors.glassBorder),
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('arrow-left'),
                          size: 18,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Préstamos y cuotas',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'Seguimiento de deudas y préstamos',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pressable(
                    onTap: () {
                      Haptics.tick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoanEditorScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.brandStart,
                      ),
                      child: Center(
                        child: Icon(
                          uiIcon('plus'),
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Segmented control de pestañas: Debo / Presté / Terminados
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.glassFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.glassBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Debo',
                        selected: _currentTab == LoansTab.owe,
                        onTap: () {
                          Haptics.tick();
                          setState(() => _currentTab = LoansTab.owe);
                        },
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Presté',
                        selected: _currentTab == LoansTab.lent,
                        onTap: () {
                          Haptics.tick();
                          setState(() => _currentTab = LoansTab.lent);
                        },
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Terminados',
                        selected: _currentTab == LoansTab.closed,
                        onTap: () {
                          Haptics.tick();
                          setState(() => _currentTab = LoansTab.closed);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Lista según la pestaña activa
            Expanded(
              child: _buildTabList(context, repo, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabList(BuildContext context, LoansRepository repo, PocktColors colors) {
    final AsyncValue<List<Loan>> loansAsync = switch (_currentTab) {
      LoansTab.owe => ref.watch(activeLoansProvider(LoanDirection.owe)),
      LoansTab.lent => ref.watch(activeLoansProvider(LoanDirection.lent)),
      LoansTab.closed => ref.watch(closedLoansProvider),
    };

    final loans = loansAsync.value ?? [];

    if (loans.isEmpty) {
      final emptyText = switch (_currentTab) {
        LoansTab.owe => 'No tenés deudas ni compras en cuotas activas.',
        LoansTab.lent => 'No prestaste dinero a nadie actualmente.',
        LoansTab.closed => 'No tenés préstamos finalizados todavía.',
      };

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(uiIcon('coins'), size: 40, color: colors.textTertiary),
              const SizedBox(height: 12),
              Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        return _LoanCard(loan: loan);
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.pockt;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (isDark ? colors.brandStart.withValues(alpha: 0.20) : colors.brandStart.withValues(alpha: 0.14))
              : Colors.transparent,
          border: selected ? Border.all(color: colors.brandStart.withValues(alpha: 0.35)) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.brandStart : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoanCard extends ConsumerWidget {
  final Loan loan;

  const _LoanCard({required this.loan});

  String _formatGs(int amount) {
    final formatter = NumberFormat('#,###', 'es_PY');
    return '₲ ${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.pockt;
    final payments = ref.watch(loanPaymentsProvider(loan.id)).value ?? [];
    final progress = calculateLoanProgress(loan: loan, payments: payments);

        // Vencimiento etiqueta (solo si está activo y faltan <= 5 días)
        Widget? dueBadge;
        if (!progress.isClosed && progress.daysUntilNextDue != null && progress.daysUntilNextDue! <= 5) {
          final days = progress.daysUntilNextDue!;
          final isDanger = days <= 0;
          final label = days <= 0
              ? (days == 0 ? 'Vence hoy' : 'Vencido')
              : 'Vence en $days día${days == 1 ? '' : 's'}';
          final badgeColor = isDanger ? colors.danger : colors.warning;

          dueBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(uiIcon('warning'), size: 12, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Pressable(
            onTap: () {
              Haptics.tick();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoanDetailScreen(loanId: loan.id),
                ),
              );
            },
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila superior: Título, contraparte y badge de vencimiento
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loan.name,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (loan.counterparty != null && loan.counterparty!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                loan.counterparty!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ?dueBadge,
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Saldo pendiente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo pendiente',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        _formatGs(progress.balance),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Barra de progreso
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.percent,
                      minHeight: 6,
                      backgroundColor: colors.glassBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress.isClosed ? colors.positive : colors.brandStart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Pie de la tarjeta: N de M cuotas · Fin estimado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loan.installmentsTotal != null
                            ? '${progress.installmentsPaid} de ${loan.installmentsTotal} cuotas'
                            : '${progress.installmentsPaid} cuota${progress.installmentsPaid == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      if (progress.estimatedEndDate != null)
                        Text(
                          'Fin est. ${formatMonthYear(progress.estimatedEndDate!)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

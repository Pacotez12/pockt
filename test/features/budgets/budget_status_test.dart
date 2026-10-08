import 'package:flutter_test/flutter_test.dart';
import 'package:pockt/features/budgets/domain/budget_status.dart';

void main() {
  test('budgetStatus(79, 100) -> ok, (80, 100) -> warning, (100, 100) -> over', () {
    final s79 = budgetStatus(79, 100);
    expect(s79.level, BudgetLevel.ok);
    expect(s79.ratio, 0.79);
    expect(s79.remaining, 21);

    final s80 = budgetStatus(80, 100);
    expect(s80.level, BudgetLevel.warning);
    expect(s80.ratio, 0.8);
    expect(s80.remaining, 20);

    final s99 = budgetStatus(99, 100);
    expect(s99.level, BudgetLevel.warning);
    expect(s99.ratio, 0.99);
    expect(s99.remaining, 1);

    final s100 = budgetStatus(100, 100);
    expect(s100.level, BudgetLevel.over);
    expect(s100.ratio, 1.0);
    expect(s100.remaining, 0);

    final s112 = budgetStatus(112, 100);
    expect(s112.level, BudgetLevel.over);
    expect(s112.ratio, 1.12);
    expect(s112.remaining, -12);
  });
}

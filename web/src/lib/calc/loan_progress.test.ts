import { describe, it, expect } from 'vitest';
import { calculateLoanProgress } from './loan_progress';

describe('loan_progress timezone safety (5h)', () => {
  it('detects a payment made on the 1st of the month as paid this month even in negative UTC offset timezones', () => {
    // A loan with no installments schedule, dueDay 5, installmentAmount 100,000
    // Today is 2026-11-08 (after dueDay 5).
    // Payment of 100,000 occurred on 2026-11-01 ('2026-11-01' string).
    // Since payment was made this month, nextDueDate should be in December (2026-12-05).
    // If '2026-11-01' is parsed as UTC midnight in UTC-3, it shifts to 2026-10-31,
    // causing paidThisMonth to be false, which would incorrectly set nextDueDate or affect calculations.
    
    // We test with loan without fixed schedule
    const loan = {
      id: 'loan-1',
      name: 'Préstamo',
      direction: 'owe',
      totalAmount: 1000000,
      installmentAmount: 100000,
      dueDay: 5,
    };

    // When today is 2026-11-04 (before dueDay 5):
    // If not paid, nextDueDate is 2026-11-05.
    // If paid on 2026-11-01, paidThisMonth is true, so nextDueDate should be 2026-12-05!
    const payments = [
      {
        id: 'p1',
        type: 'expense',
        amount: 100000,
        occurredAt: '2026-11-01',
      },
    ];

    const result = calculateLoanProgress({
      loan: loan as any,
      schedule: [],
      payments: payments as any,
      now: new Date(2026, 10, 4), // 2026-11-04 local
    });

    // Because payment was made on 2026-11-01, this month's installment is already paid.
    // nextDueDate MUST be 2026-12-05, NOT 2026-11-05.
    expect(result.nextDueDate).toBe('2026-12-05');
  });
});

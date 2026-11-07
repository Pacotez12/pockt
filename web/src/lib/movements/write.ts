export interface DBExecutable {
  execute(sql: string, params?: any[]): Promise<any>;
  getAll?<T>(sql: string, params?: any[]): Promise<T[]>;
  getOptional?<T>(sql: string, params?: any[]): Promise<T | null>;
}

export interface CreateMovementInput {
  type: 'expense' | 'income' | 'transfer';
  amount: number;
  categoryId: string;
  occurredAt: number | Date;
  merchant?: string | null;
  note?: string | null;
}

export interface UpdateMovementInput {
  type?: 'expense' | 'income' | 'transfer';
  amount?: number;
  categoryId?: string;
  occurredAt?: number | Date;
  merchant?: string | null;
  note?: string | null;
}

function validateAmount(amount: number): void {
  if (typeof amount !== 'number' || !Number.isInteger(amount) || amount <= 0) {
    throw new Error('El monto debe ser un entero positivo sin decimales.');
  }
}

function toUnixSeconds(val: number | Date): number {
  if (val instanceof Date) {
    return Math.floor(val.getTime() / 1000);
  }
  // If already in seconds (e.g. < 1e11), keep; if in ms, convert to seconds
  return val > 1e11 ? Math.floor(val / 1000) : Math.floor(val);
}

export async function createMovement(
  db: DBExecutable,
  input: CreateMovementInput
): Promise<string> {
  validateAmount(input.amount);

  const id = crypto.randomUUID();
  const now = Math.floor(Date.now() / 1000);
  const occurredAt = toUnixSeconds(input.occurredAt);
  const merchant = input.merchant?.trim() || null;
  const note = input.note?.trim() || null;

  const sql = `INSERT INTO transactions (
    id, type, amount, currency, category_id, merchant, note,
    occurred_at, created_at, updated_at, source, is_extra, deleted_at
  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;

  const params = [
    id,
    input.type,
    input.amount,
    'PYG',
    input.categoryId,
    merchant,
    note,
    occurredAt,
    now,
    now,
    'manual',
    0,
    null,
  ];

  await db.execute(sql, params);
  return id;
}

async function checkLoanMovement(db: DBExecutable, id: string): Promise<void> {
  if (typeof db.getOptional === 'function') {
    const row = await db.getOptional<{ loan_id: string | null }>(
      'SELECT loan_id FROM transactions WHERE id = ?',
      [id]
    );
    if (row && row.loan_id) {
      throw new Error(
        'Los movimientos vinculados a un préstamo no se pueden editar ni borrar desde la web.'
      );
    }
  } else if (typeof db.getAll === 'function') {
    const rows = await db.getAll<{ loan_id: string | null }>(
      'SELECT loan_id FROM transactions WHERE id = ?',
      [id]
    );
    if (rows.length > 0 && rows[0].loan_id) {
      throw new Error(
        'Los movimientos vinculados a un préstamo no se pueden editar ni borrar desde la web.'
      );
    }
  }
}

export async function updateMovement(
  db: DBExecutable,
  id: string,
  input: UpdateMovementInput
): Promise<void> {
  await checkLoanMovement(db, id);

  if (input.amount !== undefined) {
    validateAmount(input.amount);
  }

  const setClauses: string[] = [];
  const params: any[] = [];

  if (input.type !== undefined) {
    setClauses.push('type = ?');
    params.push(input.type);
  }

  if (input.amount !== undefined) {
    setClauses.push('amount = ?');
    params.push(input.amount);
  }

  if (input.categoryId !== undefined) {
    setClauses.push('category_id = ?');
    params.push(input.categoryId);
  }

  if (input.occurredAt !== undefined) {
    setClauses.push('occurred_at = ?');
    params.push(toUnixSeconds(input.occurredAt));
  }

  if (input.merchant !== undefined) {
    setClauses.push('merchant = ?');
    params.push(input.merchant?.trim() || null);
  }

  if (input.note !== undefined) {
    setClauses.push('note = ?');
    params.push(input.note?.trim() || null);
  }

  const now = Math.floor(Date.now() / 1000);
  setClauses.push('updated_at = ?');
  params.push(now);

  params.push(id);

  const sql = `UPDATE transactions SET ${setClauses.join(', ')} WHERE id = ?`;
  await db.execute(sql, params);
}

export async function softDeleteMovement(db: DBExecutable, id: string): Promise<void> {
  await checkLoanMovement(db, id);

  const now = Math.floor(Date.now() / 1000);
  const sql = 'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE id = ?';
  await db.execute(sql, [now, now, id]);
}

export async function restoreMovement(db: DBExecutable, id: string): Promise<void> {
  const now = Math.floor(Date.now() / 1000);
  const sql = 'UPDATE transactions SET deleted_at = NULL, updated_at = ? WHERE id = ?';
  await db.execute(sql, [now, id]);
}

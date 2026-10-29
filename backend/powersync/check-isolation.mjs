import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const supabase = process.env.SUPABASE_URL || 'http://localhost:55321';
const powersync = process.env.POWERSYNC_URL || 'http://localhost:18081';
for (const url of [supabase, powersync]) {
  assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(new URL(url).hostname), 'Este chequeo solo admite servicios locales.');
}
const anon = process.env.SUPABASE_ANON_KEY;
const admin = process.env.SUPABASE_SERVICE_ROLE_KEY;
const run = randomUUID();
const password = randomUUID() + randomUUID();
const now = Math.floor(Date.now() / 1000);
const tables = ['transactions', 'categories', 'loans', 'loan_installments', 'goals', 'goal_contributions', 'budgets', 'recurring_rules', 'income_schedules', 'salary_deductions', 'events', 'settings'];
const users = [];

function fixture(table, label, suffix) {
  const marker = `${label}-${run}`;
  const amount = label === 'A' ? 184000 : 92000;
  const id = `isolation-${run}-${suffix}`;
  const fields = {
    transactions: { type: 'expense', amount, category_id: 'no-parent', note: marker, occurred_at: now, created_at: now, source: 'manual' },
    categories: { name: marker, icon: 'test', color_dark: 4294967295, color_light: 4294967295, kind: 'expense', sort_order: 0 },
    loans: { direction: 'owe', kind: 'loan', name: marker, total_amount: amount, start_date: now, created_at: now },
    loan_installments: { id: `${id}:1`, loan_id: id, number: 1, due_date: now, amount },
    goals: { name: marker, icon: 'test', target_amount: amount, created_at: now },
    goal_contributions: { goal_id: 'no-parent', amount, date: now, note: marker, created_at: now },
    budgets: { category_id: marker, monthly_limit: amount },
    recurring_rules: { name: marker, type: 'expense', amount, category_id: 'no-parent', frequency: 'monthly', next_due_date: now },
    income_schedules: { mode: marker, pay_days: '[1]', pay_day_rules: '[]', pay_split_percents: '[100]', category_id: 'no-parent', effective_from: now },
    salary_deductions: { schedule_id: 'no-parent', name: marker, kind: 'fixed', value: amount },
    events: { name: marker, icon: 'test', start_date: now, created_at: now },
    settings: { key: id, value: marker },
  };
  return { id, updated_at: now, ...fields[table] };
}

async function api(path, key, token, method = 'GET', body) {
  const response = await fetch(`${supabase}${path}`, {
    method,
    headers: { apikey: key, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`${method} ${path}: HTTP ${response.status}: ${await response.text()}`);
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

async function createUser(label) {
  const email = `isolation-${run}-${label.toLowerCase()}@test.local`;
  const user = await api('/auth/v1/admin/users', admin, admin, 'POST', { email, password, email_confirm: true });
  // Registrar antes del login para limpiar incluso si este falla.
  const item = { label, id: user.id, token: null, rows: new Map() };
  users.push(item);
  const session = await api('/auth/v1/token?grant_type=password', anon, anon, 'POST', { email, password });
  item.token = session.access_token;
  return item;
}

async function seed(user) {
  for (const table of tables) {
    // Un id privado y otro igual entre A/B: prueba aislamiento aun con colisiones.
    const rows = [fixture(table, user.label, user.label), fixture(table, user.label, 'shared')];
    user.rows.set(table, rows);
    await api(`/rest/v1/${table}`, anon, user.token, 'POST', rows);
  }
}

async function receive(user) {
  const received = new Map(tables.map(table => [table, new Map()]));
  const response = await fetch(`${powersync}/sync/stream`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${user.token}`, 'Content-Type': 'application/json', Accept: 'application/x-ndjson' },
    body: JSON.stringify({ buckets: [], include_checksum: true, raw_data: true }),
    signal: AbortSignal.timeout(30000),
  });
  assert.equal(response.status, 200, `PowerSync ${user.label}: HTTP ${response.status}`);
  let buffer = '';
  const decoder = new TextDecoder();
  for await (const chunk of response.body) {
    buffer += decoder.decode(chunk, { stream: true });
    let end;
    while ((end = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, end).trim();
      buffer = buffer.slice(end + 1);
      if (!line) continue;
      const event = JSON.parse(line);
      if (event.error) throw new Error(`PowerSync: ${JSON.stringify(event.error)}`);
      if (event.data) {
        for (const entry of event.data.data) {
          if (entry.op !== 'PUT') continue;
          const table = entry.object_type;
          assert.ok(tables.includes(table), `Tabla inesperada: ${table}`);
          const data = typeof entry.data === 'string' ? JSON.parse(entry.data) : entry.data;
          assert.ok(data && !Object.hasOwn(data, 'user_id'), `${table}: user_id no debe bajar al cliente`);
          const row = { ...data, id: entry.object_id };
          const expected = user.rows.get(table).find(item => item.id === row.id);
          assert.ok(expected, `${user.label} recibió una fila ajena de ${table}`);
          for (const [key, value] of Object.entries(expected)) {
            assert.deepEqual(row[key], value, `${user.label}: ${table}.${key}, valores ajenos o alterados`);
          }
          received.get(table).set(row.id, row);
        }
      }
      // Un checkpoint completo evita aprobar con un stream vacío/incompleto.
      if (event.checkpoint_complete && tables.every(table => received.get(table).size === 2)) {
        for (const table of tables) console.log(`PASS: ${user.label} ${table}: 2 propias, 0 ajenas, sin user_id`);
        return;
      }
    }
  }
  throw new Error(`${user.label}: stream terminó sin un checkpoint completo con las 12 tablas`);
}

async function cleanup() {
  const errors = [];
  for (const user of users) {
    for (const [table, rows] of user.rows) {
      if (!user.token) continue;
      for (const row of rows) {
        try { await api(`/rest/v1/${table}?id=eq.${encodeURIComponent(row.id)}`, anon, user.token, 'DELETE'); }
        catch (error) { errors.push(error.message); }
      }
    }
    try { await api(`/auth/v1/admin/users/${user.id}`, admin, admin, 'DELETE'); }
    catch (error) { errors.push(error.message); }
  }
  assert.equal(errors.length, 0, `Falló limpieza de fixtures: ${errors.join('; ')}`);
}

try {
  const health = await fetch(`${powersync}/probes/liveness`, { signal: AbortSignal.timeout(5000) });
  assert.ok(health.ok, `PowerSync liveness: HTTP ${health.status}`);
  assert.ok(anon && admin, 'Completar llaves exclusivamente locales en backend/powersync/.env');
  try {
    const a = await createUser('A');
    const b = await createUser('B');
    await seed(a);
    await seed(b);
    // B se inserta al final: su checkpoint con todas las filas implica que
    // también se replicaron las filas anteriores de A. Luego verificar A.
    await receive(b);
    await receive(a);
    console.log('PASS: aislamiento bidireccional en 12 tablas; ids compartidos con valores propios');
  } finally { await cleanup(); }
  console.log('PASS: filas y usuarios de prueba eliminados');
} catch (error) {
  console.error(`FAIL: ${error.message}`);
  process.exitCode = 1;
}

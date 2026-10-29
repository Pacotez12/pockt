import { useEffect, useState, type FormEvent } from 'react';
import type { Session } from '@supabase/supabase-js';
import { PowerSyncDatabase } from '@powersync/web';
import { PowerSyncContext, usePowerSync, useQuery, useStatus } from '@powersync/react';
import { configError, connectorFor, supabase } from './backend';
import { AppSchema, type SpikeTx } from './schema';
import { formatGs } from './format';

const message = (error: unknown) => error instanceof Error ? error.message : String(error);

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
      setLoading(false);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  return <main>
    <header><span className="brand">pockt<span>.</span></span><span className="badge">Prueba local · 0.4</span></header>
    <h1>Movimientos en vivo</h1>
    <p className="intro">Una prueba de sincronización con datos inventados.</p>
    {configError ? <p role="alert">Completá las tres variables de .env y reiniciá Vite.</p>
      : loading ? <p role="status">Cargando sesión…</p>
      : session ? <UserDatabase key={session.user.id} session={session} /> : <Login />}
  </main>;
}

function Login() {
  const [email, setEmail] = useState('a@test.local');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  async function login(event: FormEvent) {
    event.preventDefault();
    setBusy(true); setError('');
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) throw error;
    } catch (error) { setError(message(error)); }
    finally { setBusy(false); }
  }
  return <section className="panel login">
    <h2>Entrar a la prueba</h2>
    <p>Usá a@test.local o b@test.local y la contraseña inventada del entorno local.</p>
    <form onSubmit={login}>
      <label htmlFor="email">Email</label>
      <input id="email" type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} required />
      <label htmlFor="password">Contraseña de prueba</label>
      <input id="password" type="password" autoComplete="current-password" value={password} onChange={e => setPassword(e.target.value)} required />
      {error && <p role="alert">{error}</p>}
      <button disabled={busy} type="submit">{busy ? 'Entrando…' : 'Entrar'}</button>
    </form>
  </section>;
}

function UserDatabase({ session }: { session: Session }) {
  const [database] = useState(() => new PowerSyncDatabase({
    schema: AppSchema,
    database: { dbFilename: `pockt-spike-${session.user.id}.db` },
  }));
  const [error, setError] = useState('');
  useEffect(() => {
    let active = true;
    database.connect(connectorFor(session.user.id)).catch(error => {
      if (active) setError(message(error));
    });
    return () => {
      active = false;
      void database.close().catch(console.error);
    };
  }, [database, session.user.id]);
  return <PowerSyncContext.Provider value={database}>
    {error && <p role="alert">{error}</p>}
    <Movements session={session} />
  </PowerSyncContext.Provider>;
}

function Movements({ session }: { session: Session }) {
  const db = usePowerSync();
  const status = useStatus();
  const { data, isLoading, error: queryError } = useQuery<SpikeTx>(
    'SELECT * FROM spike_tx WHERE user_id = ? AND deleted_at IS NULL ORDER BY occurred_at DESC, id DESC',
    [session.user.id],
  );
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);
  async function insert() {
    setBusy(true); setError('');
    try {
      const now = Math.floor(Date.now() / 1000);
      await db.execute(
        'INSERT INTO spike_tx (id, user_id, amount, note, occurred_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
        [crypto.randomUUID(), session.user.id, 184000, 'Prueba desde la web', now, now],
      );
    } catch (error) { setError(message(error)); }
    finally { setBusy(false); }
  }
  async function logout() {
    setBusy(true); setError('');
    try {
      await db.disconnect();
      const { error } = await supabase.auth.signOut({ scope: 'local' });
      if (error) throw error;
    } catch (error) { setError(message(error)); setBusy(false); }
  }
  const syncError = status.dataFlowStatus.uploadError || status.dataFlowStatus.downloadError;
  return <section className="panel">
    <div className="toolbar">
      <div><strong>{session.user.email}</strong><p role="status">{
        status.connected ? status.dataFlowStatus.uploading ? 'Subiendo cambios…' : status.hasSynced ? 'Sincronizado' : 'Sincronizando…'
          : status.connecting ? 'Conectando…' : 'Sin conexión · cambios guardados localmente'
      }</p></div>
      <button className="secondary" disabled={busy} onClick={logout}>Cerrar sesión</button>
    </div>
    <div className="toolbar"><h2>Movimientos <span className="count">{data.length}</span></h2>
      <button onClick={insert} disabled={busy || isLoading}>{busy ? 'Guardando…' : '+ Insertar Gs. 184.000'}</button></div>
    {(error || queryError || syncError) && <p role="alert">{error || message(queryError || syncError)}</p>}
    {isLoading ? <p role="status">Cargando movimientos…</p> : data.length === 0 ? <p className="empty">Todavía no hay movimientos. Insertá una fila de prueba.</p>
      : <ul className="movements">{data.map(row => <li key={row.id}>
        <div><strong>{row.note || 'Sin nota'}</strong><p>{new Date((row.occurred_at ?? 0) * 1000).toLocaleString('es-PY')}</p><code>{row.id}</code></div>
        <span className="amount">{formatGs(row.amount ?? 0)}</span>
      </li>)}</ul>}
    <p className="hint">Los cambios de tu cuenta llegan en vivo. Cada inserción usa un UUID y fechas en segundos Unix.</p>
  </section>;
}

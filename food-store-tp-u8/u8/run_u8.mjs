// Runner de evidencias U8: PostgreSQL de pruebas + SQLite de la tablet.
// No escribe en railway ni en foodstore. Solo usa foodstore_u8_lab.
import pg from 'pg';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SQL = path.join(ROOT, 'sql', 'u8');
const OUT = path.join(HERE, 'resultados');
const SNAPS = path.join(HERE, 'snapshots');
const DB = path.join(HERE, 'tablet_u8.db');
const CSV = path.join(HERE, 'servidor_snapshot.csv');
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(SNAPS, { recursive: true });
for (const f of [DB, DB + '-wal', DB + '-shm']) fs.rmSync(f, { force: true });

const LAB = process.env.U8_DATABASE_URL;
if (!LAB) throw new Error('Definir U8_DATABASE_URL con la URL de foodstore_u8_lab (no se guarda en el archivo).');
const logFile = path.join(OUT, 'evidencia_u8.txt');
let log = '';
function w(s = '') { log += s + '\n'; }
function section(t) { w('\n' + '='.repeat(78)); w(t); w('='.repeat(78)); }

const client = new pg.Client({ connectionString: LAB, ssl: { rejectUnauthorized: false } });
await client.connect();
await client.query("SET TIME ZONE 'America/Argentina/Buenos_Aires'");

async function pgRows(sql) { return (await client.query(sql)).rows; }
async function pgExec(sql) { await client.query(sql); }

function csvCell(v) {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return /[",\n\r]/.test(s) ? '"' + s.replaceAll('"', '""') + '"' : s;
}
async function exportSnapshot(dest) {
  const rows = await pgRows(`
    SELECT producto_id, nombre, precio_centavos, stock,
           CASE WHEN disponible THEN 't' ELSE 'f' END AS disponible,
           CASE WHEN eliminado  THEN 't' ELSE 'f' END AS eliminado,
           fecha_copia::text AS fecha_copia
    FROM v_snapshot_movil
    ORDER BY producto_id`);
  const header = 'producto_id,nombre,precio_centavos,stock,disponible,eliminado,fecha_copia';
  const body = rows.map(r => [r.producto_id, r.nombre, r.precio_centavos, r.stock,
    r.disponible, r.eliminado, r.fecha_copia].map(csvCell).join(','));
  fs.writeFileSync(dest, [header, ...body].join('\n') + '\n', 'utf8');
  return rows.length;
}
function importSnapshot(csv) {
  runSqliteCmd('DELETE FROM snapshot_servidor;');
  const r = spawnSync('sqlite3', [DB, `.import --csv --skip 1 "${csv}" snapshot_servidor`], { encoding: 'utf8' });
  w(`$ sqlite3 tablet_u8.db ".import --csv --skip 1 ${path.basename(csv)} snapshot_servidor"`);
  if (r.stdout) w(r.stdout.trim());
  if (r.stderr) w(r.stderr.trim());
  if (r.status !== 0) throw new Error('import falló: ' + r.stderr);
}
function runSql(name) {
  const sql = fs.readFileSync(path.join(SQL, name), 'utf8');
  const r = spawnSync('sqlite3', [DB], { input: sql, encoding: 'utf8' });
  w(`$ sqlite3 tablet_u8.db < sql/u8/${name}`);
  if (r.stdout) w(r.stdout.trim());
  if (r.stderr) w(r.stderr.trim());
  return r;
}
function runSqliteCmd(cmd) {
  const r = spawnSync('sqlite3', [DB, cmd], { encoding: 'utf8' });
  if (r.stdout) w(r.stdout.trim());
  if (r.stderr) w(r.stderr.trim());
  if (r.status !== 0) throw new Error('sqlite cmd falló: ' + r.stderr);
}
async function estado(titulo) {
  const r = spawnSync('sqlite3', ['-header', '-column', DB,
    "SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY estado, solicitud_uuid;"], { encoding: 'utf8' });
  w(`\n[${titulo}] cola_sync:`);
  w(r.stdout.trim());
}

section('U8 - Evidencia de ejecución');
w(`Fecha de ejecución: ${new Date().toISOString()}`);
w('PostgreSQL de pruebas: foodstore_u8_lab (Railway)');
w('Tablet: SQLite ' + spawnSync('sqlite3', ['--version'], { encoding: 'utf8' }).stdout.trim());
w('La tablet no ejecuta INSERT/UPDATE sobre PostgreSQL.');

// Baseline PostgreSQL
section('0. Baseline PostgreSQL ANTES de las simulaciones');
const antes = (await pgRows(`
  SELECT (SELECT count(*) FROM pedido) AS pedidos,
         (SELECT count(*) FROM detalle_pedido) AS detalles,
         (SELECT sum(stock) FROM producto) AS stock_total,
         (SELECT md5(string_agg(id::text || '|' || fecha::text || '|' || forma_pago::text || '|' || cliente_id::text, ';' ORDER BY id)) FROM pedido) AS md5_pedidos,
         (SELECT md5(string_agg(id::text || '|' || cantidad::text || '|' || precio_unitario::text || '|' || pedido_id::text || '|' || producto_id::text, ';' ORDER BY id)) FROM detalle_pedido) AS md5_detalles`))[0];
w(JSON.stringify(antes, null, 2));

// S0 + SQLite inicial
section('1. Instantánea inicial S0 y creación de la tablet');
w(`Filas exportadas: ${await exportSnapshot(CSV)} -> u8/servidor_snapshot.csv`);
w('CSV (primeras líneas):');
w(fs.readFileSync(CSV, 'utf8').split('\n').slice(0, 4).join('\n'));

runSqliteCmd('PRAGMA foreign_keys=ON;');
runSql('schema_sqlite.sql');
importSnapshot(CSV);
runSql('carga_snapshot.sql');

section('2. Pruebas 1.c: borrador, ROLLBACK, C1 y C7');
runSql('pruebas_sqlite.sql');
runSql('semaforo.sql');
await estado('tras C5');

// C2: precio sube en servidor
section('3. Caso C2: precio del servidor sube');
await pgExec('UPDATE producto SET precio = 1100.00 WHERE id = 1;');
const c2csv = path.join(SNAPS, 'caso_c2.csv');
w(`Filas exportadas: ${await exportSnapshot(c2csv)} -> u8/snapshots/caso_c2.csv`);
importSnapshot(c2csv);
runSql('carga_snapshot.sql');
runSql('caso_c2a.sql');
runSql('semaforo.sql');
await estado('C2 con precio viejo');
runSql('caso_c2b.sql');
runSql('semaforo.sql');
await estado('C2 precio aceptado');

// C3: stock baja
section('4. Caso C3: stock insuficiente');
await pgExec('UPDATE producto SET stock = 2 WHERE id = 3;');
const c3csv = path.join(SNAPS, 'caso_c3.csv');
w(`Filas exportadas: ${await exportSnapshot(c3csv)} -> u8/snapshots/caso_c3.csv`);
importSnapshot(c3csv);
runSql('carga_snapshot.sql');
runSql('caso_c3.sql');
runSql('semaforo.sql');
await estado('C3');

// La instantánea de C3 ya quedó en la tablet con stock 2. Se restaura el
// stock del servidor para que el control final vuelva al baseline; el
// cambio fue un fixture del servidor, no una escritura de la tablet.
await pgExec('UPDATE producto SET stock = 100 WHERE id = 3;');

// C4: baja lógica
section('5. Caso C4: producto dado de baja');
await pgExec('UPDATE producto SET activo = false WHERE id = 2;');
const c4csv = path.join(SNAPS, 'caso_c4.csv');
w(`Filas exportadas: ${await exportSnapshot(c4csv)} -> u8/snapshots/caso_c4.csv`);
importSnapshot(c4csv);
runSql('carga_snapshot.sql');
runSql('caso_c4.sql');
runSql('semaforo.sql');
await estado('C4');
runSql('consulta_c4.sql');

// C6: reenvío
section('6. Caso C6: reenvío del mismo UUID');
runSql('caso_c6.sql');
runSql('semaforo.sql');
await estado('C6');

// Cierre
section('7. PostgreSQL DESPUÉS: pedidos y stock');
const despues = (await pgRows(`
  SELECT (SELECT count(*) FROM pedido) AS pedidos,
         (SELECT count(*) FROM detalle_pedido) AS detalles,
         (SELECT sum(stock) FROM producto) AS stock_total,
         (SELECT md5(string_agg(id::text || '|' || fecha::text || '|' || forma_pago::text || '|' || cliente_id::text, ';' ORDER BY id)) FROM pedido) AS md5_pedidos,
         (SELECT md5(string_agg(id::text || '|' || cantidad::text || '|' || precio_unitario::text || '|' || pedido_id::text || '|' || producto_id::text, ';' ORDER BY id)) FROM detalle_pedido) AS md5_detalles`))[0];
w(JSON.stringify(despues, null, 2));
w('\nComparación:');
w(JSON.stringify({
  pedidos_iguales: antes.pedidos === despues.pedidos,
  detalles_iguales: antes.detalles === despues.detalles,
  stock_igual: antes.stock_total === despues.stock_total,
  md5_pedidos_igual: antes.md5_pedidos === despues.md5_pedidos,
  md5_detalles_igual: antes.md5_detalles === despues.md5_detalles
}, null, 2));

section('8. Resumen final de la cola');
const r = spawnSync('sqlite3', ['-header', '-column', DB,
  "SELECT estado, count(*) AS solicitudes FROM cola_sync GROUP BY estado ORDER BY estado;"], { encoding: 'utf8' });
w(r.stdout.trim());

await client.end();
fs.writeFileSync(logFile, log, 'utf8');
console.log('Evidencia escrita en', logFile);

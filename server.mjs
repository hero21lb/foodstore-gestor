import express from "express";
import { Pool } from "pg";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { webcrypto } from "node:crypto";
import initSqlJs from "sql.js";

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const app = express();
const here = path.dirname(fileURLToPath(import.meta.url));
const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 10 });
const U8 = path.join(here, "food-store-tp-u8");
const U6 = path.join(here, "food-store-tp-u6");
const U7 = path.join(here, "food-store-tp-u7");

app.use(express.json());
app.use(express.static(path.join(here, "public")));

const asyncRoute = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
const required = (value, label) => {
  if (value === undefined || value === null || String(value).trim() === "") {
    const error = new Error(`${label} es obligatorio`);
    error.status = 400;
    throw error;
  }
  return value;
};
const number = (value, label, min = 0) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min) {
    const error = new Error(`${label} debe ser un número válido`);
    error.status = 400;
    throw error;
  }
  return parsed;
};
const readText = (file) => fs.readFileSync(file, "utf8");
const readJson = (file) => JSON.parse(readText(file));
const timed = async (fn) => {
  const start = performance.now();
  const value = await fn();
  return { value, ms: Number((performance.now() - start).toFixed(2)) };
};
const planNodes = (plan, acc = []) => {
  acc.push(plan["Node Type"]);
  for (const child of plan.Plans || []) planNodes(child, acc);
  return acc;
};

// ---------------------------------------------------------------- app base

app.get("/api/health", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query("SELECT current_database() AS database, version() AS version");
  res.json({ ok: true, database: rows[0].database, version: rows[0].version });
}));

app.get("/api/dashboard", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`
    SELECT
      (SELECT count(*) FROM producto WHERE activo) AS productos_activos,
      (SELECT count(*) FROM categoria WHERE activo) AS categorias_activas,
      (SELECT count(*) FROM cliente) AS clientes,
      (SELECT count(*) FROM pedido) AS pedidos,
      (SELECT COALESCE(sum(total_facturado), 0) FROM mv_facturacion_categoria_mes) AS facturacion
  `);
  res.json(rows[0]);
}));

app.get("/api/categories", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`
    SELECT c.id, c.nombre, c.descripcion, c.activo, count(p.id)::int AS productos
    FROM categoria c
    LEFT JOIN producto p ON p.categoria_id = c.id AND p.activo = true
    GROUP BY c.id
    ORDER BY c.activo DESC, c.nombre
  `);
  res.json(rows);
}));

app.post("/api/categories", asyncRoute(async (req, res) => {
  const nombre = required(req.body.nombre, "El nombre");
  const descripcion = req.body.descripcion?.trim() || null;
  const { rows } = await pool.query(
    "INSERT INTO categoria (nombre, descripcion) VALUES ($1, $2) RETURNING *",
    [nombre.trim(), descripcion],
  );
  res.status(201).json(rows[0]);
}));

app.patch("/api/categories/:id", asyncRoute(async (req, res) => {
  const id = number(req.params.id, "El id", 1);
  const { nombre, descripcion, activo } = req.body;
  const { rows } = await pool.query(`
    UPDATE categoria
    SET nombre = COALESCE($2, nombre),
        descripcion = COALESCE($3, descripcion),
        activo = COALESCE($4, activo)
    WHERE id = $1
    RETURNING *
  `, [id, nombre?.trim() || null, descripcion?.trim() || null, typeof activo === "boolean" ? activo : null]);
  if (!rows[0]) return res.status(404).json({ error: "Categoría no encontrada" });
  res.json(rows[0]);
}));

app.get("/api/products", asyncRoute(async (req, res) => {
  const search = String(req.query.search || "").trim();
  const categoryId = req.query.category ? number(req.query.category, "La categoría", 1) : null;
  const showInactive = req.query.all === "true";
  const { rows } = await pool.query(`
    SELECT p.id, p.nombre, p.descripcion, p.precio, p.stock, p.activo,
           c.id AS categoria_id, c.nombre AS categoria
    FROM producto p
    JOIN categoria c ON c.id = p.categoria_id
    WHERE ($1::text = '' OR p.nombre ILIKE '%' || $1 || '%')
      AND ($2::bigint IS NULL OR p.categoria_id = $2)
      AND ($3::boolean = true OR p.activo = true)
    ORDER BY p.activo DESC, p.nombre
    LIMIT 250
  `, [search, categoryId, showInactive]);
  res.json(rows);
}));

app.post("/api/products", asyncRoute(async (req, res) => {
  const nombre = required(req.body.nombre, "El nombre");
  const precio = number(req.body.precio, "El precio");
  const stock = number(req.body.stock, "El stock");
  const categoriaId = number(req.body.categoria_id, "La categoría", 1);
  const { rows } = await pool.query(`
    INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *
  `, [nombre.trim(), req.body.descripcion?.trim() || null, precio, stock, categoriaId]);
  res.status(201).json(rows[0]);
}));

app.patch("/api/products/:id", asyncRoute(async (req, res) => {
  const id = number(req.params.id, "El id", 1);
  const payload = req.body;
  const { rows } = await pool.query(`
    UPDATE producto
    SET nombre = COALESCE($2, nombre),
        descripcion = COALESCE($3, descripcion),
        precio = COALESCE($4, precio),
        stock = COALESCE($5, stock),
        categoria_id = COALESCE($6, categoria_id),
        activo = COALESCE($7, activo)
    WHERE id = $1
    RETURNING *
  `, [
    id,
    payload.nombre?.trim() || null,
    payload.descripcion?.trim() || null,
    payload.precio === undefined ? null : number(payload.precio, "El precio"),
    payload.stock === undefined ? null : number(payload.stock, "El stock"),
    payload.categoria_id === undefined ? null : number(payload.categoria_id, "La categoría", 1),
    typeof payload.activo === "boolean" ? payload.activo : null,
  ]);
  if (!rows[0]) return res.status(404).json({ error: "Producto no encontrado" });
  res.json(rows[0]);
}));

app.get("/api/orders", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`
    SELECT p.pedido_id, p.fecha, p.forma_pago,
           p.nombre || ' ' || p.apellido AS cliente,
           COALESCE(sum(d.subtotal), 0)::numeric(14,2) AS total,
           COALESCE(sum(d.cantidad), 0)::int AS unidades
    FROM vw_pedidos_cliente p
    LEFT JOIN vw_detalle_pedido d ON d.pedido_id = p.pedido_id
    GROUP BY p.pedido_id, p.fecha, p.forma_pago, p.nombre, p.apellido
    ORDER BY p.fecha DESC
    LIMIT 100
  `);
  res.json(rows);
}));

// ---------------------------------------------------------------- laboratorio

app.get("/api/lab/overview", asyncRoute(async (_req, res) => {
  const [db, u4, roles] = await Promise.all([
    pool.query(`SELECT current_database() AS database, version() AS version,
      (SELECT count(*) FROM producto)::int AS productos,
      (SELECT count(*) FROM cliente)::int AS clientes,
      (SELECT count(*) FROM pedido)::int AS pedidos,
      (SELECT count(*) FROM detalle_pedido)::int AS detalles`),
    pool.query("SELECT to_regclass('tp_u4.control_lote_almacen') IS NOT NULL AS ok"),
    pool.query("SELECT count(*)::int AS n FROM pg_roles WHERE rolname IN ('app_web','admin_datos','rol_app_lectura')"),
  ]);
  res.json({
    ...db.rows[0],
    u4: u4.rows[0].ok,
    roles: roles.rows[0].n,
    mongo: Boolean(process.env.MONGO_URL),
    u8: fs.existsSync(path.join(U8, "u8", "tablet_u8.db")),
  });
}));

// U1 - restricciones y concurrencia -----------------------------------------

async function testSql(sql) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SAVEPOINT lab");
    try {
      const result = await client.query(sql);
      await client.query("ROLLBACK TO SAVEPOINT lab");
      return { ok: true, rows: result.rows.slice(0, 3), rowCount: result.rowCount };
    } catch (error) {
      await client.query("ROLLBACK TO SAVEPOINT lab").catch(() => {});
      return { ok: false, code: error.code, message: error.message };
    }
  } finally {
    await client.query("ROLLBACK").catch(() => {});
    client.release();
  }
}

app.get("/api/lab/u1/restricciones", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query("SELECT min(id) AS producto, (SELECT min(id) FROM pedido) AS pedido, (SELECT min(id) FROM cliente) AS cliente FROM producto");
  const { producto, pedido, cliente } = rows[0];
  const precio = (await pool.query("SELECT precio FROM producto WHERE id = $1", [producto])).rows[0].precio;
  const dup = (await pool.query("SELECT pedido_id, producto_id FROM detalle_pedido LIMIT 1")).rows[0];
  const tests = [
    ["Pedido válido", `INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES (now(), 'EFECTIVO', ${cliente}) RETURNING id`],
    ["Pedido con fecha futura", `INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES ('2030-01-01', 'EFECTIVO', ${cliente})`],
    ["Detalle válido", `INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (2, ${precio}, ${pedido}, ${producto}) RETURNING id`],
    ["Cantidad 0", `INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (0, ${precio}, ${pedido}, ${producto})`],
    ["Cantidad 50", `INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (50, ${precio}, ${pedido}, ${producto})`],
    ["Precio > 1,5x", `INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (1, ${Number(precio) * 2}, ${pedido}, ${producto})`],
    ["Mail duplicado", `INSERT INTO cliente (nombre, apellido, mail) VALUES ('Test', 'Duplicado', (SELECT mail FROM cliente LIMIT 1))`],
    ["FK de categoría inexistente", `INSERT INTO producto (nombre, precio, stock, categoria_id) VALUES ('Producto X', 1, 1, 999999)`],
    ["Detalle duplicado", `INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES (1, ${precio}, ${dup.pedido_id}, ${dup.producto_id})`],
    ["Baja lógica", `UPDATE producto SET activo = false WHERE id = ${producto} RETURNING id`],
  ];
  const results = [];
  for (const [name, sql] of tests) results.push({ name, ...(await testSql(sql)) });
  res.json({ producto, pedido, cliente, results });
}));

app.get("/api/lab/u1/concurrencia", asyncRoute(async (_req, res) => {
  const a = await pool.connect();
  const b = await pool.connect();
  const log = [];
  try {
    await a.query("BEGIN");
    const row = await a.query("SELECT id FROM producto ORDER BY id LIMIT 1 FOR UPDATE");
    log.push({ paso: "A bloquea la fila", ok: true, id: row.rows[0].id });
    await b.query("BEGIN");
    await b.query("SET LOCAL lock_timeout = '800ms'");
    const start = performance.now();
    try {
      await b.query("SELECT id FROM producto ORDER BY id LIMIT 1 FOR UPDATE");
      log.push({ paso: "B obtiene el lock", ok: true, ms: Number((performance.now() - start).toFixed(2)) });
    } catch (error) {
      log.push({
        paso: "B queda esperando y vence el lock_timeout",
        ok: false,
        code: error.code,
        message: error.message,
        ms: Number((performance.now() - start).toFixed(2)),
      });
    }
    await b.query("ROLLBACK");
    await a.query("ROLLBACK");
    log.push({ paso: "Ambas transacciones revierten", ok: true });
  } finally {
    a.release();
    b.release();
  }
  res.json({ log, nota: "FOR UPDATE bloquea la fila; B no puede leerla con lock exclusivo hasta el COMMIT/ROLLBACK de A." });
}));

// U2 - consultas y planes ----------------------------------------------------

const queries = {
  clientes: `SELECT c.id, c.nombre, c.apellido,
      SUM(d.cantidad * d.precio_unitario)::numeric(14,2) AS total
    FROM cliente c
    JOIN pedido p ON p.cliente_id = c.id
    JOIN detalle_pedido d ON d.pedido_id = p.id
    GROUP BY c.id, c.nombre, c.apellido
    ORDER BY total DESC
    LIMIT 10`,
  productos: `SELECT p.id, p.nombre, SUM(d.cantidad)::int AS unidades
    FROM producto p
    JOIN detalle_pedido d ON d.producto_id = p.id
    WHERE p.activo = TRUE
    GROUP BY p.id, p.nombre
    ORDER BY unidades DESC
    LIMIT 10`,
  ranking: `WITH ventas AS (
      SELECT c.id AS categoria_id, c.nombre AS categoria,
             p.id AS producto_id, p.nombre AS producto,
             SUM(d.cantidad)::int AS unidades
      FROM categoria c
      JOIN producto p ON p.categoria_id = c.id
      JOIN detalle_pedido d ON d.producto_id = p.id
      WHERE c.activo = TRUE AND p.activo = TRUE
      GROUP BY c.id, c.nombre, p.id, p.nombre
    )
    SELECT categoria, producto, unidades,
           DENSE_RANK() OVER (PARTITION BY categoria_id ORDER BY unidades DESC) AS puesto
    FROM ventas
    ORDER BY categoria, puesto, producto
    LIMIT 15`,
};

app.get("/api/lab/u2/consultas", asyncRoute(async (_req, res) => {
  const out = {};
  for (const [name, sql] of Object.entries(queries)) {
    const { value, ms } = await timed(() => pool.query(sql));
    out[name] = { ms, rows: value.rows.slice(0, 10) };
  }
  res.json(out);
}));

app.get("/api/lab/u2/explain", asyncRoute(async (_req, res) => {
  const { value, ms } = await timed(() => pool.query(`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${queries.productos}`));
  const plan = value.rows[0]["QUERY PLAN"][0];
  res.json({
    ms,
    node: plan.Plan["Node Type"],
    executionTime: plan["Execution Time"],
    planningTime: plan["Planning Time"],
    rows: plan.Plan["Actual Rows"],
    plan: plan.Plan,
  });
}));

// U3 - vistas y materializada ------------------------------------------------

app.get("/api/lab/u3/vistas", asyncRoute(async (_req, res) => {
  const counts = await pool.query(`
    SELECT 'vw_productos_vigentes' AS objeto, count(*)::int AS filas FROM vw_productos_vigentes
    UNION ALL SELECT 'vw_pedidos_cliente', count(*)::int FROM vw_pedidos_cliente
    UNION ALL SELECT 'vw_detalle_pedido', count(*)::int FROM vw_detalle_pedido
    UNION ALL SELECT 'mv_facturacion_categoria_mes', count(*)::int FROM mv_facturacion_categoria_mes
  `);
  const sample = await pool.query("SELECT * FROM vw_productos_vigentes ORDER BY producto LIMIT 5");
  const mv = await pool.query("SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes, categoria_id LIMIT 5");
  res.json({ counts: counts.rows, productos: sample.rows, facturacion: mv.rows });
}));

app.post("/api/lab/u3/refresh", asyncRoute(async (_req, res) => {
  const { ms } = await timed(() => pool.query("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes"));
  const { rows } = await pool.query("SELECT count(*)::int AS filas FROM mv_facturacion_categoria_mes");
  res.json({ ok: true, ms, filas: rows[0].filas });
}));

// U4 - FNBC y desnormalización ----------------------------------------------

app.get("/api/lab/u4/estado", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query("SELECT to_regclass('tp_u4.control_lote_almacen') IS NOT NULL AS instalado");
  res.json({ instalado: rows[0].instalado });
}));

app.get("/api/lab/u4/fnbc", asyncRoute(async (_req, res) => {
  const view = await pool.query("SELECT * FROM tp_u4.vw_control_lote_almacen ORDER BY lote_id");
  const diff = await pool.query(`
    SELECT count(*)::int AS diferencias FROM (
      (SELECT * FROM tp_u4.control_lote_almacen_original
       EXCEPT ALL SELECT * FROM tp_u4.vw_control_lote_almacen)
      UNION ALL
      (SELECT * FROM tp_u4.vw_control_lote_almacen
       EXCEPT ALL SELECT * FROM tp_u4.control_lote_almacen_original)
    ) x
  `);
  res.json({ filas: view.rows, diferencias: diff.rows[0].diferencias });
}));

app.get("/api/lab/u4/top", asyncRoute(async (_req, res) => {
  const day = (await pool.query("SELECT max(fecha_venta_u4)::text AS d FROM detalle_pedido")).rows[0].d;
  const normalSql = `
    SELECT c.id AS categoria_id, c.nombre AS categoria,
           SUM(dp.cantidad * dp.precio_unitario)::numeric(14,2) AS total
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    JOIN pedido ped ON ped.id = dp.pedido_id
    WHERE (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date = $1
    GROUP BY c.id, c.nombre
    ORDER BY total DESC, c.id
    LIMIT 5`;
  const denormSql = `
    SELECT categoria_id_u4 AS categoria_id, categoria_nombre_u4 AS categoria,
           SUM(subtotal_u4)::numeric(14,2) AS total
    FROM detalle_pedido
    WHERE fecha_venta_u4 = $1
    GROUP BY categoria_id_u4, categoria_nombre_u4
    ORDER BY total DESC, categoria_id_u4
    LIMIT 5`;
  const normal = await timed(() => pool.query(normalSql, [day]));
  const denorm = await timed(() => pool.query(denormSql, [day]));
  const normalPlan = await pool.query(`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${normalSql}`, [day]);
  const denormPlan = await pool.query(`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${denormSql}`, [day]);
  res.json({
    dia: day,
    normal: { ms: normal.ms, rows: normal.value.rows, node: normalPlan.rows[0]["QUERY PLAN"][0].Plan["Node Type"], nodes: planNodes(normalPlan.rows[0]["QUERY PLAN"][0].Plan) },
    denorm: { ms: denorm.ms, rows: denorm.value.rows, node: denormPlan.rows[0]["QUERY PLAN"][0].Plan["Node Type"], nodes: planNodes(denormPlan.rows[0]["QUERY PLAN"][0].Plan) },
  });
}));

app.post("/api/lab/u4/instalar", asyncRoute(async (req, res) => {
  if (req.body?.confirm !== true) throw Object.assign(new Error("Enviar confirm: true para instalar U4"), { status: 400 });
  const files = ["tp_fnbc_control_lote.sql", "tp_desnormalizacion_top_categorias.sql"];
  for (const file of files) {
    const sql = readText(path.join(here, "food-store-tp-u4", "sql", file));
    await pool.query(sql);
  }
  res.json({ ok: true, archivos: files });
}));

// U5 - roles, auditoría y login ---------------------------------------------

async function asRole(role, sql, params = []) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(`SET LOCAL ROLE ${role}`);
    try {
      const result = await client.query(sql, params);
      await client.query("ROLLBACK");
      return { ok: true, rows: result.rows.slice(0, 5), rowCount: result.rowCount };
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      return { ok: false, code: error.code, message: error.message };
    }
  } finally {
    client.release();
  }
}

app.get("/api/lab/u5/roles", asyncRoute(async (_req, res) => {
  const roles = await pool.query(`
    SELECT rolname, rolcanlogin FROM pg_roles
    WHERE rolname IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes',
                      'app_web','admin_datos','foodstore_auth_owner')
    ORDER BY rolname`);
  const grants = await pool.query(`
    SELECT grantee, table_name, privilege_type
    FROM information_schema.role_table_grants
    WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes',
                      'app_web','admin_datos')
    ORDER BY grantee, table_name, privilege_type
    LIMIT 40`);
  const tests = [
    ["app_web lee productos", await asRole("app_web", "SELECT count(*)::int AS n FROM producto")],
    ["app_web NO lee password_hash", await asRole("app_web", "SELECT password_hash FROM usuario LIMIT 1")],
    ["app_web NO borra pedidos", await asRole("app_web", "DELETE FROM pedido WHERE id = 1")],
    ["app_web NO se autoasigna admin_datos", await asRole("app_web", "GRANT admin_datos TO app_web")],
  ];
  res.json({ tests, roles: roles.rows, grants: grants.rows });
}));

app.get("/api/lab/u5/auditoria", asyncRoute(async (_req, res) => {
  const count = await pool.query("SELECT count(*)::int AS n FROM auditoria_stock");
  const rows = await pool.query("SELECT id, fecha_evento, operacion, cambios FROM auditoria_stock ORDER BY id DESC LIMIT 5");
  res.json({ filas: count.rows[0].n, ultimos: rows.rows });
}));

app.post("/api/lab/u5/login", asyncRoute(async (req, res) => {
  const mail = required(req.body.mail, "El mail");
  const password = required(req.body.password, "La contraseña");
  const { rows } = await pool.query("SELECT fn_autenticar($1, $2) AS id", [String(mail).trim(), String(password)]);
  const id = rows[0].id;
  if (!id) return res.status(401).json({ ok: false, error: "Credenciales inválidas" });
  const user = await pool.query("SELECT id, nombre, mail, rol FROM usuario WHERE id = $1", [id]);
  res.json({ ok: true, usuario: user.rows[0] });
}));

app.post("/api/lab/u5/auditar", asyncRoute(async (_req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("UPDATE producto SET stock = stock + 1 WHERE id = (SELECT min(id) FROM producto)");
    await client.query("UPDATE producto SET stock = stock - 1 WHERE id = (SELECT min(id) FROM producto)");
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }
  const { rows } = await pool.query("SELECT id, fecha_evento, operacion, cambios FROM auditoria_stock ORDER BY id DESC LIMIT 3");
  const count = await pool.query("SELECT count(*)::int AS n FROM auditoria_stock");
  res.json({ ok: true, filas: count.rows[0].n, ultimos: rows });
}));

// U6 - mantenimiento ---------------------------------------------------------

function latestBackup() {
  const dir = path.join(U6, "logs");
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.startsWith("backup_") && f.endsWith(".json")) : [];
  if (!files.length) return null;
  files.sort();
  return readJson(path.join(dir, files[files.length - 1]));
}

app.get("/api/lab/u6/estado", asyncRoute(async (_req, res) => {
  const restore = readJson(path.join(U6, "logs", "restore_resultado.json"));
  const backup = latestBackup();
  const health = readText(path.join(U6, "logs", "health.txt")).slice(0, 2500);
  const maintenance = readText(path.join(U6, "logs", "maintenance.txt")).slice(0, 2500);
  res.json({ restore, backup, health, maintenance });
}));

app.get("/api/lab/u6/salud", asyncRoute(async (_req, res) => {
  const { rows } = await pool.query(`
    SELECT current_database() AS base,
           pg_size_pretty(pg_database_size(current_database())) AS tamano,
           (SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()) AS conexiones,
           (SELECT count(*) FROM pedido) AS pedidos,
           (SELECT sum(stock) FROM producto) AS stock_total
  `);
  res.json(rows[0]);
}));

// U7 - MongoDB ---------------------------------------------------------------

app.get("/api/lab/u7/estado", asyncRoute(async (_req, res) => {
  const evidence = readJson(path.join(U7, "evidencias", "verificacion.json"));
  if (!process.env.MONGO_URL) {
    return res.json({ modo: "evidencia", message: "MONGO_URL no configurada; se muestra la evidencia de U7.", evidence });
  }
  try {
    const { MongoClient, Decimal128 } = await import("mongodb");
    const client = new MongoClient(process.env.MONGO_URL, { serverSelectionTimeoutMS: 4000 });
    await client.connect();
    const pedidos = client.db("foodstore_u7").collection("pedidos");
    const ids = evidence.parametros.ids;
    const query = (filter, projection = { _id: 1 }) => pedidos.find(filter, { projection }).sort({ _id: 1 }).toArray();
    const [total, muestra, estado, producto, importe] = await Promise.all([
      pedidos.countDocuments(),
      query({ _id: { $in: ids } }, { _id: 1, estado: 1, total: 1 }),
      query({ _id: { $in: ids }, estado: evidence.parametros.estado }),
      query({ _id: { $in: ids }, "lineas.producto_id": evidence.parametros.producto_id }),
      query({ _id: { $in: ids }, total: { $gt: Decimal128.fromString(String(evidence.parametros.umbral)) } }, { _id: 1, total: 1 }),
    ]);
    await client.close();
    const pg = await pool.query(`
      SELECT array_agg(id ORDER BY id) AS ids FROM pedido WHERE id = ANY($1::bigint[])
    `, [ids]);
    res.json({ modo: "mongo", total, muestra, estado, producto, importe, postgres: pg.rows[0].ids, evidence });
  } catch (error) {
    res.json({ modo: "evidencia", message: "MongoDB no respondió; se muestra la evidencia de U7.", detalle: error.message, evidence });
  }
}));

// U8 - SQLite ----------------------------------------------------------------

let sqlJsPromise;
async function getSqlJs() {
  if (!sqlJsPromise) {
    sqlJsPromise = initSqlJs({ locateFile: (file) => path.join(here, "node_modules", "sql.js", "dist", file) });
  }
  return sqlJsPromise;
}

function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/);
  const header = lines.shift().split(",");
  return lines.filter(Boolean).map((line) => header.map((_, index) => line.split(",")[index]));
}

function rows(db, sql) {
  const result = db.exec(sql);
  if (!result.length) return [];
  const { columns, values } = result[0];
  return values.map((value) => Object.fromEntries(columns.map((column, index) => [column, value[index]])));
}

async function makeTablet(snapshot) {
  const SQL = await getSqlJs();
  const db = new SQL.Database();
  db.exec(readText(path.join(U8, "sql", "schema_sqlite.sql")));
  db.exec("DELETE FROM snapshot_servidor;");
  const insert = db.prepare("INSERT INTO snapshot_servidor (producto_id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia) VALUES (?, ?, ?, ?, ?, ?, ?)");
  for (const row of parseCsv(readText(path.join(U8, "u8", snapshot)))) insert.run(row);
  insert.free();
  db.exec(readText(path.join(U8, "sql", "carga_snapshot.sql")));
  return db;
}

function addDraft(db, { id, product, qty, price, solicitud, user = "defensa" }) {
  db.run("INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha) VALUES (?, ?, ?, ?)", [id, user, "EFECTIVO", new Date().toISOString()]);
  db.run("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES (?, ?, ?, ?)", [id, product, qty, price]);
  db.run("INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo) VALUES (?, ?, 'PENDIENTE', NULL)", [solicitud, id]);
}

function semaforo(db) {
  db.exec(readText(path.join(U8, "sql", "semaforo.sql")));
}

const queueSql = "SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY estado, solicitud_uuid";

const cases = {
  C1: async () => {
    const db = await makeTablet("servidor_snapshot.csv");
    const result = rows(db, "SELECT * FROM vw_catalogo_disponible");
    db.close();
    return { titulo: "C1 - catálogo disponible sin servidor", catalogo: result };
  },
  C2: async () => {
    const db = await makeTablet("snapshots/caso_c2.csv");
    addDraft(db, { id: "44444444-4444-4444-8444-444444444444", product: 1, qty: 1, price: 105000, solicitud: "b2222222-2222-4222-8222-222222222222" });
    semaforo(db);
    const primera = rows(db, queueSql);
    db.run("UPDATE item_borrador SET precio_centavos_visto = 110000 WHERE id_local = ? AND producto_id = 1", ["44444444-4444-4444-8444-444444444444"]);
    db.run("INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo) VALUES (?, ?, 'PENDIENTE', NULL)", ["b2222222-2222-4222-8222-222222222223", "44444444-4444-4444-8444-444444444444"]);
    semaforo(db);
    const segunda = rows(db, queueSql);
    db.close();
    return { titulo: "C2 - cambio de precio", primera, segunda };
  },
  C3: async () => {
    const db = await makeTablet("snapshots/caso_c3.csv");
    addDraft(db, { id: "55555555-5555-4555-8555-555555555555", product: 3, qty: 5, price: 80000, solicitud: "b3333333-3333-4333-8333-333333333333" });
    semaforo(db);
    const result = rows(db, queueSql);
    db.close();
    return { titulo: "C3 - stock insuficiente", cola: result };
  },
  C4: async () => {
    const db = await makeTablet("snapshots/caso_c4.csv");
    addDraft(db, { id: "66666666-6666-4666-8666-666666666666", product: 2, qty: 1, price: 150000, solicitud: "b4444444-4444-4444-8444-444444444444" });
    semaforo(db);
    const result = rows(db, queueSql);
    const cache = rows(db, "SELECT id, nombre, precio_centavos, disponible, eliminado FROM producto_cache WHERE id = 2");
    const catalogo = rows(db, "SELECT count(*) AS n FROM vw_catalogo_disponible WHERE id = 2");
    db.close();
    return { titulo: "C4 - baja lógica", cola: result, cache, catalogo };
  },
  C5: async () => {
    const db = await makeTablet("servidor_snapshot.csv");
    addDraft(db, { id: "11111111-1111-4111-8111-111111111111", product: 1, qty: 2, price: 105000, solicitud: "a1111111-1111-4111-8111-111111111111" });
    semaforo(db);
    const result = rows(db, queueSql);
    db.close();
    return { titulo: "C5 - sin cambios", cola: result };
  },
  C6: async () => {
    const db = await makeTablet("servidor_snapshot.csv");
    addDraft(db, { id: "11111111-1111-4111-8111-111111111111", product: 1, qty: 2, price: 105000, solicitud: "a1111111-1111-4111-8111-111111111111" });
    semaforo(db);
    let error = null;
    try {
      db.run("INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo) VALUES (?, ?, 'PENDIENTE', NULL)", ["a1111111-1111-4111-8111-111111111111", "11111111-1111-4111-8111-111111111111"]);
    } catch (e) {
      error = e.message;
    }
    semaforo(db);
    const result = rows(db, queueSql);
    const n = rows(db, "SELECT count(*) AS n FROM cola_sync");
    db.close();
    return { titulo: "C6 - idempotencia", error, cola: result, solicitudes: n[0].n };
  },
  C7: async () => {
    const db = await makeTablet("servidor_snapshot.csv");
    db.run("INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha) VALUES (?, ?, ?, ?)", ["33333333-3333-4333-8333-333333333333", "defensa", "EFECTIVO", new Date().toISOString()]);
    const errors = [];
    try {
      db.run("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES (?, ?, ?, ?)", ["33333333-3333-4333-8333-333333333333", 1, 0, 105000]);
    } catch (e) {
      errors.push("cantidad 0: " + e.message);
    }
    try {
      db.run("INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto) VALUES (?, ?, ?, ?)", ["33333333-3333-4333-8333-333333333333", 9999, 1, 105000]);
    } catch (e) {
      errors.push("producto 9999: " + e.message);
    }
    const n = rows(db, "SELECT count(*) AS n FROM item_borrador WHERE id_local = '33333333-3333-4333-8333-333333333333'");
    db.close();
    return { titulo: "C7 - cantidad 0 y producto inexistente", errors, items: n[0].n };
  },
};

app.get("/api/lab/u8/estado", asyncRoute(async (_req, res) => {
  const SQL = await getSqlJs();
  const db = new SQL.Database(fs.readFileSync(path.join(U8, "u8", "tablet_u8.db")));
  const cola = rows(db, queueSql);
  const cache = rows(db, "SELECT id, nombre, precio_centavos, stock_visto, disponible, eliminado FROM producto_cache ORDER BY id");
  db.close();
  res.json({ cola, cache });
}));

app.post("/api/lab/u8/caso", asyncRoute(async (req, res) => {
  const key = required(req.body.caso, "El caso").toUpperCase();
  if (!cases[key]) throw Object.assign(new Error("Caso inválido; usar C1 a C7"), { status: 400 });
  const result = await cases[key]();
  res.json({ caso: key, ...result });
}));

// ---------------------------------------------------------------- errors

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || "Ocurrió un error inesperado" });
});

const port = 3000;
app.listen(port, "0.0.0.0", () => console.log(`Food Store gestor iniciado en puerto ${port}`));

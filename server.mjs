import express from "express";
import { Pool } from "pg";
import path from "node:path";
import { fileURLToPath } from "node:url";

const app = express();
const here = path.dirname(fileURLToPath(import.meta.url));
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

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

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(err.status || 500).json({ error: err.message || "Ocurrió un error inesperado" });
});

app.listen(process.env.PORT || 3000, () => console.log("Food Store gestor iniciado"));

-- ============================================================
-- views.sql - Food Store - Unidad 3, Semana 1
-- Compatible con schema_completo.sql: detalle_pedido y cliente.mail
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;
DROP VIEW IF EXISTS vw_detalle_pedido;
DROP VIEW IF EXISTS vw_pedidos_cliente;
DROP VIEW IF EXISTS vw_productos_vigentes;

-- Reporte de catálogo: no expone productos dados de baja.
CREATE VIEW vw_productos_vigentes AS
SELECT p.id AS producto_id,
       p.nombre AS producto,
       p.descripcion,
       p.precio,
       p.stock,
       c.id AS categoria_id,
       c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE AND c.activo = TRUE;

-- Reporte de pedidos. Se exponen datos del cliente, nunca credenciales
-- (la tabla cliente de este modelo tampoco contiene contrasena).
CREATE VIEW vw_pedidos_cliente AS
SELECT pe.id AS pedido_id,
       pe.fecha,
       pe.forma_pago,
       c.id AS cliente_id,
       c.nombre,
       c.apellido,
       c.mail,
       c.celular
FROM pedido pe
JOIN cliente c ON c.id = pe.cliente_id;

-- Detalle legible para comprobantes y consultas de soporte.
CREATE VIEW vw_detalle_pedido AS
SELECT d.pedido_id,
       d.producto_id,
       p.nombre AS producto,
       d.cantidad,
       d.precio_unitario,
       d.cantidad * d.precio_unitario AS subtotal
FROM detalle_pedido d
JOIN producto p ON p.id = d.producto_id;

-- Reporte agregado costoso: facturacion por categoria y mes.
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT date_trunc('month', pe.fecha)::date AS mes,
       c.id AS categoria_id,
       c.nombre AS categoria,
       SUM(d.cantidad * d.precio_unitario)::numeric(14,2) AS total_facturado,
       COUNT(DISTINCT pe.id) AS cantidad_pedidos
FROM pedido pe
JOIN detalle_pedido d ON d.pedido_id = pe.id
JOIN producto p ON p.id = d.producto_id
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE AND c.activo = TRUE
GROUP BY date_trunc('month', pe.fecha)::date, c.id, c.nombre;

-- Requisito para REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE UNIQUE INDEX ux_mv_facturacion_categoria_mes
ON mv_facturacion_categoria_mes (mes, categoria_id);

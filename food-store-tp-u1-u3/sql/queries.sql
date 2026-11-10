-- ============================================================
-- queries.sql — Food Store · consultas reales sobre la base masiva
-- Base de Datos II · Unidad 2 · Semana 3
-- ============================================================

-- Q1: productos vigentes de una categoría (usa idx_producto_categoria)
SELECT id, nombre, precio
FROM producto
WHERE categoria_id = 1 AND activo = TRUE
ORDER BY nombre;

-- Q2: historial de pedidos de un cliente (usa idx_pedido_cliente)
SELECT id, fecha, forma_pago
FROM pedido
WHERE cliente_id = 1000
ORDER BY fecha DESC;

-- Q3: pedidos de los últimos 30 días (SIN índice en fecha -> Seq Scan)
SELECT id, fecha, cliente_id, forma_pago
FROM pedido
WHERE fecha >= now() - interval '30 days';

-- Q4: total facturado por categoría (agregación con joins)
SELECT c.nombre, sum(d.cantidad * d.precio_unitario) AS total
FROM categoria c
JOIN producto p ON p.categoria_id = c.id
JOIN detalle_pedido d ON d.producto_id = p.id
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.nombre
ORDER BY total DESC;

-- Q5: top 10 productos más vendidos (agregación por producto)
SELECT p.nombre, sum(d.cantidad) AS vendido
FROM producto p
JOIN detalle_pedido d ON d.producto_id = p.id
WHERE p.activo = TRUE
GROUP BY p.nombre
ORDER BY vendido DESC
LIMIT 10;

-- Q6: pedidos que incluyen un producto concreto (SIN índice en producto_id -> Seq Scan)
SELECT p.id, p.fecha, cl.nombre, cl.apellido
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id
JOIN cliente cl ON cl.id = p.cliente_id
WHERE d.producto_id = 1;   -- id 1 = 'Muzzarella'

-- Q7: listado alfabético de productos (SIN índice en nombre -> sort de 50k filas)
SELECT id, nombre, precio
FROM producto
WHERE activo = TRUE
ORDER BY nombre
LIMIT 50;

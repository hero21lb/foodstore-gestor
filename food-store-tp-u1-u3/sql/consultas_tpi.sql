-- ============================================================
-- TPI Food Store - DML, agregaciones, subconsultas y ventanas
-- ============================================================

-- JOIN + agregación: total facturado por cliente.
SELECT c.id, c.nombre, c.apellido,
       SUM(d.cantidad * d.precio_unitario)::NUMERIC(14,2) AS total_facturado
FROM cliente c
JOIN pedido pe ON pe.cliente_id = c.id
JOIN detalle_pedido d ON d.pedido_id = pe.id
GROUP BY c.id, c.nombre, c.apellido
ORDER BY total_facturado DESC;

-- GROUP BY/HAVING: productos que superan 20 unidades vendidas.
SELECT p.id, p.nombre, SUM(d.cantidad) AS unidades_vendidas
FROM producto p
JOIN detalle_pedido d ON d.producto_id = p.id
WHERE p.activo = TRUE
GROUP BY p.id, p.nombre
HAVING SUM(d.cantidad) > 20
ORDER BY unidades_vendidas DESC;

-- Subconsulta: productos con precio superior al promedio de su categoría.
SELECT p.id, p.nombre, p.precio, c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id = p.categoria_id
WHERE p.activo = TRUE
  AND p.precio > (
      SELECT AVG(p2.precio)
      FROM producto p2
      WHERE p2.categoria_id = p.categoria_id AND p2.activo = TRUE
  )
ORDER BY categoria, precio DESC;

-- Función de ventana: ranking de productos más vendidos por categoría.
WITH ventas AS (
    SELECT c.id AS categoria_id, c.nombre AS categoria,
           p.id AS producto_id, p.nombre AS producto,
           SUM(d.cantidad) AS unidades_vendidas
    FROM categoria c
    JOIN producto p ON p.categoria_id = c.id
    JOIN detalle_pedido d ON d.producto_id = p.id
    WHERE c.activo = TRUE AND p.activo = TRUE
    GROUP BY c.id, c.nombre, p.id, p.nombre
)
SELECT categoria, producto, unidades_vendidas,
       DENSE_RANK() OVER (
           PARTITION BY categoria_id ORDER BY unidades_vendidas DESC
       ) AS puesto_en_categoria
FROM ventas
ORDER BY categoria, puesto_en_categoria, producto;

-- Función de ventana: evolución mensual y diferencia contra el mes anterior.
WITH facturacion_mensual AS (
    SELECT date_trunc('month', pe.fecha)::date AS mes,
           SUM(d.cantidad * d.precio_unitario)::NUMERIC(14,2) AS facturacion
    FROM pedido pe
    JOIN detalle_pedido d ON d.pedido_id = pe.id
    GROUP BY date_trunc('month', pe.fecha)::date
)
SELECT mes, facturacion,
       LAG(facturacion) OVER (ORDER BY mes) AS facturacion_mes_anterior,
       facturacion - LAG(facturacion) OVER (ORDER BY mes) AS variacion
FROM facturacion_mensual
ORDER BY mes;

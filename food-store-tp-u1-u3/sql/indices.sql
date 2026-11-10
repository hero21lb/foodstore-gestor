-- ============================================================
-- indices.sql — Food Store · Parte 2 (Semana 3)
-- Índices propuestos (por IA) y aceptados tras leerlos y justificarlos:
-- ============================================================

-- 1) Acelera las consultas por rango de fechas (ej. pedidos de los últimos 30 días)
--    Ataca el Seq Scan sobre pedido (200.000 filas) filtrado por fecha.
CREATE INDEX idx_pedido_fecha ON pedido(fecha);

-- 2) Acelera "pedidos que incluyen un producto" y las agregaciones por producto.
--    Ataca el Seq Scan sobre detalle_pedido (600.000 filas) filtrando por producto_id
--    (la FK producto_id no estaba indexada; el UNIQUE cubre (pedido_id, producto_id),
--    cuyo prefijo es pedido_id, no producto_id).
CREATE INDEX idx_detalle_producto ON detalle_pedido(producto_id);

-- 3) Acelera el listado alfabético de productos (ORDER BY nombre).
--    Ataca el Sort (top-N) de 50.003 filas; con el índice el orden lo da el propio árbol.
CREATE INDEX idx_producto_nombre ON producto(nombre);

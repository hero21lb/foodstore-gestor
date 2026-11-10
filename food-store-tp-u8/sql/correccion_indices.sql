-- U8 - Corrección H-02 del code review.
-- Elimina los índices exactamente duplicados que quedaron al aplicar
-- indices.sql y indices_u3.sql sobre la misma base.
-- No se toca idx_producto_nombre completo: no es duplicado exacto del
-- índice parcial y puede servir para búsquedas sobre productos inactivos.

DROP INDEX IF EXISTS idx_pedido_fecha;       -- duplicado de idx_pedido_fecha_u3
DROP INDEX IF EXISTS idx_detalle_producto;   -- duplicado de idx_detalle_pedido_producto_u3

-- Control posterior: no deben quedar dos índices btree sobre las mismas
-- columnas con distinto nombre.
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('pedido', 'detalle_pedido')
ORDER BY tablename, indexname;

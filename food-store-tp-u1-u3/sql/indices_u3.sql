-- ============================================================
-- indices_u3.sql - índices nuevos de Unidad 3
-- ============================================================

-- El índice UNIQUE (pedido_id, producto_id) no sirve para buscar por
-- producto_id solo. Este índice sí acelera ese acceso y los JOIN analíticos.
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_producto_u3
    ON detalle_pedido (producto_id);

-- Filtra por fecha, una columna de alta selectividad en reportes recientes.
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_u3
    ON pedido (fecha);

-- Evita ordenar toda la tabla al pedir el catálogo alfabético vigente.
-- Es parcial porque los reportes de negocio solo muestran activos.
CREATE INDEX IF NOT EXISTS idx_producto_nombre_activo_u3
    ON producto (nombre)
    WHERE activo = TRUE;

-- Propuesta descartada: no crear otro índice sobre pedido(cliente_id),
-- porque idx_pedido_cliente ya existe desde la Semana 3.

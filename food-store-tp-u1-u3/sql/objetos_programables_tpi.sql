-- ============================================================
-- TPI Food Store - objetos programables PostgreSQL 16+
-- Ejecutar luego de schema_completo.sql y restricciones_tp2.sql
-- ============================================================

-- Auditoría de cambios de stock. El detalle se conserva como JSONB.
CREATE TABLE IF NOT EXISTS auditoria_stock (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha_evento  TIMESTAMPTZ NOT NULL DEFAULT now(),
    operacion     VARCHAR(20) NOT NULL,
    cambios       JSONB NOT NULL
);

-- Trigger con tablas de transición: registra en una fila el conjunto de
-- productos cuyo stock cambió durante una sentencia UPDATE.
CREATE OR REPLACE FUNCTION fn_auditar_cambio_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_cambios JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'producto_id', nuevo.id,
            'stock_anterior', anterior.stock,
            'stock_nuevo', nuevo.stock
        ) ORDER BY nuevo.id
    )
    INTO v_cambios
    FROM productos_antes anterior
    JOIN productos_despues nuevo USING (id)
    WHERE anterior.stock IS DISTINCT FROM nuevo.stock;

    IF v_cambios IS NOT NULL THEN
        INSERT INTO auditoria_stock (operacion, cambios)
        VALUES ('UPDATE_STOCK', v_cambios);
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditar_cambio_stock ON producto;
CREATE TRIGGER trg_auditar_cambio_stock
AFTER UPDATE ON producto
REFERENCING OLD TABLE AS productos_antes NEW TABLE AS productos_despues
FOR EACH STATEMENT
EXECUTE FUNCTION fn_auditar_cambio_stock();

-- Función reutilizable para comprobantes y reportes.
CREATE OR REPLACE FUNCTION fn_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(14,2)
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(cantidad * precio_unitario), 0)::NUMERIC(14,2)
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id;
$$;

-- Procedimiento de alta atómica. Recibe los renglones como JSONB.
-- Ejemplo p_items: [{"producto_id":1,"cantidad":2},{"producto_id":3,"cantidad":1}]
CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    IN p_cliente_id BIGINT,
    IN p_forma_pago forma_pago,
    IN p_items JSONB,
    INOUT p_pedido_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lineas INTEGER;
    v_invalidas INTEGER;
BEGIN
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array'
       OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'p_items debe ser un arreglo JSONB no vacío';
    END IF;

    PERFORM 1 FROM cliente WHERE id = p_cliente_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'cliente % inexistente', p_cliente_id;
    END IF;

    SELECT COUNT(*) INTO v_invalidas
    FROM jsonb_to_recordset(p_items) AS x(producto_id BIGINT, cantidad INTEGER)
    LEFT JOIN producto p ON p.id = x.producto_id AND p.activo = TRUE
    WHERE p.id IS NULL OR x.cantidad IS NULL OR x.cantidad NOT BETWEEN 1 AND 20;

    IF v_invalidas > 0 THEN
        RAISE EXCEPTION 'items inválidos: producto inexistente/inactivo o cantidad fuera de rango';
    END IF;

    SELECT COUNT(*) INTO v_lineas
    FROM jsonb_to_recordset(p_items) AS x(producto_id BIGINT, cantidad INTEGER);
    IF v_lineas <> jsonb_array_length(p_items)
       OR EXISTS (
           SELECT 1
           FROM jsonb_to_recordset(p_items) AS x(producto_id BIGINT, cantidad INTEGER)
           GROUP BY producto_id HAVING COUNT(*) > 1
       ) THEN
        RAISE EXCEPTION 'cada producto debe aparecer una sola vez';
    END IF;

    INSERT INTO pedido (forma_pago, cliente_id)
    VALUES (p_forma_pago, p_cliente_id)
    RETURNING id INTO p_pedido_id;

    INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id)
    SELECT x.cantidad, p.precio, p_pedido_id, x.producto_id
    FROM jsonb_to_recordset(p_items) AS x(producto_id BIGINT, cantidad INTEGER)
    JOIN producto p ON p.id = x.producto_id;
END;
$$;

-- Pruebas manuales (usar BEGIN; ... ROLLBACK; antes de COMMIT):
-- CALL sp_registrar_pedido(1, 'EFECTIVO', '[{"producto_id":1,"cantidad":2}]'::jsonb, NULL);
-- SELECT fn_total_pedido(1);
-- UPDATE producto SET stock = stock - 1 WHERE id IN (1, 2);
-- SELECT * FROM auditoria_stock ORDER BY id DESC;

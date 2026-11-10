-- Unidad 4, Parte 2. Ejecutar sobre una COPIA poblada de Food Store.
-- Zona de negocio fija: Buenos Aires. No se modifican ventas históricas.
SET TIME ZONE 'America/Argentina/Buenos_Aires';

-- ANTES: equivalente ejecutable al enunciado en el esquema real.
-- No existen dp.subtotal, dp.eliminado ni ped.eliminado: el subtotal se
-- calcula y ninguna de esas dos tablas tiene borrado lógico.
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id AS categoria_id, c.nombre AS categoria,
       SUM(dp.cantidad * dp.precio_unitario)::numeric(14,2) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha >= CURRENT_DATE::timestamptz
  AND ped.fecha < (CURRENT_DATE + 1)::timestamptz
GROUP BY c.id, c.nombre
ORDER BY total_vendido DESC, c.id
LIMIT 5;

BEGIN;

-- Patrón elegido: columnas precalculadas en la línea, sincronizadas por
-- triggers dentro de la misma transacción que cambia la fuente.
ALTER TABLE detalle_pedido
    ADD COLUMN IF NOT EXISTS fecha_venta_u4 DATE,
    ADD COLUMN IF NOT EXISTS categoria_id_u4 BIGINT,
    ADD COLUMN IF NOT EXISTS categoria_nombre_u4 VARCHAR(80),
    ADD COLUMN IF NOT EXISTS subtotal_u4 NUMERIC(14,2);

-- El trigger heredado de TP2 comprobaba el precio también al actualizar
-- metadatos. Se limita la validación a los cambios que alteran su regla.
DO $$
BEGIN
    IF to_regprocedure('trg_check_precio_unitario()') IS NOT NULL THEN
        DROP TRIGGER IF EXISTS chk_precio_unitario ON detalle_pedido;
        CREATE TRIGGER chk_precio_unitario
        BEFORE INSERT OR UPDATE OF precio_unitario, producto_id
        ON detalle_pedido
        FOR EACH ROW EXECUTE FUNCTION trg_check_precio_unitario();
    END IF;
END;
$$;

-- Backfill transaccional de las filas preexistentes.
UPDATE detalle_pedido dp
SET fecha_venta_u4 = (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
    categoria_id_u4 = c.id,
    categoria_nombre_u4 = c.nombre,
    subtotal_u4 = dp.cantidad * dp.precio_unitario
FROM pedido ped, producto pr, categoria c
WHERE ped.id = dp.pedido_id
  AND pr.id = dp.producto_id
  AND c.id = pr.categoria_id;

ALTER TABLE detalle_pedido
    ALTER COLUMN fecha_venta_u4 SET NOT NULL,
    ALTER COLUMN categoria_id_u4 SET NOT NULL,
    ALTER COLUMN categoria_nombre_u4 SET NOT NULL,
    ALTER COLUMN subtotal_u4 SET NOT NULL;

-- Sincroniza altas y cambios de cantidad, precio, pedido o producto.
-- FOR SHARE evita que las dimensiones cambien entre la lectura del trigger
-- y la confirmación de la línea. Las demás actualizaciones de metadatos
-- se hacen con triggers específicos de pedido, producto y categoría.
CREATE OR REPLACE FUNCTION fn_u4_sincronizar_detalle()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    SELECT (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date,
           c.id, c.nombre
    INTO NEW.fecha_venta_u4, NEW.categoria_id_u4, NEW.categoria_nombre_u4
    FROM pedido ped
    JOIN producto pr ON pr.id = NEW.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    WHERE ped.id = NEW.pedido_id
    FOR SHARE OF ped, pr, c;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido, producto o categoría inexistente';
    END IF;
    NEW.subtotal_u4 := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_u4_sincronizar_detalle ON detalle_pedido;
CREATE TRIGGER trg_u4_sincronizar_detalle
BEFORE INSERT OR UPDATE OF cantidad, precio_unitario, pedido_id, producto_id
ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_u4_sincronizar_detalle();

CREATE OR REPLACE FUNCTION fn_u4_pedido_fecha()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE detalle_pedido
    SET fecha_venta_u4 = (NEW.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
    WHERE pedido_id = NEW.id;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_u4_pedido_fecha ON pedido;
CREATE TRIGGER trg_u4_pedido_fecha
AFTER UPDATE OF fecha ON pedido
FOR EACH ROW
WHEN (OLD.fecha IS DISTINCT FROM NEW.fecha)
EXECUTE FUNCTION fn_u4_pedido_fecha();

CREATE OR REPLACE FUNCTION fn_u4_producto_categoria()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE detalle_pedido dp
    SET categoria_id_u4 = c.id,
        categoria_nombre_u4 = c.nombre
    FROM categoria c
    WHERE c.id = NEW.categoria_id
      AND dp.producto_id = NEW.id;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_u4_producto_categoria ON producto;
CREATE TRIGGER trg_u4_producto_categoria
AFTER UPDATE OF categoria_id ON producto
FOR EACH ROW
WHEN (OLD.categoria_id IS DISTINCT FROM NEW.categoria_id)
EXECUTE FUNCTION fn_u4_producto_categoria();

CREATE OR REPLACE FUNCTION fn_u4_categoria_nombre()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE detalle_pedido
    SET categoria_nombre_u4 = NEW.nombre
    WHERE categoria_id_u4 = NEW.id;
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_u4_categoria_nombre ON categoria;
CREATE TRIGGER trg_u4_categoria_nombre
AFTER UPDATE OF nombre ON categoria
FOR EACH ROW
WHEN (OLD.nombre IS DISTINCT FROM NEW.nombre)
EXECUTE FUNCTION fn_u4_categoria_nombre();

CREATE INDEX IF NOT EXISTS idx_detalle_top_categorias_u4
ON detalle_pedido (fecha_venta_u4, categoria_id_u4)
INCLUDE (categoria_nombre_u4, subtotal_u4);

COMMIT;

ANALYZE detalle_pedido;

-- DESPUÉS: lee únicamente la tabla que contiene los datos precalculados.
EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria_id_u4 AS categoria_id,
       categoria_nombre_u4 AS categoria,
       SUM(subtotal_u4)::numeric(14,2) AS total_vendido
FROM detalle_pedido
WHERE fecha_venta_u4 = CURRENT_DATE
GROUP BY categoria_id_u4, categoria_nombre_u4
ORDER BY total_vendido DESC, categoria_id_u4
LIMIT 5;

-- Auditoría: DEBE devolver cero filas. Detecta diferencias de fecha,
-- categoría, nombre y subtotal contra las cuatro tablas fuente.
SELECT dp.id AS detalle_id,
       dp.fecha_venta_u4, (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha_esperada,
       dp.categoria_id_u4, c.id AS categoria_esperada,
       dp.categoria_nombre_u4, c.nombre AS nombre_esperado,
       dp.subtotal_u4, (dp.cantidad * dp.precio_unitario)::numeric(14,2) AS subtotal_esperado
FROM detalle_pedido dp
JOIN pedido ped ON ped.id = dp.pedido_id
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
WHERE dp.fecha_venta_u4 IS DISTINCT FROM (ped.fecha AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
   OR dp.categoria_id_u4 IS DISTINCT FROM c.id
   OR dp.categoria_nombre_u4 IS DISTINCT FROM c.nombre
   OR dp.subtotal_u4 IS DISTINCT FROM (dp.cantidad * dp.precio_unitario)::numeric(14,2);

-- Reversión sin pérdida de ventas: DROP INDEX, DROP TRIGGER/FUNCTION y
-- ALTER TABLE ... DROP COLUMN para los cuatro campos _u4. Los campos base
-- nunca se reemplazan ni se eliminan.

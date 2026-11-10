-- ============================================================
-- U8 - Carga de una instantánea nueva en la tablet
-- Requiere haber importado el CSV en snapshot_servidor:
--   DELETE FROM snapshot_servidor;
--   .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
-- Este script es idempotente: actualiza filas existentes y conserva
-- la fila de un producto que el servidor dio de baja (lápida).
-- ============================================================

BEGIN;

INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT producto_id,
       nombre,
       precio_centavos,
       stock,
       CASE WHEN lower(trim(disponible)) IN ('t', 'true', '1') THEN 1 ELSE 0 END,
       CASE WHEN lower(trim(eliminado))  IN ('t', 'true', '1') THEN 1 ELSE 0 END,
       fecha_copia
FROM snapshot_servidor
WHERE true
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

-- Si un producto desapareciera del servidor sin lápida, se marca como
-- eliminado en la tablet en vez de borrar la fila.
UPDATE producto_cache
SET disponible = 0,
    eliminado   = 1
WHERE id NOT IN (SELECT producto_id FROM snapshot_servidor);

COMMIT;

SELECT count(*) AS productos_en_cache,
       sum(CASE WHEN disponible = 1 AND eliminado = 0 THEN 1 ELSE 0 END)
           AS disponibles
FROM producto_cache;

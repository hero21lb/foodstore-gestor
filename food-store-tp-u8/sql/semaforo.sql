-- ============================================================
-- U8 - Semáforo de sincronización (SQLite)
-- Solo evalúa solicitudes PENDIENTE. No toca PostgreSQL: lee la
-- instantánea local y actualiza la cola de la tablet.
--
-- Rojo     RECHAZADO: producto inexistente, dado de baja, no disponible
--                     o stock insuficiente.
-- Amarillo CONFLICTO: no hay rojo, pero cambió el precio.
-- Verde    SIMULADO_APROBADO: todo coincide.
-- ============================================================

BEGIN;

-- Un borrador sin renglones no puede aprobarse.
UPDATE cola_sync
SET estado = 'RECHAZADO',
    motivo = 'Borrador sin ítems'
WHERE estado = 'PENDIENTE'
  AND NOT EXISTS (
      SELECT 1 FROM item_borrador i
      WHERE i.id_local = cola_sync.id_local
  );

WITH items AS (
    SELECT cs.solicitud_uuid,
           i.producto_id,
           i.cantidad,
           i.precio_centavos_visto,
           s.producto_id       AS snap_id,
           s.precio_centavos   AS snap_precio,
           s.stock             AS snap_stock,
           s.disponible        AS snap_disponible,
           s.eliminado         AS snap_eliminado,
           CASE
               WHEN s.producto_id IS NULL
                   THEN 'producto ' || i.producto_id || ' inexistente'
               WHEN lower(trim(s.eliminado)) IN ('t', 'true', '1')
                   THEN 'producto ' || i.producto_id || ' dado de baja'
               WHEN lower(trim(s.disponible)) NOT IN ('t', 'true', '1')
                   THEN 'producto ' || i.producto_id || ' no disponible'
               WHEN i.cantidad > s.stock
                   THEN 'stock insuficiente para producto ' || i.producto_id
                        || ' (pedido ' || i.cantidad || ', disponible ' || s.stock || ')'
           END AS problema,
           CASE
               WHEN s.producto_id IS NOT NULL
                AND s.precio_centavos <> i.precio_centavos_visto
                   THEN 'producto ' || i.producto_id || ' visto '
                        || i.precio_centavos_visto || ', ahora ' || s.precio_centavos
           END AS cambio_precio
    FROM cola_sync cs
    JOIN item_borrador i ON i.id_local = cs.id_local
    LEFT JOIN snapshot_servidor s ON s.producto_id = i.producto_id
    WHERE cs.estado = 'PENDIENTE'
),
evaluacion AS (
    SELECT solicitud_uuid,
           MAX(CASE WHEN problema IS NOT NULL THEN 1 ELSE 0 END) AS hay_rojo,
           MAX(CASE WHEN problema IS NULL AND cambio_precio IS NOT NULL
                    THEN 1 ELSE 0 END) AS hay_amarillo,
           COALESCE(group_concat(problema, '; '), '')      AS problemas,
           COALESCE(group_concat(cambio_precio, '; '), '') AS precios
    FROM items
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET estado = CASE
                 WHEN e.hay_rojo = 1     THEN 'RECHAZADO'
                 WHEN e.hay_amarillo = 1 THEN 'CONFLICTO'
                 ELSE 'SIMULADO_APROBADO'
             END,
    motivo = CASE
                 WHEN e.hay_rojo = 1     THEN e.problemas
                 WHEN e.hay_amarillo = 1 THEN 'Cambio de precio: ' || e.precios
                 ELSE 'Sin diferencias contra la instantánea'
             END
FROM evaluacion e
WHERE cola_sync.solicitud_uuid = e.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';

COMMIT;

-- Resultado legible de la simulación.
SELECT solicitud_uuid,
       id_local,
       estado,
       motivo
FROM cola_sync
ORDER BY estado, solicitud_uuid;

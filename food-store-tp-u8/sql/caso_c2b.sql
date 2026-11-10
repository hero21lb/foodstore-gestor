-- C2, segunda parte: el cliente acepta el precio nuevo del servidor.
-- Se actualiza el borrador y se crea una solicitud nueva; la anterior
-- queda CONFLICTO como registro histórico.
PRAGMA foreign_keys = ON;
UPDATE item_borrador
SET precio_centavos_visto = 110000
WHERE id_local = '44444444-4444-4444-8444-444444444444'
  AND producto_id = 1;

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b2222222-2222-4222-8222-222222222223',
        '44444444-4444-4444-8444-444444444444', 'PENDIENTE', NULL);

SELECT 'C2b: precio aceptado y solicitud nueva' AS paso;

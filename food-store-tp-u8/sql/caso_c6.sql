-- C6: reenvío de la misma solicitud (mismo UUID).
-- Debe fallar por PRIMARY KEY y la simulación repetida no debe reevaluar.
PRAGMA foreign_keys = ON;

.print 'C6: reenvío del UUID ya usado (debe fallar por PK)'
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('a1111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);

.print 'C6: estado de la solicitud original (no se reevalúa)'
SELECT solicitud_uuid, estado, motivo
FROM cola_sync
WHERE solicitud_uuid = 'a1111111-1111-4111-8111-111111111111';

.print 'C6: cantidad total de solicitudes (no se duplicó)'
SELECT count(*) AS solicitudes FROM cola_sync;

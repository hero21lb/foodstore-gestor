-- ============================================================
-- U8 - Pruebas de la base de la tablet (consigna 1.c)
-- Requiere schema_sqlite.sql y una instantánea cargada.
-- Ejecutar con: sqlite3 tablet_u8.db < pruebas_sqlite.sql
-- ============================================================

PRAGMA foreign_keys = ON;

.print '--- 1.c.1 Borrador completo: BEGIN ... COMMIT ---'
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('11111111-1111-4111-8111-111111111111', 'vendedor_feria',
        'EFECTIVO', '2026-11-10T10:00:00-03:00');
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('11111111-1111-4111-8111-111111111111', 1, 2, 105000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('a1111111-1111-4111-8111-111111111111',
        '11111111-1111-4111-8111-111111111111', 'PENDIENTE', NULL);
COMMIT;

SELECT 'borrador' AS entidad, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '11111111-1111-4111-8111-111111111111'
UNION ALL
SELECT 'items', count(*) FROM item_borrador
WHERE id_local = '11111111-1111-4111-8111-111111111111'
UNION ALL
SELECT 'solicitud', count(*) FROM cola_sync
WHERE solicitud_uuid = 'a1111111-1111-4111-8111-111111111111';

.print '--- 1.c.1 Bis: operación deshecha con ROLLBACK ---'
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('22222222-2222-4222-8222-222222222222', 'vendedor_feria',
        'TARJETA', '2026-11-10T10:05:00-03:00');
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('22222222-2222-4222-8222-222222222222', 1, 1, 105000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('a2222222-2222-4222-8222-222222222222',
        '22222222-2222-4222-8222-222222222222', 'PENDIENTE', NULL);
ROLLBACK;

SELECT 'borrador_rollback' AS entidad, count(*) AS filas
FROM pedido_borrador
WHERE id_local = '22222222-2222-4222-8222-222222222222'
UNION ALL
SELECT 'items_rollback', count(*) FROM item_borrador
WHERE id_local = '22222222-2222-4222-8222-222222222222'
UNION ALL
SELECT 'solicitud_rollback', count(*) FROM cola_sync
WHERE solicitud_uuid = 'a2222222-2222-4222-8222-222222222222';

.print '--- 1.c.2 Caso C1: catálogo disponible sin servidor ---'
SELECT * FROM vw_catalogo_disponible;

.print '--- 1.c.3 Caso C7: cantidad 0 y producto inexistente ---'
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('33333333-3333-4333-8333-333333333333', 'vendedor_feria',
        'TRANSFERENCIA', '2026-11-10T10:10:00-03:00');

.print 'Intento con cantidad = 0 (debe fallar por CHECK):'
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('33333333-3333-4333-8333-333333333333', 1, 0, 105000);

.print 'Intento con producto_id = 9999 (debe fallar por FK):'
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('33333333-3333-4333-8333-333333333333', 9999, 1, 105000);

SELECT 'items_invalidos_guardados' AS control, count(*) AS filas
FROM item_borrador
WHERE id_local = '33333333-3333-4333-8333-333333333333';

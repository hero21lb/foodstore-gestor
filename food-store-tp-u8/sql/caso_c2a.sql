-- C2, primera parte: borrador con el precio viejo.
PRAGMA foreign_keys = ON;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('44444444-4444-4444-8444-444444444444', 'vendedor_feria',
        'TARJETA', '2026-11-10T11:00:00-03:00');
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('44444444-4444-4444-8444-444444444444', 1, 1, 105000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b2222222-2222-4222-8222-222222222222',
        '44444444-4444-4444-8444-444444444444', 'PENDIENTE', NULL);
SELECT 'C2a: solicitud creada' AS paso;

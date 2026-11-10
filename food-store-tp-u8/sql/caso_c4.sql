-- C4: borrador de un producto que el servidor dio de baja lógica.
-- El servidor ya marcó producto 2 como inactivo antes de la instantánea.
PRAGMA foreign_keys = ON;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('66666666-6666-4666-8666-666666666666', 'vendedor_feria',
        'TRANSFERENCIA', '2026-11-10T11:20:00-03:00');
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('66666666-6666-4666-8666-666666666666', 2, 1, 150000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b4444444-4444-4444-8444-444444444444',
        '66666666-6666-4666-8666-666666666666', 'PENDIENTE', NULL);
SELECT 'C4: solicitud creada' AS paso;

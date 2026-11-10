-- C3: borrador por más unidades de las que quedan.
-- El servidor ya bajó el stock del producto 3 a 2 antes de la instantánea.
PRAGMA foreign_keys = ON;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('55555555-5555-4555-8555-555555555555', 'vendedor_feria',
        'EFECTIVO', '2026-11-10T11:10:00-03:00');
INSERT INTO item_borrador
    (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('55555555-5555-4555-8555-555555555555', 3, 5, 80000);
INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b3333333-3333-4333-8333-333333333333',
        '55555555-5555-4555-8555-555555555555', 'PENDIENTE', NULL);
SELECT 'C3: solicitud creada' AS paso;

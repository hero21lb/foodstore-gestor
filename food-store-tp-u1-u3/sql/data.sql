-- ============================================================
-- data.sql — Food Store · seed de referencia (pocas filas)
-- Datos de la planilla del TP1 (Semana 1) + algunas categorías
-- ============================================================

-- Categorías
INSERT INTO categoria (nombre, descripcion) VALUES
    ('Pizzas', 'Pizzas y variedades'),
    ('Bebidas', 'Bebidas con y sin alcohol'),
    ('Postres', 'Postres y dulces'),
    ('Empanadas', 'Empanadas al horno y fritas');

-- Productos (precio = precio de lista actual)
INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id) VALUES
    ('Muzzarella', 'Pizza de muzzarella', 1050.00, 40, (SELECT id FROM categoria WHERE nombre = 'Pizzas')),
    ('Napolitana', 'Pizza napolitana', 1500.00, 35, (SELECT id FROM categoria WHERE nombre = 'Pizzas')),
    ('Coca 1.5L', 'Gaseosa cola 1.5 litros', 800.00, 100, (SELECT id FROM categoria WHERE nombre = 'Bebidas'));

-- Clientes
INSERT INTO cliente (nombre, apellido, mail, celular) VALUES
    ('Ana', 'Gómez', 'ana.gomez@mail.com', '2615551001'),
    ('Luis', 'Paz', 'luis.paz@mail.com', '2615551002'),
    ('Marta', 'Ruiz', 'marta.ruiz@mail.com', '2615551003');

-- Pedidos (fecha, forma_pago, cliente)
INSERT INTO pedido (fecha, forma_pago, cliente_id) VALUES
    ('2026-03-01 12:00:00-03', 'EFECTIVO',      (SELECT id FROM cliente WHERE mail = 'ana.gomez@mail.com')),
    ('2026-03-01 13:00:00-03', 'TARJETA',       (SELECT id FROM cliente WHERE mail = 'luis.paz@mail.com')),
    ('2026-03-05 10:00:00-03', 'TRANSFERENCIA', (SELECT id FROM cliente WHERE mail = 'ana.gomez@mail.com')),
    ('2026-03-06 18:00:00-03', 'EFECTIVO',      (SELECT id FROM cliente WHERE mail = 'marta.ruiz@mail.com')),
    ('2026-03-07 20:00:00-03', 'TARJETA',       (SELECT id FROM cliente WHERE mail = 'luis.paz@mail.com'));

-- Detalles de pedido (cantidad, precio_unitario histórico)
-- Pedido 1: Muzzarella x2 a 1000, Coca 1.5L x1 a 800
INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id) VALUES
    (2, 1000.00, (SELECT id FROM pedido WHERE fecha = '2026-03-01 12:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Muzzarella')),
    (1, 800.00,  (SELECT id FROM pedido WHERE fecha = '2026-03-01 12:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Coca 1.5L')),
    -- Pedido 2: Napolitana x1 a 1500
    (1, 1500.00, (SELECT id FROM pedido WHERE fecha = '2026-03-01 13:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Napolitana')),
    -- Pedido 3: Muzzarella x3 a 1050
    (3, 1050.00, (SELECT id FROM pedido WHERE fecha = '2026-03-05 10:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Muzzarella')),
    -- Pedido 4: Coca 1.5L x4 a 800, Napolitana x2 a 1500
    (4, 800.00,  (SELECT id FROM pedido WHERE fecha = '2026-03-06 18:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Coca 1.5L')),
    (2, 1500.00, (SELECT id FROM pedido WHERE fecha = '2026-03-06 18:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Napolitana')),
    -- Pedido 5: Muzzarella x1 a 1050
    (1, 1050.00, (SELECT id FROM pedido WHERE fecha = '2026-03-07 20:00:00-03'), (SELECT id FROM producto WHERE nombre = 'Muzzarella'));

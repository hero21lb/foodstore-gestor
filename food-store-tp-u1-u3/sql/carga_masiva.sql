-- ============================================================
-- carga_masiva.sql — Food Store · Parte 1 (Semana 3)
-- Pobla masivamente con generate_series:
--   * 50.000 productos (distribuidos parejo entre las categorías)
--   * 20.000 clientes
--   * 200.000 pedidos + 600.000 líneas de detalle (3 por pedido)
-- Protocolo: ejecutar DENTRO DE UNA TRANSACCIÓN, sobre copia, con respaldo previo.
-- Nota: las FK se resuelven indexando arrays de ids reales (O(1) por fila),
--       robusto ante huecos de secuencia y sin nested loops.
-- ============================================================

-- 1) 50.000 productos, precio 500..5000, stock 0..200, repartidos parejo entre categorías
INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id, activo)
SELECT
    'Producto ' || g,
    'Producto generado masivamente ' || g,
    (500 + random() * 4500)::numeric(10,2),
    floor(random() * 201)::int,
    cats.arr[1 + ((g - 1) % array_length(cats.arr, 1))::int],
    TRUE
FROM generate_series(1, 50000) AS g
CROSS JOIN (SELECT array_agg(id ORDER BY id) AS arr FROM categoria) AS cats;

-- 2) 20.000 clientes (mail único por índice g)
INSERT INTO cliente (nombre, apellido, mail, celular)
SELECT
    'Nombre' || g,
    'Apellido' || g,
    'usuario' || g || '@foodstore.com',
    '261' || lpad((g % 10000000)::text, 7, '0')
FROM generate_series(1, 20000) AS g;

-- 3) 200.000 pedidos (fecha en los últimos 365 días, forma de pago aleatoria,
--    cliente distribuido de forma pareja entre los existentes)
INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT
    now() - (random() * interval '365 days'),
    (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO'])[1 + floor(random() * 3)]::forma_pago,
    cl.arr[1 + ((g - 1) % array_length(cl.arr, 1))::int]
FROM generate_series(1, 200000) AS g
CROSS JOIN (SELECT array_agg(id ORDER BY id) AS arr FROM cliente) AS cl;

-- 4) 600.000 líneas de detalle (3 por pedido, productos distintos dentro del pedido)
--    Solo para los pedidos nuevos (sin detalle previo), respetando UNIQUE(pedido_id, producto_id)
INSERT INTO detalle_pedido (cantidad, precio_unitario, pedido_id, producto_id)
SELECT
    1 + floor(random() * 10)::int,
    (500 + random() * 4500)::numeric(10,2),
    p.id,
    pr.arr[1 + ((p.id + n) % array_length(pr.arr, 1))::int]
FROM pedido p
CROSS JOIN generate_series(1, 3) AS n
CROSS JOIN (SELECT array_agg(id ORDER BY id) AS arr FROM producto) AS pr
WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.pedido_id = p.id);

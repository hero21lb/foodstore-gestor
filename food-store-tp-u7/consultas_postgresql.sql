-- U7: ejecutar en foodstore. Muestra identica a MongoDB: pedidos 1 a 5.
-- estado fue agregado para U7; los valores de la muestra son sinteticos.
-- Este archivo solo consulta; laboratorio_u7.py preparar efectua el cambio con respaldo.
BEGIN TRANSACTION READ ONLY;

-- a) Todos los pedidos migrados.
SELECT id, estado FROM public.pedido
WHERE id IN (1,2,3,4,5) ORDER BY id;

-- b) Estado presente en los datos de prueba.
SELECT id, estado FROM public.pedido
WHERE id IN (1,2,3,4,5) AND estado='CONFIRMADO' ORDER BY id;

-- c) Producto del pedido 1 (conserva el identificador real del origen).
SELECT DISTINCT p.id
FROM public.pedido p JOIN public.detalle_pedido d ON d.pedido_id=p.id
WHERE p.id IN (1,2,3,4,5)
  AND d.producto_id=(SELECT producto_id FROM public.detalle_pedido
                    WHERE pedido_id=1 ORDER BY id LIMIT 1)
ORDER BY p.id;

-- d) 300 separa importes menores y mayores en la muestra.
SELECT pedido_id AS id, SUM(cantidad*precio_unitario) AS total
FROM public.detalle_pedido WHERE pedido_id IN (1,2,3,4,5)
GROUP BY pedido_id HAVING SUM(cantidad*precio_unitario)>300 ORDER BY pedido_id;
COMMIT;

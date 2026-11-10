-- U8 - Control final: la tablet no creó pedidos ni movió stock.
-- Ejecutar en foodstore_u8_lab, nunca en railway.
SET TIME ZONE 'America/Argentina/Buenos_Aires';

SELECT 'pedidos' AS metrica, count(*)::text AS valor FROM pedido
UNION ALL
SELECT 'detalle_pedido', count(*)::text FROM detalle_pedido
UNION ALL
SELECT 'stock_total', sum(stock)::text FROM producto
UNION ALL
SELECT 'md5_pedidos',
       md5(string_agg(id::text || '|' || fecha::text || '|' ||
                      forma_pago::text || '|' || cliente_id::text,
                      ';' ORDER BY id))
FROM pedido
UNION ALL
SELECT 'md5_detalles',
       md5(string_agg(id::text || '|' || cantidad::text || '|' ||
                      precio_unitario::text || '|' || pedido_id::text || '|' ||
                      producto_id::text,
                      ';' ORDER BY id))
FROM detalle_pedido;

-- La misma consulta sirve antes y después de correr el semáforo.
-- Los únicos cambios deliberados son los fixtures de C2 (precio),
-- C3 (stock, restaurado después de exportar) y C4 (baja lógica).

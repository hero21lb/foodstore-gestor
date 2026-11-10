# Informe de mediciones - Unidad 3, Semana 1

## Alcance y decisión sobre el esquema

El práctico continúa `schema_completo.sql`, `data.sql` y `queries.sql`. En los
archivos heredados existe una variante más antigua (`schema.sql`) que usa
`linea_pedido` y `email`; no se mezclan ambas variantes porque produciría un
script no ejecutable. El modelo no se modifica: solo se agregan índices y vistas.

## Índices aceptados

| Consulta | Problema | Índice | Razón |
|---|---|---|---|
| Q3, pedidos recientes | filtro por `pedido.fecha` | `idx_pedido_fecha_u3` | fecha tiene buena selectividad para ventanas temporales |
| Q5/Q6, ventas por producto | filtro/JOIN por `detalle_pedido.producto_id` | `idx_detalle_pedido_producto_u3` | el índice UNIQUE existente empieza por `pedido_id` |
| Q7, catálogo alfabético | orden por `producto.nombre` | `idx_producto_nombre_activo_u3` | índice parcial: solo filas vigentes |

Ejecutar en una copia con datos masivos y guardar la salida completa:

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha, cliente_id, forma_pago
FROM pedido WHERE fecha >= now() - interval '30 days';

\i sql/indices_u3.sql

EXPLAIN (ANALYZE, BUFFERS) SELECT id, fecha, cliente_id, forma_pago
FROM pedido WHERE fecha >= now() - interval '30 days';
```

Repetir el mismo procedimiento para Q6 y Q7. En una carga pequeña PostgreSQL
puede conservar un `Seq Scan` porque leer toda la tabla es más barato; eso no
invalidaría el diseño. La aceptación se decide con el plan y el tiempo sobre
la carga masiva, no por intuición.

## Costo de escritura

Comparar el mismo lote de varios cientos de INSERT en una transacción, primero
sin los tres índices nuevos y luego con `indices_u3.sql`. Registrar `Planning
Time`, `Execution Time` y cantidad de filas. Los índices mejoran lectura pero
aumentan el trabajo de cada INSERT y el espacio ocupado; por eso se conservan
solo los que sirven a consultas frecuentes.

## Índice descartado

Se descarta `CREATE INDEX ... ON pedido(cliente_id)` porque `idx_pedido_cliente`
ya fue creado en la Semana 3. Sería redundante: duplicaría mantenimiento e
inventario sin aportar una ruta de acceso nueva.

## Vistas y equivalencia

- `vw_productos_vigentes` equivale al JOIN entre `producto` y `categoria` con
  ambos filtros `activo = TRUE`.
- `vw_pedidos_cliente` equivale al JOIN entre `pedido` y `cliente`; expone solo
  datos identificatorios y no credenciales.
- `vw_detalle_pedido` equivale al JOIN entre `detalle_pedido` y `producto` y
  calcula el subtotal sin almacenarlo.

La verificación exacta se realiza comparando cada consulta manual con su vista,
ordenando por las mismas claves y comprobando que ambas devuelvan el mismo
conjunto de filas.

## Vista materializada

`mv_facturacion_categoria_mes` materializa la facturación por mes y categoría.
La consulta original recalcula JOIN, agrupación y suma en cada ejecución; la
consulta sobre la vista lee el resultado ya agregado. El índice único sobre
`(mes, categoria_id)` permite `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Para un tablero consultado muchas veces al día, se recomienda refrescar una vez
por hora o al cierre de cada lote de pedidos. Durante el refresh los usuarios
pueden ver el último corte confirmado: el dato no es transaccionalmente actual
hasta completar el siguiente refresh.

## Ejecución realizada en Railway

La base `postgrefacu` fue desplegada y cargada con 20.000 filas en `pedido`,
20.000 en `detalle_pedido`, 5.000 clientes, 1.000 productos y 20 categorías.
Los planes posteriores a la creación de los índices fueron:

| Consulta | Plan observado | Execution Time |
|---|---|---:|
| Pedidos de los últimos 30 días | Bitmap Heap Scan + Bitmap Index Scan sobre `idx_pedido_fecha_u3` | 0,610 ms |
| Pedidos que incluyen producto 1 | Bitmap Heap Scan sobre `idx_detalle_producto_u3` + Index Scan en joins | 0,434 ms |
| Catálogo vigente ordenado | Index Scan sobre `idx_producto_nombre_activo_u3` | 0,050 ms |
| Lectura de la vista materializada | Seq Scan sobre `mv_facturacion_categoria_mes` | 0,082 ms |

La vista materializada devolvió 260 filas agregadas. Para comparar exactamente
contra la consulta original, el agrupamiento debe usar
`date_trunc('month', pe.fecha)::date`, que es la misma clave `mes` almacenada en
`mv_facturacion_categoria_mes`.

# Food Store - Unidad 3, Semana 1

## Orden de ejecución

1. Crear una base PostgreSQL 16+ vacía.
2. Ejecutar `sql/schema_completo.sql`.
3. Ejecutar `sql/data.sql` y, si se dispone, `sql/carga_masiva.sql`.
4. Medir las consultas con `EXPLAIN (ANALYZE, BUFFERS)` antes de los índices.
5. Ejecutar `sql/indices_u3.sql` y repetir las mediciones.
6. Ejecutar `sql/views.sql`.

## Consultas de verificación

```sql
SELECT * FROM vw_productos_vigentes ORDER BY categoria, producto;
SELECT * FROM vw_pedidos_cliente ORDER BY pedido_id;
SELECT * FROM vw_detalle_pedido ORDER BY pedido_id, producto_id;
SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes, categoria_id;
```

Para actualizar el reporte:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
```

El refresh concurrente requiere que exista el índice único creado en
`sql/views.sql` y que la vista materializada ya tenga datos.

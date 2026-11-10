# TP Unidad 4 - FNBC y desnormalización controlada

El trabajo continúa el esquema vigente `sql/schema_completo.sql` de Food Store.
La extensión de lotes queda aislada en el esquema `tp_u4`; la optimización del
top de categorías modifica `detalle_pedido` de la **copia de prueba**.

## Archivos para entregar

1. `sql/tp_fnbc_control_lote.sql`: instancia original, descomposición FNBC,
   migración, vista de compatibilidad y prueba de equivalencia.
2. `sql/tp_desnormalizacion_top_categorias.sql`: consulta original adaptada,
   columnas precalculadas, triggers de sincronización, índice, consulta nueva,
   EXPLAIN y auditoría.
3. `../output/pdf/TP_U4_FNBC_Desnormalizacion_FoodStore_Entregable.pdf`:
   demostración formal, anomalías, planes y mediciones.

`documentacion/evidencia_u4.md` guarda los resultados legibles de la prueba.

## Cómo ejecutar en PostgreSQL 16+

Trabajar en una copia poblada de Food Store. Si se parte de una base vacía,
ejecutar primero `\i setup_tpi.sql`, cargar volumen de prueba y correr `ANALYZE`.
Luego, desde esta carpeta en `psql`:

```sql
\i sql/tp_fnbc_control_lote.sql
\i sql/tp_desnormalizacion_top_categorias.sql
```

El segundo script muestra `EXPLAIN (ANALYZE, BUFFERS)` antes y después. El
último SELECT es la auditoría y debe devolver **cero filas**. La primera parte
también contiene un `EXCEPT ALL` bidireccional que debe devolver cero filas.

La consulta del enunciado usa `dp.subtotal`, `dp.eliminado`, `ped.eliminado` y
`ped.fecha = CURRENT_DATE`. Esas columnas no existen en el esquema vigente y
`fecha` es `TIMESTAMPTZ`; el script calcula `cantidad * precio_unitario`, usa un
rango de día en la zona `America/Argentina/Buenos_Aires` y conserva todas las
ventas históricas. Producto y categoría sí tienen `activo` para el catálogo,
pero el reporte de ventas de la consigna no filtra esos estados.

La medición publicada corresponde a una copia local con PostgreSQL 18.3
embebido mediante PGlite. Sus tiempos demuestran el contraste en ese entorno;
no se presentan como tiempos de Railway.


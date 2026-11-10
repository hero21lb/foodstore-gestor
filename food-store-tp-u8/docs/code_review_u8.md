# U8 - Code review con IA

**Herramienta:** OpenCode, agente Plan.
**Alcance:** scripts SQL de las unidades 1 a 8 y sus informes.
**Método:** leer el script, ejecutarlo o consultar el catálogo del motor, y
registrar la evidencia. No se aceptó ningún hallazgo sin comprobarlo.

## Prompt utilizado

> "Revisá todos los scripts SQL de la cursada. Buscá errores de ejecución,
> redundancias, riesgos de integridad y contradicciones con los informes.
> Devolvé una tabla con hallazgo, unidad, evidencia, decisión
> (aceptado/corregido/descartado) y motivo. Verificá cada hallazgo en la base."

## Hallazgos

| # | Unidad | Hallazgo | Evidencia | Decisión | Motivo |
|---|---|---|---|---|---|
| H-01 | U2 | `setup_tpi.sql` aplica `restricciones_tp2.sql` y después `carga_masiva.sql` genera precios históricos aleatorios; el trigger de 1.5x rechaza la carga. | Ejecución real: `ERROR: precio_unitario 4482.56 supera 1.5x el precio de lista del producto 15`. | **Aceptado** | El flujo documentado no es reproducible. Se documenta y se evita en U8; la corrección sería generar el precio desde `producto.precio` o deshabilitar el trigger dentro de la transacción de carga. |
| H-02 | U3 | `indices.sql` e `indices_u3.sql` crean índices duplicados sobre las mismas columnas. | `pg_indexes`: `idx_pedido_fecha` y `idx_pedido_fecha_u3` sobre `pedido(fecha)`; `idx_detalle_producto` y `idx_detalle_pedido_producto_u3` sobre `detalle_pedido(producto_id)`. | **Corregido** | Se eliminaron los dos duplicados exactos en el laboratorio con `sql/u8/correccion_indices.sql`; no se toca el entregable histórico de U3. |
| H-03 | U3 | `mv_facturacion_categoria_mes` filtra `p.activo` y `c.activo` en un reporte histórico: al dar de baja un producto, sus ventas desaparecen del total. | Prueba: total 14.700,00 -> 8.500,00 al desactivar producto 1 -> 4.000,00 al desactivar categoría 1; la facturación real en `detalle_pedido` sigue siendo 14.700,00. | **Aceptado** | El reporte de ventas no debería filtrar estados del catálogo. Se documenta; la corrección sería quitar esos filtros de la vista materializada (o separar catálogo de facturación). |
| H-04 | U3/U4 | `date_trunc('month', pe.fecha)::date` depende de `TimeZone` de la sesión. | `2026-02-28 23:30-03` cae en febrero con `America/Argentina/Buenos_Aires` y en marzo con `UTC`. | **Aceptado** | Un reporte mensual debe fijar la zona de negocio. U8 usa `now() AT TIME ZONE 'America/Argentina/Buenos_Aires'` para la fecha de copia. |
| H-05 | U3 | Agregar un índice nuevo sobre `pedido(cliente_id)`. | `pg_indexes`: ya existe `idx_pedido_cliente` sobre `pedido(cliente_id)`. | **Descartado** | Sería un duplicado exacto: solo agregaría espacio y costo de escritura. |
| H-06 | U1 | `restricciones_tp2.sql` dice "reemplaza" el CHECK de cantidad, pero el CHECK original queda con otro nombre. | `pg_constraint`: conviven `detalle_pedido_cantidad_check` (`cantidad > 0`) y `chk_detalle_cantidad_rango` (`1..20`). | **Aceptado** | No rompe la integridad (el rango 1..20 es más estricto), pero el script no hace lo que declara. Se documenta para no repetir el error. |

## Cómo se comprobó

- **H-01:** ejecución de `setup_tpi.sql` + `carga_masiva.sql` en un PostgreSQL
  embebido; el error se reproduce de forma determinista.
- **H-02:** consulta a `pg_indexes` antes y después de
  `sql/u8/correccion_indices.sql`; la salida está en
  `u8/resultados/correccion_indices.txt`.
- **H-03:** prueba transaccional sobre la vista materializada: se desactiva un
  producto y una categoría, se refresca y se compara contra la facturación real
  de `detalle_pedido`.
- **H-04:** dos sesiones con `SET TIME ZONE` distinto y la misma fecha
  `timestamptz`; la salida está en `u8/resultados/code_review_pg.txt`.
- **H-05:** `pg_indexes` confirma el índice existente; no se crea nada.
- **H-06:** `pg_constraint` muestra las dos restricciones conviviendo.

## Conclusión

El review encontró dos problemas que afectan la reproducibilidad (H-01 y H-02),
dos decisiones de reporte que cambian el significado del dato (H-03 y H-04), una
propuesta descartada por sobreindexación (H-05) y una imprecisión de
documentación (H-06). H-02 se corrigió en el laboratorio; el resto queda
documentado para la defensa.

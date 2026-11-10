# U4 - Design

## Parte 1 - FNBC

La relación original tiene dos claves candidatas: `(LoteID, DepositoID)` y
`(LoteID, ResponsableControlID)`. La dependencia `ResponsableControlID ->
DepositoID` viola FNBC porque su determinante no es superclave.

Descomposición:

- `R1(ResponsableControlID, DepositoID)` con PK en el responsable.
- `R2(LoteID, ResponsableControlID)` con PK compuesta.
- La vista `vw_control_lote_almacen` reúne `R2 JOIN R1 USING
  (ResponsableControlID)`.

La dependencia `(LoteID, DepositoID) -> ResponsableControlID` no se preserva solo
con las proyecciones; un trigger con advisory lock por lote impide dos
responsables para el mismo lote/depósito. El cambio de depósito de un responsable
con controles también se bloquea.

## Parte 2 - Desnormalización

Se agregan a `detalle_pedido`:

- `fecha_venta_u4` (día de negocio en `America/Argentina/Buenos_Aires`).
- `categoria_id_u4` y `categoria_nombre_u4`.
- `subtotal_u4`.

Backfill transaccional, luego `SET NOT NULL`. Triggers:

- `BEFORE INSERT/UPDATE OF cantidad, precio_unitario, pedido_id, producto_id`
  recalcula la línea.
- `AFTER UPDATE OF fecha` en `pedido` propaga el día.
- `AFTER UPDATE OF categoria_id` en `producto` y `AFTER UPDATE OF nombre` en
  `categoria` propagan la categoría.

Índice `idx_detalle_top_categorias_u4 (fecha_venta_u4, categoria_id_u4)
INCLUDE (categoria_nombre_u4, subtotal_u4)`.

Reversión: `DROP INDEX`, `DROP TRIGGER/FUNCTION` y `ALTER TABLE ... DROP COLUMN`
de los cuatro campos. Las columnas base nunca se eliminan.

## Pruebas

- `EXCEPT ALL` bidireccional: 0 filas.
- Vista reconstruye `(501,30,801)`, `(502,30,801)`, `(503,31,802)`.
- Segundo responsable del lote 501/depósito 30: rechazado.
- Consulta top 5: 14,440 ms -> 1,280 ms (captura) y mediana 14,576 -> 1,230 ms
  en PGlite 18.3; no se extrapola a Railway.
- Auditoría de las cuatro columnas: 0 diferencias después del backfill y tras
  cambiar cantidad, fecha, categoría y nombre en una transacción revertida.

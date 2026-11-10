# U4 - Revisión humana y eliminación lógica

**Responsable:** Lemus Nahuel
**Fecha de revisión:** 10/11/2026

## Decisión sobre FNBC

Se acepta la descomposición `R1(ResponsableControlID, DepositoID)` +
`R2(LoteID, ResponsableControlID)` porque elimina la dependencia `R -> D` que
viola FNBC y la vista reconstruye las tuplas originales. Se descarta dejar la
relación original con un trigger que solo “oculte” la anomalía.

## Decisión sobre desnormalización

Se aceptan las columnas precalculadas y los triggers porque la consulta del top
de categorías es frecuente y la medición muestra una mejora de lectura. Se
descarta guardar `subtotal` en la tabla base sin trigger: sería una redundancia
sin salvaguarda.

## Eliminación lógica

La consigna de U4 usa `dp.eliminado` y `ped.eliminado`; el esquema Food Store
vigente no tiene esas columnas (usa `producto.activo` y `categoria.activo`). Por
eso el script adapta la consulta con `cantidad * precio_unitario` y conserva
todas las ventas históricas. Si se incorpora `eliminado`, el filtro debe
aplicarse tanto a la consulta original como a la desnormalizada, y la auditoría
debe cubrirlo. **No se inventó una columna ni se filtraron ventas históricas**
para hacer coincidir el resultado con la consigna.

## Reversión

`DROP INDEX`, `DROP TRIGGER/FUNCTION` y `ALTER TABLE ... DROP COLUMN` de los
cuatro campos `_u4`; las columnas base y las ventas no se eliminan.

Firma: ______________________________

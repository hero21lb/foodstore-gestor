# U4 - Requirements (Kiro, EARS)

## REQ-01 - Descomposición sin pérdida

**WHEN** la relación `R(LoteID, DepositoID, ResponsableControlID)` tiene la
dependencia `ResponsableControlID -> DepositoID`
**THE SYSTEM SHALL** descomponerla en `R1(ResponsableControlID, DepositoID)` y
`R2(LoteID, ResponsableControlID)` sin pérdida de información.

**Caso:** la vista de compatibilidad debe reconstruir exactamente las tres tuplas
originales y el `EXCEPT ALL` bidireccional debe devolver cero filas.

## REQ-02 - Migración reversible

**WHEN** se migran los datos a la descomposición
**THE SYSTEM SHALL** ejecutarlo dentro de una transacción y abortar si un
responsable aparece en más de un depósito.

**Caso:** el bloque `DO` de `tp_fnbc_control_lote.sql`; el intento de asignar un
segundo responsable al mismo lote/depósito debe fallar por trigger.

## REQ-03 - Desnormalización controlada

**WHEN** se consulta el top de categorías del día
**THE SYSTEM SHALL** leer columnas precalculadas en `detalle_pedido`
(`fecha_venta_u4`, `categoria_id_u4`, `categoria_nombre_u4`, `subtotal_u4`)
sincronizadas por triggers.

**Caso:** la consulta nueva debe devolver el mismo top 5 que la consulta de
cuatro tablas, con un plan de índice por fecha.

## REQ-04 - Auditoría de equivalencia

**WHEN** se ejecuta la auditoría después del backfill o de un cambio de fuente
**THE SYSTEM SHALL** devolver cero filas de diferencia entre las columnas
precalculadas y las tablas fuente.

**Caso:** ver `food-store-tp-u4/docs/evidencia_u4.md` y la consulta final de
`tp_desnormalizacion_top_categorias.sql`.

# U8 - Bitácora de IA y DUIA

## Declaración de Uso de IA (DUIA)

La IA se usó como apoyo para especificar, generar una primera versión de los
scripts, revisar la cursada y redactar pruebas. Cada script se leyó, se ejecutó
y se corrigió antes de incluirlo. Las decisiones de negocio (qué viaja, qué
decide el servidor, cuándo una solicitud es roja) son del equipo.

No se enviaron contraseñas, mails, celulares ni filas reales a la IA. Los
ejemplos usan únicamente datos inventados de la feria.

## Entrada 1 - Revisión de scripts de la cursada

**Herramienta:** OpenCode, agente Plan.

**Prompt:** "Revisá todos los scripts SQL de las unidades 1 a 8. Buscá errores
de ejecución, redundancias, riesgos de integridad y contradicciones con los
informes. Devolvé una tabla con hallazgo, unidad, evidencia, decisión
(aceptado/corregido/descartado) y motivo. Verificá cada hallazgo en la base."

**Qué propuso:** cinco hallazgos, entre ellos los índices duplicados de U3, el
choque entre `carga_masiva.sql` y el trigger de precio de TP2, el filtro
`activo` en la facturación histórica y la dependencia de zona horaria del mes.
También propuso descartar un índice nuevo sobre `pedido(cliente_id)`.

**Qué se aceptó:** los hallazgos de índices, carga masiva, facturación,
zona horaria y restricción de cantidad. **Qué se descartó:** crear el índice
`pedido(cliente_id)`, porque `idx_pedido_cliente` ya existe.

**Verificación:** las consultas y resultados están en
`u8/resultados/code_review_pg.txt` y en `documentacion/u8/code_review_u8.md`.

## Entrada 2 - Esquema SQLite y semáforo

**Herramienta:** OpenCode, modo Build.

**Prompt:** "Generá `schema_sqlite.sql` para las cuatro tablas de la consigna,
todas STRICT, con FK y CHECK. Después generá `semaforo.sql` que evalúe solo
solicitudes PENDIENTE y asigne RECHAZADO / CONFLICTO / SIMULADO_APROBADO con
prioridad rojo > amarillo > verde. La tablet no escribe en PostgreSQL."

**Qué propuso:** esquema con `id_local` y `solicitud_uuid` como TEXT, cola con
cuatro estados y un `UPDATE ... FROM` con `CASE`.

**Qué se corrigió:**

1. El primer `carga_snapshot.sql` usaba `INSERT ... SELECT ... ON CONFLICT`
   sin `WHERE true`; SQLite lo interpretaba como un JOIN y fallaba con
   `Parse error near "DO"`. Se agregó `WHERE true` y se volvió a probar.
2. El semáforo inicial comparaba los booleanos del CSV como enteros. En el CSV
   de `psql` llegan `t`/`f`; se agregó `lower(trim(...)) IN ('t','true','1')`
   y se probó C3/C4.
3. El motivo inicial era un texto fijo. Se cambió por un detalle por ítem
   (producto, cantidad, stock, precio visto/actual) para que C2/C3/C4 sean
   explicables.

**Verificación:** `u8/resultados/evidencia_u8.txt`, secciones 2 a 6.

## Entrada 3 - Especificación Kiro

**Herramienta:** Kiro (spec) + revisión manual.

**Prompt:** "Escribí cuatro requisitos EARS para la tablet: catálogo offline,
conflicto de precio, rechazo por stock/baja y aprobación simulada idempotente.
Cada uno con su caso C1-C6 y criterio de aceptación. Después un design.md con
arquitectura, esquema, semáforo y decisiones."

**Qué se aceptó:** los cuatro requisitos y la arquitectura de snapshot CSV +
SQLite + semáforo local.

**Qué se ajustó:** se separó la idempotencia de C6 en REQ-04 y se agregó la
condición "no reevaluar filas que ya no están PENDIENTE". También se explicitó
que `SIMULADO_APROBADO` no es una venta.

**Verificación:** `documentacion/u8/requirements.md`, `design.md`, `tasks.md`
y los casos en `u8/resultados/evidencia_u8.txt`.

## Entrada 4 - Instantánea y CSV

**Herramienta:** OpenCode, modo Build.

**Prompt:** "Definí `v_snapshot_movil` con las columnas mínimas de la tablet y
exportá a CSV. Cuidá que los booleanos de psql salgan como t/f y que la fecha
de copia sea la del negocio, no la de la sesión."

**Qué se aceptó:** vista con `precio_centavos` entero, `disponible`,
`eliminado` y `fecha_copia` fijada a `America/Argentina/Buenos_Aires`.

**Qué se descartó:** exportar con `SELECT *` de `producto`, porque arrastraba
columnas internas y no dejaba explícito qué viaja.

**Verificación:** `u8/servidor_snapshot.csv` y `u8/snapshots/caso_c2.csv`,
`caso_c3.csv`, `caso_c4.csv`.

## Resumen de decisiones

| Pregunta | Respuesta |
|---|---|
| ¿Qué herramienta se usó? | OpenCode (Plan y Build) para revisión y generación; Kiro para el spec; `sqlite3` y PostgreSQL para verificar. |
| ¿Qué se aceptó? | El esquema STRICT, el semáforo por prioridad y los cuatro requisitos. |
| ¿Qué se corrigió? | El `ON CONFLICT` de SQLite, la normalización `t/f` y el detalle de `motivo`. |
| ¿Qué se descartó? | El índice redundante `pedido(cliente_id)` y el `SELECT *` para el CSV. |
| ¿Cómo se verificó? | Cada caso se ejecutó y su salida quedó en `u8/resultados/evidencia_u8.txt`. |

# DUIA consolidada - TPI Food Store (U4 a U8)

La IA se usó como apoyo para especificar, generar una primera versión, revisar y
redactar pruebas. Cada script se leyó, se ejecutó sobre una copia o transacción
reversible y se corrigió antes de incluirlo. Las decisiones de negocio y la
aprobación final son del equipo.

No se enviaron contraseñas, hashes, mails, celulares ni filas reales a la IA. Los
ejemplos usan datos sintéticos.

## Resumen por unidad

| Unidad | Herramienta | Qué se pidió | Aceptado / corregido / descartado | Evidencia |
|---|---|---|---|---|
| U4 | OpenCode / Kiro (spec) | Descomponer FNBC, migrar sin pérdida, desnormalizar el top de categorías. | Aceptado el esquema R1/R2 y los triggers. Descartado guardar `subtotal` en la tabla base sin trigger. | `food-store-tp-u4/specs/`, `docs/evidencia_u4.md` |
| U5 | Codex / OpenCode | Roles de mínimo privilegio, autenticación bcrypt, auditoría y simulacro. | Aceptado el esquema. Corregido: quitar `CREATEDB/CREATEROLE` y el acceso automático a tablas futuras. Descartado dar `CREATEROLE` a `admin_datos`. OpenCode falló HTTP 400; no se inventó auditoría. | `food-store-tp-u5/BITACORA.md`, `docs/opencode_auditoria.jsonl` |
| U6 | OpenCode | Plan de respaldo, restauración y mantenimiento. | Aceptado `pg_dump -Fc` + restore a base nueva. Descartado `VACUUM FULL` periódico. | `food-store-tp-u6/SPEC_U6.md`, `logs/restore_resultado.json` |
| U7 | Codex / MongoDB | Modelo documental de pedidos, consultas y comparación. | Aceptado un documento por pedido con líneas embebidas y `Decimal128`. Descartado duplicar todos los clientes y precios actuales. | `food-store-tp-u7/asistencia_ia.md`, `evidencias/verificacion.json` |
| U8 | OpenCode / Kiro (spec) | Esquema SQLite, snapshot y semáforo. | Aceptado STRICT + FK. Corregido `ON CONFLICT` (faltaba `WHERE true`) y la normalización `t/f`. Descartado `SELECT *` para el CSV. | `food-store-tp-u8/docs/duia_u8.md`, `u8/resultados/evidencia_u8.txt` |

## Decisiones humanas explícitas

| Pregunta | Decisión |
|---|---|
| ¿Se acepta la descomposición FNBC? | Sí: elimina la anomalía `R -> D` y la vista reconstruye sin pérdida. |
| ¿Se acepta la redundancia de U4? | Sí, con triggers y auditoría; el costo de escritura se asume por la mejora de lectura. |
| ¿Se acepta el esquema de roles U5? | Sí: mínimo privilegio, sin lectura de hashes y sin `CREATEROLE`. |
| ¿Se acepta el intento de auditoría de OpenCode? | No: falló con HTTP 400; se registra el error y no se reemplaza por una respuesta inventada. |
| ¿Se acepta el respaldo/restore U6? | Sí: conteos y `md5` coinciden, RTO 32,224 s. |
| ¿Se acepta el modelo documental U7? | Sí: mismos IDs y consultas equivalentes; PostgreSQL sigue siendo la fuente de la venta. |
| ¿Se acepta la tablet U8? | Sí: semáforo local, sin escrituras al servidor; `SIMULADO_APROBADO` no es una venta. |

## Declaración

Declaramos que las herramientas de IA utilizadas y sus propuestas están
registradas en las bitácoras de cada unidad. Las decisiones finales, las
correcciones y los descartes son responsabilidad del equipo. No se atribuye a
OpenCode ni a Kiro un trabajo que no esté respaldado por una salida o un archivo
verificable.

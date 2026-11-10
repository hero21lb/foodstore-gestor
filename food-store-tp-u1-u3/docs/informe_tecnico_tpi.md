# Informe técnico - TPI Food Store, primera entrega parcial

## Motor y entorno

El proyecto se ejecuta sobre PostgreSQL 16+ con PL/pgSQL. La instancia de
Railway se utiliza como entorno remoto de prueba; debe verificarse con
`SHOW server_version;` antes de la entrega.

## Cobertura por unidad

| Unidad | Implementado | Evidencia |
|---|---|---|
| 1 | Integridad, transacciones y concurrencia | `sql/restricciones_tp2.sql`, `documentacion/informe_concurrencia.md`, `documentacion/protocolo_seguridad.md` |
| 2 | Carga masiva, consultas y optimización | `sql/carga_masiva.sql`, `sql/queries.sql`, `sql/indices.sql` |
| 3 | Índices, vistas y vista materializada | `sql/indices_u3.sql`, `sql/views.sql`, `documentacion/informe_mediciones.md` |
| TPI | Función, procedimiento JSONB, trigger de transición y ventanas | `sql/objetos_programables_tpi.sql`, `sql/consultas_tpi.sql` |

## Cómo se prueba

1. Ejecutar `setup_tpi.sql`, que incluye los scripts de `sql/` en orden.
2. Correr las consultas de `sql/consultas_tpi.sql`.
3. Probar el procedimiento dentro de `BEGIN; ... ROLLBACK;` con `CALL
   sp_registrar_pedido(...)` y verificar el pedido creado y `fn_total_pedido`.
4. Actualizar stock de dos productos y consultar `auditoria_stock` para verificar
   el trigger con tablas de transición y el contenido JSONB.
5. Ejecutar `EXPLAIN (ANALYZE, BUFFERS)` antes y después de `sql/indices_u3.sql`.

## Resultados obtenidos

La carga de prueba en Railway incorporó 20.000 pedidos y 20.000 detalles. Luego
de crear los índices se observó Bitmap Index Scan para fecha y producto, e Index
Scan para el catálogo ordenado. La vista materializada resumió 260 filas de
facturación por categoría y mes.

## IA utilizada

Se usó IA para interpretar consignas, redactar especificaciones, proponer SQL y
revisar planes de ejecución. Las decisiones aceptadas se documentan en
`documentacion/duia.md`; se descartó un índice redundante sobre `pedido(cliente_id)` porque ya
existe `idx_pedido_cliente`.

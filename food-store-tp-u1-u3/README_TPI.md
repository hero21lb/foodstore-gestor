# TPI Food Store - primera entrega parcial

## Requisito del motor

PostgreSQL 16+ con PL/pgSQL. Verificar antes de ejecutar:

```sql
SHOW server_version;
SELECT extname FROM pg_extension WHERE extname = 'plpgsql';
```

Railway es válido como infraestructura si la instancia cumple esa versión. La
base se accede desde su consola integrada o mediante `psql` usando las variables
de conexión entregadas por Railway.

## Instalación

En una base vacía, desde `psql` y ubicado en esta carpeta:

```sql
\i setup_tpi.sql
```

Para una medición representativa, ejecutar también `sql/carga_masiva.sql` antes de
`ANALYZE` y de las mediciones de índices.

## Mapa de evidencias

| Objetivo | Archivo principal |
|---|---|
| ER, cardinalidad y participación | `documentacion/parte1_modelo_er.txt`, `diagramas/foodstore_er_chen.svg` |
| Modelo relacional y normalización | `sql/schema_completo.sql`, `documentacion/normalizacion_tpi.md` |
| DDL, PK, FK, tipos y restricciones | `sql/schema_completo.sql`, `sql/restricciones_tp2.sql` |
| DML, JOIN, agregación, subconsulta y ventanas | `sql/queries.sql`, `sql/consultas_tpi.sql` |
| Índices y mediciones | `sql/indices.sql`, `sql/indices_u3.sql`, `documentacion/informe_mediciones.md` |
| Vistas y materializada | `sql/views.sql` |
| Función, procedimiento, JSONB y trigger | `sql/objetos_programables_tpi.sql` |
| Transacciones y concurrencia | `documentacion/protocolo_seguridad.md`, `documentacion/informe_concurrencia.md` |
| Soft delete | `sql/schema_completo.sql`, `sql/queries.sql`, `sql/indices_u3.sql` |
| Informe técnico y DUIA | `documentacion/informe_tecnico_tpi.md`, `documentacion/duia.md` |

## Pruebas mínimas

```sql
BEGIN;
CALL sp_registrar_pedido(
  1,
  'EFECTIVO',
  '[{"producto_id": 1, "cantidad": 2}, {"producto_id": 2, "cantidad": 1}]'::jsonb,
  NULL
);
SELECT fn_total_pedido((SELECT max(id) FROM pedido));
UPDATE producto SET stock = stock - 1 WHERE id IN (1, 2);
SELECT * FROM auditoria_stock ORDER BY id DESC LIMIT 1;
ROLLBACK;

SELECT * FROM vw_productos_vigentes;
SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes, categoria_id;
\i sql/consultas_tpi.sql
```

La transacción de prueba termina en `ROLLBACK` para demostrar atomicidad y no
dejar datos de ensayo persistidos.

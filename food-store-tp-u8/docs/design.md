# U8 - Design

## Arquitectura

```text
PostgreSQL 18.6 (foodstore_u8_lab)
  producto, pedido, detalle_pedido, cliente
        |
        | v_snapshot_movil -> CSV (solo catálogo)
        v
SQLite 3.54 (tablet_u8.db)
  snapshot_servidor -> producto_cache
  pedido_borrador + item_borrador
  cola_sync (PENDIENTE -> estado)
        |
        | simulación local, sin escrituras al servidor
        v
  SIMULADO_APROBADO / CONFLICTO / RECHAZADO
```

No hay canal de escritura de la tablet hacia PostgreSQL en este trabajo. La
sincronización se simula: la tablet produce una solicitud y el servidor, en un
sistema real, la validaría y confirmaría. Acá el semáforo solo clasifica.

## Por qué estos datos viajan

| Viaja | No viaja | Motivo |
|---|---|---|
| `id`, `nombre` | `cliente`, `mail`, `celular` | La tablet solo necesita identificar el producto; no debe llevar datos personales. |
| `precio_centavos` | `precio` como decimal | Entero en centavos evita ambigüedad de punto flotante y redondeo. |
| `stock_visto` | stock autoritativo del servidor | La tablet muestra una foto; no reserva ni descuenta. |
| `disponible`, `eliminado` | ventas, pedidos confirmados | La baja lógica se representa con una lápida, no con un borrado local. |
| `fecha_copia` | usuarios/roles/credenciales | Permite saber si la foto está vieja; no expone seguridad. |

PostgreSQL sigue siendo la fuente de verdad de precio, stock, pedidos y ventas.
La tablet nunca decide esos valores.

## Esquema SQLite

- `producto_cache`: `STRICT`, precio entero no negativo, `disponible` y
  `eliminado` restringidos a 0/1, `fecha_copia` de 10 caracteres.
- `pedido_borrador`: UUID local como PK, forma de pago restringida al dominio
  cerrado, fecha ISO-8601.
- `item_borrador`: PK compuesta `(id_local, producto_id)`, FK a borrador y a
  caché, cantidad `> 0`, precio visto no negativo.
- `cola_sync`: UUID de solicitud como PK, estado restringido a los cuatro
  valores, FK al borrador.
- `snapshot_servidor`: foto cruda del CSV. Los booleanos de `psql` llegan como
  `t`/`f`; se normalizan al cargar `producto_cache`.
- `vw_catalogo_disponible`: vista de lectura del catálogo operativo.

`PRAGMA foreign_keys = ON` se declara al inicio del esquema y en cada script que
inserta datos. SQLite lo aplica por conexión.

## Semáforo

El script `semaforo.sql`:

1. Rechaza borradores sin ítems.
2. Toma solo `cola_sync.estado = 'PENDIENTE'`.
3. Une cada ítem con `snapshot_servidor` por `producto_id`.
4. Calcula un problema rojo por ítem, en este orden:
   inexistente -> dado de baja -> no disponible -> stock insuficiente.
5. Calcula un cambio de precio solo si no hay rojo.
6. Agrupa por solicitud y actualiza una sola vez:
   - `RECHAZADO` si hay al menos un rojo;
   - `CONFLICTO` si no hay rojo pero hay precio distinto;
   - `SIMULADO_APROBADO` si todo coincide.
7. No reevalúa filas que ya no están `PENDIENTE`.

El `motivo` guarda el detalle (producto, cantidad pedida, stock disponible,
precio visto y actual) para que la revisión humana no tenga que adivinar.

## Idempotencia

- `solicitud_uuid` es PK: reenviar el mismo UUID falla y no duplica.
- El semáforo solo evalúa `PENDIENTE`: repetir la simulación no cambia un
  resultado ya calculado.
- La carga de instantánea es idempotente: `ON CONFLICT (id) DO UPDATE` y
  marcado de lápida para filas que ya no están en el CSV.

## Seguridad y privacidad

- No viajan mails, celulares, usuarios ni hashes.
- El CSV se genera desde una vista de columnas explícitas, no con `SELECT *`
  sobre las tablas base.
- La tablet no tiene credenciales de PostgreSQL.
- El laboratorio usa una base nueva (`foodstore_u8_lab`) y datos inventados.
- `railway` y `foodstore` no se tocan.

## Decisiones y alternativas

| Decisión | Alternativa descartada | Motivo |
|---|---|---|
| Precio en centavos `INTEGER` | `REAL` o texto | Evita errores de punto flotante y comparaciones frágiles. |
| `STRICT` en todas las tablas | SQLite flexible | Fuerza tipos y detecta cargas mal formadas. |
| Lápida (`eliminado = 1`) | Borrar la fila local | Conserva trazabilidad y permite explicar C4. |
| Semáforo en SQLite con `UPDATE ... FROM` | Script Python | La consigna permite SQL puro y queda reproducible con `sqlite3`. |
| Snapshot por CSV | Replicación o API | Es el mecanismo pedido y no requiere red en la tablet. |
| No escribir en PostgreSQL | Confirmar venta desde la tablet | Viola la regla de oro y el servidor debe validar stock/precio. |

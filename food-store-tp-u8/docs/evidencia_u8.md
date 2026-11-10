# U8 - Evidencia de ejecución

**Entorno:** PostgreSQL 18.6 en Railway, base de pruebas `foodstore_u8_lab`;
SQLite 3.54.0; fecha de ejecución 2026-11-10.
**Regla respetada:** no se modificó `railway` ni `foodstore`. La tablet no
ejecutó escrituras sobre PostgreSQL.

La salida completa está en `u8/resultados/evidencia_u8.txt`. Los archivos
`u8/servidor_snapshot.csv` y `u8/snapshots/caso_c*.csv` son las instantáneas
usadas.

## 1.a Qué datos viajan

| Viaja a la tablet | No viaja | Por qué |
|---|---|---|
| `producto_id`, `nombre` | `cliente`, `mail`, `celular` | La tablet solo necesita identificar el producto; no debe llevar datos personales. |
| `precio_centavos` entero | `precio` decimal interno | Un entero en centavos evita ambigüedad de redondeo. |
| `stock_visto` | stock autoritativo | Es una foto; la tablet no reserva ni descuenta. |
| `disponible`, `eliminado` | ventas/pedidos confirmados | La baja lógica se representa con lápida; la venta la decide el servidor. |
| `fecha_copia` | usuarios, roles, hashes | Permite detectar una foto vieja sin exponer seguridad. |

PostgreSQL es la fuente de verdad de precio, stock, pedidos y ventas. SQLite
solo propone borradores y clasifica solicitudes.

## 1.b Las tablas

`schema_sqlite.sql` empieza con `PRAGMA foreign_keys = ON;` y crea:

| Tabla | Claves y reglas |
|---|---|
| `producto_cache` | PK `id`; `precio_centavos >= 0`; `stock_visto >= 0`; `disponible` y `eliminado` en 0/1; `fecha_copia` de 10 caracteres. |
| `pedido_borrador` | PK `id_local` UUID de 36 caracteres; `forma_pago` en EFECTIVO/TARJETA/TRANSFERENCIA. |
| `item_borrador` | PK `(id_local, producto_id)`; FK a borrador y a caché; `cantidad > 0`; precio visto no negativo. |
| `cola_sync` | PK `solicitud_uuid`; FK al borrador; estado en PENDIENTE/CONFLICTO/RECHAZADO/SIMULADO_APROBADO. |

Además: `snapshot_servidor` para el CSV crudo y `vw_catalogo_disponible` para
C1. Las cuatro tablas de la consigna son `STRICT`.

## 1.c Pruebas

### Borrador completo y ROLLBACK

```sql
BEGIN;
INSERT INTO pedido_borrador ...;   -- 1 fila
INSERT INTO item_borrador ...;      -- 1 fila
INSERT INTO cola_sync ...;          -- 1 fila
COMMIT;
```

Resultado: `borrador|1`, `items|1`, `solicitud|1`.
La segunda operación termina en `ROLLBACK` y devuelve `0` en las tres tablas.

### C1 - catálogo disponible sin servidor

```sql
SELECT * FROM vw_catalogo_disponible;
```

```text
3|Coca 1.5L|80000|100
5|Limonada Feria|60000|30
1|Muzzarella|105000|40
2|Napolitana|150000|35
4|Pizza Feria|120000|15
```

La consulta solo lee `producto_cache`; no hay conexión a PostgreSQL.

### C7 - cantidad 0 y producto inexistente

```text
Intento con cantidad = 0:
Error near line 64: CHECK constraint failed: cantidad > 0

Intento con producto_id = 9999:
Error near line 69: FOREIGN KEY constraint failed

items_invalidos_guardados|0
```

Ningún intento dejó filas nuevas. La FK y el CHECK funcionan porque cada script
de inserción declara `PRAGMA foreign_keys = ON`.

## 2.a La instantánea

Vista creada en PostgreSQL:

```sql
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id AS producto_id,
       p.nombre,
       (p.precio * 100)::bigint AS precio_centavos,
       p.stock,
       (p.activo AND p.stock > 0) AS disponible,
       (NOT p.activo) AS eliminado,
       (now() AT TIME ZONE 'America/Argentina/Buenos_Aires')::date AS fecha_copia
FROM producto p;
```

Exportación:

```text
\copy (SELECT producto_id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia FROM v_snapshot_movil ORDER BY producto_id) TO 'servidor_snapshot.csv' CSV HEADER
```

CSV inicial (5 productos, fecha de copia 2026-11-10):

```text
producto_id,nombre,precio_centavos,stock,disponible,eliminado,fecha_copia
1,Muzzarella,105000,40,t,f,2026-11-10
2,Napolitana,150000,35,t,f,2026-11-10
3,Coca 1.5L,80000,100,t,f,2026-11-10
4,Pizza Feria,120000,15,t,f,2026-11-10
5,Limonada Feria,60000,30,t,f,2026-11-10
```

Importación en SQLite:

```text
sqlite3 tablet_u8.db
DELETE FROM snapshot_servidor;
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
.read sql/u8/carga_snapshot.sql
```

`carga_snapshot.sql` normaliza los booleanos `t`/`f` a 1/0 y actualiza las filas
existentes con `ON CONFLICT (id) DO UPDATE`. Resultado: `5|5` (5 productos en
caché, 5 disponibles).

## 2.b El semáforo

`sql/u8/semaforo.sql` evalúa únicamente `PENDIENTE` y actualiza `estado` y
`motivo`:

- **RECHAZADO:** producto inexistente, dado de baja, no disponible o stock
  insuficiente. Tiene prioridad sobre el precio.
- **CONFLICTO:** no hay rojo, pero algún `precio_centavos_visto` difiere del
  snapshot.
- **SIMULADO_APROBADO:** todos los ítems coinciden.

Repetir la simulación no cambia nada porque las filas ya no están `PENDIENTE`.

## 2.c Casos

### C2 - precio del servidor sube

Comando: `UPDATE producto SET precio = 1100.00 WHERE id = 1;`, nueva
instantánea `snapshots/caso_c2.csv`, recarga y semáforo.

Resultado:

```text
b2222222-... | CONFLICTO | Cambio de precio: producto 1 visto 105000, ahora 110000
```

El cliente acepta: se actualiza `item_borrador.precio_centavos_visto = 110000` y
se crea la solicitud `b2222222-...223`. La nueva da `SIMULADO_APROBADO`; la
anterior queda `CONFLICTO` como historial.

### C3 - stock insuficiente

Comando: `UPDATE producto SET stock = 2 WHERE id = 3;`, nueva instantánea y
semáforo.

```text
b3333333-... | RECHAZADO | stock insuficiente para producto 3 (pedido 5, disponible 2)
```

La tablet no descuenta stock; solo compara contra la foto.

### C4 - baja lógica

Comando: `UPDATE producto SET activo = false WHERE id = 2;`, nueva instantánea,
recarga y semáforo.

```text
b4444444-... | RECHAZADO | producto 2 dado de baja
```

Al recargar el catálogo, la fila sigue en la tablet pero no en la vista:

```text
2|Napolitana|150000|0|1|2026-11-10   -- producto_cache
productos_2_en_catalogo|0
fila_2_en_cache|1
```

### C5 - borrador sin cambios

```text
a1111111-... | SIMULADO_APROBADO | Sin diferencias contra la instantánea
```

### C6 - reenvío del mismo UUID

```text
Error near line 6: UNIQUE constraint failed: cola_sync.solicitud_uuid
a1111111-... | SIMULADO_APROBADO | Sin diferencias contra la instantánea
solicitudes|5
```

El UUID repetido no se duplica y la simulación no reevalúa la fila ya aprobada.
En un sistema real, la protección definitiva es la clave primaria/`UNIQUE` en el
servidor y una tabla de idempotencia por `solicitud_uuid` (parada 8).

### Control final en PostgreSQL

```text
pedidos           5
detalle_pedido    7
stock_total       220
md5_pedidos       10c2d0044f769bd188ebc2ce804dded9
md5_detalles      2d6cd57a2046238bcd08f46e3f0c8723
```

Comparación antes/después: `pedidos_iguales: true`, `detalles_iguales: true`,
`stock_igual: true`, ambos `md5` iguales. La tablet no creó pedidos ni movió
stock. Los cambios de precio, stock y baja de C2-C4 fueron fixtures del servidor
para preparar cada caso; el stock de C3 se restauró después de exportar su
instantánea para que el control final vuelva al baseline.

## 3. Integración

- **3.a Mapa de motores:** `documentacion/u8/mapa_motores.md`.
- **3.b Plan de mantenimiento:** `documentacion/u8/mantenimiento_u8.md`.
- **3.c Code review:** `documentacion/u8/code_review_u8.md`. Hallazgos H-01 a
  H-06, con H-02 corregido en el laboratorio y H-05 descartado.

## 4. Kiro, bitácora y defensa

- Spec: `documentacion/u8/requirements.md`, `design.md`, `tasks.md`.
- Bitácora y DUIA: `documentacion/u8/duia_u8.md`.
- README de reproducción: `README_U8.md`.
- Guion de defensa: `documentacion/u8/defensa_u8.md`.

# U8 - Food Store en la feria

Tablet SQLite + PostgreSQL de pruebas + sincronización simulada.
**Regla de oro:** el móvil propone, el servidor dispone. `SIMULADO_APROBADO`
no es una venta.

## Archivos

| Archivo | Qué contiene |
|---|---|
| `sql/u8/pg_u8_lab.sql` | Vista `v_snapshot_movil` y dos productos inventados. |
| `sql/u8/exportar_snapshot.sql` | `\copy` de la instantánea a CSV. |
| `sql/u8/schema_sqlite.sql` | Cuatro tablas `STRICT`, snapshot y vista de catálogo. |
| `sql/u8/carga_snapshot.sql` | Carga idempotente del CSV en `producto_cache`. |
| `sql/u8/pruebas_sqlite.sql` | Borrador COMMIT/ROLLBACK, C1 y C7. |
| `sql/u8/semaforo.sql` | Clasificación PENDIENTE -> estado + motivo. |
| `sql/u8/caso_c2a.sql`, `caso_c2b.sql` | Caso de cambio de precio. |
| `sql/u8/caso_c3.sql` | Caso de stock insuficiente. |
| `sql/u8/caso_c4.sql`, `consulta_c4.sql` | Caso de baja lógica. |
| `sql/u8/caso_c6.sql` | Reenvío del mismo UUID. |
| `sql/u8/pg_control.sql` | Control de pedidos y stock en PostgreSQL. |
| `sql/u8/correccion_indices.sql` | Corrección H-02 del code review. |
| `documentacion/u8/` | Requirements, design, tasks, DUIA, evidencia, mapa, mantenimiento, code review y defensa. |
| `u8/run_u8.mjs` | Runner automatizado usado para producir la evidencia. |
| `u8/resultados/evidencia_u8.txt` | Salida completa de los casos. |
| `u8/servidor_snapshot.csv` | Instantánea inicial. |
| `u8/snapshots/caso_c*.csv` | Instantáneas de C2, C3 y C4. |
| `u8/tablet_u8.db` | Base SQLite resultante. |

## Requisitos

- PostgreSQL 16+ con `psql`.
- SQLite 3.37+ con `sqlite3`.
- Una base de pruebas vacía. **No usar `railway` ni `foodstore`.**

## 1. PostgreSQL de pruebas

Crear una base nueva (ejemplo `foodstore_u8_lab`) y cargar el esquema Food Store:

```bash
createdb -h <host> -U postgres foodstore_u8_lab
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/schema_completo.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/data.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/restricciones_tp2.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/indices.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/indices_u3.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/views.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/objetos_programables_tpi.sql
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/u8/pg_u8_lab.sql
```

Alternativa: `\i setup_tpi.sql` desde esta carpeta y después
`\i sql/u8/pg_u8_lab.sql`.

## 2. Instantánea

Desde la carpeta `u8/`, conectado a `foodstore_u8_lab`:

```bash
psql -h <host> -U postgres -d foodstore_u8_lab -f ../sql/u8/exportar_snapshot.sql
```

Eso genera `servidor_snapshot.csv` con las columnas:
`producto_id,nombre,precio_centavos,stock,disponible,eliminado,fecha_copia`.

## 3. Tablet SQLite

Desde `u8/`:

```bash
sqlite3 tablet_u8.db < ../sql/u8/schema_sqlite.sql
sqlite3 tablet_u8.db "DELETE FROM snapshot_servidor;"
sqlite3 tablet_u8.db ".import --csv --skip 1 servidor_snapshot.csv snapshot_servidor"
sqlite3 tablet_u8.db < ../sql/u8/carga_snapshot.sql
```

## 4. Pruebas 1.c y C5

```bash
sqlite3 tablet_u8.db < ../sql/u8/pruebas_sqlite.sql
sqlite3 tablet_u8.db < ../sql/u8/semaforo.sql
```

`pruebas_sqlite.sql` muestra el borrador completo, el ROLLBACK, C1 y C7.
El semáforo deja C5 en `SIMULADO_APROBADO`.

## 5. Casos C2, C3, C4 y C6

Para cada caso: cambiar el dato en PostgreSQL, exportar una instantánea nueva a
`snapshots/caso_cN.csv`, importarla en SQLite, recargar la caché y correr el
semáforo.

### C2 - precio

```sql
UPDATE producto SET precio = 1100.00 WHERE id = 1;
```

```bash
psql ... -c "\copy (SELECT producto_id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia FROM v_snapshot_movil ORDER BY producto_id) TO 'snapshots/caso_c2.csv' CSV HEADER"
sqlite3 tablet_u8.db "DELETE FROM snapshot_servidor;"
sqlite3 tablet_u8.db ".import --csv --skip 1 snapshots/caso_c2.csv snapshot_servidor"
sqlite3 tablet_u8.db < ../sql/u8/carga_snapshot.sql
sqlite3 tablet_u8.db < ../sql/u8/caso_c2a.sql
sqlite3 tablet_u8.db < ../sql/u8/semaforo.sql
sqlite3 tablet_u8.db < ../sql/u8/caso_c2b.sql
sqlite3 tablet_u8.db < ../sql/u8/semaforo.sql
```

### C3 - stock

```sql
UPDATE producto SET stock = 2 WHERE id = 3;
```

Exportar a `snapshots/caso_c3.csv`, importar, recargar y ejecutar
`caso_c3.sql` + `semaforo.sql`. Después de exportar, restaurar el stock a 100
para el control final.

### C4 - baja lógica

```sql
UPDATE producto SET activo = false WHERE id = 2;
```

Exportar a `snapshots/caso_c4.csv`, importar, recargar y ejecutar
`caso_c4.sql`, `semaforo.sql` y `consulta_c4.sql`.

### C6 - idempotencia

```bash
sqlite3 tablet_u8.db < ../sql/u8/caso_c6.sql
sqlite3 tablet_u8.db < ../sql/u8/semaforo.sql
```

## 6. Control final en PostgreSQL

Desde esta carpeta (`bases de datos/`):

```bash
psql -h <host> -U postgres -d foodstore_u8_lab -f sql/u8/pg_control.sql
```

Debe devolver 5 pedidos, 7 detalles y stock 220, con los mismos `md5` que antes
de la simulación. La tablet no creó pedidos ni movió stock.

## 7. Runner automático (opcional)

`u8/run_u8.mjs` reproduce toda la secuencia y escribe
`u8/resultados/evidencia_u8.txt`. Requiere Node.js y el paquete `pg`.
No se incluye la URL con contraseña: se pasa por variable de entorno.

## 8. Railway

- El laboratorio usó una base nueva `foodstore_u8_lab`; `railway` y `foodstore`
  no se tocaron.
- Al terminar se elimina `foodstore_u8_lab` y se cierran las conexiones.
- El servicio PostgreSQL se redeployó solo para despertarlo. Si no se necesita,
  pausarlo desde el dashboard de Railway; no se borra el volumen.
- No se incluyen credenciales en este README ni en el paquete.

## 9. Orden de lectura para la defensa

1. `documentacion/u8/requirements.md` y `design.md`.
2. `documentacion/u8/evidencia_u8.md`.
3. `documentacion/u8/mapa_motores.md` y `mantenimiento_u8.md`.
4. `documentacion/u8/code_review_u8.md`.
5. `documentacion/u8/duia_u8.md` y `defensa_u8.md`.

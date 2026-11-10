# U8 - Requirements (Kiro, notación EARS)

Proyecto: Food Store en la feria. Tablet SQLite + PostgreSQL de pruebas.
Regla de oro: **el móvil propone, el servidor dispone**.

## Contexto y límites

- La tablet solo consulta el catálogo y arma borradores locales.
- La tablet no confirma ventas, no modifica precio ni stock del servidor.
- `SIMULADO_APROBADO` es un resultado de simulación, no una venta.
- PostgreSQL es la fuente de verdad de producto, precio, stock y pedidos.
- SQLite guarda una foto del catálogo, borradores y la cola de solicitudes.

## REQ-01 - Catálogo disponible sin conexión

**WHEN** la tablet no tiene conexión con PostgreSQL
**THE SYSTEM SHALL** mostrar el catálogo desde `producto_cache`, incluyendo solo
filas con `disponible = 1` y `eliminado = 0`.

**Caso de prueba:** C1. Se corta la conexión lógica (no se consulta PostgreSQL)
y `vw_catalogo_disponible` devuelve los productos vigentes de la última
instantánea.

**Criterio de aceptación:** la consulta no referencia ninguna tabla del
servidor; devuelve al menos un producto y no muestra productos dados de baja.

## REQ-02 - Conflicto por cambio de precio

**WHEN** una solicitud está `PENDIENTE`, ningún ítem tiene un problema rojo y el
precio visto de al menos un ítem difiere del precio de `snapshot_servidor`
**THE SYSTEM SHALL** marcar la solicitud como `CONFLICTO` y registrar en
`motivo` el precio visto y el precio actual.

**Caso de prueba:** C2. El servidor sube el precio de Muzzarella de 105000 a
110000 centavos; la tablet conserva el precio viejo en el borrador. El semáforo
marca `CONFLICTO`. Al aceptar el cliente, se actualiza el borrador y una
solicitud nueva da `SIMULADO_APROBADO`.

**Criterio de aceptación:** una sola fila de `cola_sync` cambia a `CONFLICTO`;
el motivo contiene ambos precios; PostgreSQL no recibe escrituras.

## REQ-03 - Rechazo por producto o stock

**WHEN** una solicitud está `PENDIENTE` y algún ítem referencia un producto
inexistente, dado de baja, no disponible o con stock menor a la cantidad pedida
**THE SYSTEM SHALL** marcar la solicitud como `RECHAZADO` y explicar el primer
problema detectado en `motivo`.

**Caso de prueba:** C3 (stock insuficiente: 5 unidades contra stock 2) y C4
(producto 2 dado de baja lógica). Ambos dan `RECHAZADO` con motivo legible.

**Criterio de aceptación:** el estado es `RECHAZADO`; no se crea ningún pedido
en PostgreSQL; en C4 la fila de `producto_cache` permanece con
`eliminado = 1`, pero el catálogo operativo no la muestra.

## REQ-04 - Aprobación simulada e idempotencia

**WHEN** una solicitud está `PENDIENTE` y todos sus ítems coinciden con la
instantánea en existencia, disponibilidad, stock y precio
**THE SYSTEM SHALL** marcarla como `SIMULADO_APROBADO`.
**WHEN** se reenvía el mismo `solicitud_uuid`
**THE SYSTEM SHALL** rechazar el duplicado por clave primaria y no reevaluar
solicitudes que ya no están `PENDIENTE`.

**Caso de prueba:** C5 (borrador sin cambios) y C6 (reenvío del mismo UUID).

**Criterio de aceptación:** C5 queda `SIMULADO_APROBADO`; C6 produce error de
`PRIMARY KEY`, el estado original no cambia y el conteo de solicitudes no crece.

## Trazabilidad

| Requisito | Script | Caso | Evidencia |
|---|---|---|---|
| REQ-01 | `sql/u8/schema_sqlite.sql`, `carga_snapshot.sql` | C1 | `u8/resultados/evidencia_u8.txt` |
| REQ-02 | `sql/u8/semaforo.sql` | C2 | `u8/resultados/evidencia_u8.txt` |
| REQ-03 | `sql/u8/semaforo.sql` | C3, C4 | `u8/resultados/evidencia_u8.txt` |
| REQ-04 | `sql/u8/semaforo.sql`, `caso_c6.sql` | C5, C6 | `u8/resultados/evidencia_u8.txt` |

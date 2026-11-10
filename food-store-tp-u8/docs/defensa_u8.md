# U8 - Guion de defensa (10 minutos)

## 0:00 - 1:00 | Apertura y mapa

"Food Store vende en una feria sin señal. La tablet no es un cliente de
PostgreSQL: es una foto del catálogo y una cola de propuestas. PostgreSQL sigue
siendo la fuente de verdad de precio, stock y ventas. MongoDB, de U7, aporta la
ficha ampliada del producto, pero no decide precio ni stock. SQLite guarda la
foto, los borradores y la cola. El móvil propone, el servidor dispone."

Mostrar `documentacion/u8/mapa_motores.md`.

## 1:00 - 3:00 | La base de la tablet

- Cuatro tablas `STRICT`: `producto_cache`, `pedido_borrador`, `item_borrador`,
  `cola_sync`.
- Precio en centavos, no decimal: comparaciones exactas.
- `PRAGMA foreign_keys = ON`; FK de ítem a borrador y a caché; CHECK de cantidad
  y de estado.
- Lo que no viaja: cliente, mail, celular, ventas, credenciales.
- C1: `SELECT * FROM vw_catalogo_disponible;` funciona sin PostgreSQL.
- C7: cantidad 0 da CHECK; producto 9999 da FK; ninguna fila nueva.

Frase para defender: "La tablet no puede equivocarse con el stock porque no lo
tiene: tiene `stock_visto`, una foto con fecha."

## 3:00 - 6:30 | Semáforo y casos en vivo

Mostrar el flujo: `snapshot_servidor` -> `producto_cache` -> borrador ->
`cola_sync PENDIENTE` -> `semaforo.sql`.

1. **C5 (verde):** borrador sin cambios -> `SIMULADO_APROBADO`.
2. **C2 (amarillo):** sube el precio en PostgreSQL, nueva instantánea ->
   `CONFLICTO` con "visto 105000, ahora 110000". Aceptar el precio y crear una
   solicitud nueva -> `SIMULADO_APROBADO`.
3. **C3 (rojo):** stock 2 y borrador por 5 -> `RECHAZADO` con "pedido 5,
   disponible 2".
4. **C4 (rojo):** baja lógica del producto 2 -> `RECHAZADO` "dado de baja"; la
   fila queda en `producto_cache` con `eliminado=1`, pero no aparece en el
   catálogo.
5. **C6 (idempotencia):** repetir el UUID -> error de PK; el estado no cambia y
   el conteo no crece.

Cerrar con la consulta de control: 5 pedidos, 7 detalles, stock 220, mismos
`md5`. "La tablet no creó ninguna venta."

## 6:30 - 8:30 | Code review

Mostrar un hallazgo aceptado y uno descartado:

- **H-02 (corregido):** `indices.sql` e `indices_u3.sql` duplicaban
  `pedido(fecha)` y `detalle_pedido(producto_id)`. Se comprobó con `pg_indexes`
  y se eliminaron los duplicados exactos en el laboratorio.
- **H-03 (aceptado):** la vista materializada de facturación filtraba
  `activo`; al dar de baja un producto, sus ventas históricas desaparecían.
  Prueba: 14.700 -> 8.500 -> 4.000, mientras la facturación real seguía en
  14.700.
- **H-05 (descartado):** agregar `pedido(cliente_id)` era redundante con
  `idx_pedido_cliente`; solo sumaba costo de escritura.

Frase: "La IA encontró cosas útiles, pero la decisión de qué aceptar no se
delega."

## 8:30 - 10:00 | Mantenimiento y cierre

- Respaldo diario de PostgreSQL y de `tablet_u8.db`; restauración probada en una
  base nueva, con conteos y `md5`.
- Si se restaura un respaldo viejo, la tablet no manda: se exporta una
  instantánea nueva, se recarga y el semáforo vuelve a evaluar. Un precio viejo
  da `CONFLICTO`; un producto que ya no está da `RECHAZADO`.
- Los `CONFLICTO` los revisa el encargado del turno; los `RECHAZADO`, el
  administrador de datos al cierre. Ningún conflicto se resuelve solo por
  tiempo.
- Cierre: "La tablet propone, PostgreSQL dispone. `SIMULADO_APROBADO` no es una
  venta."

## Preguntas probables

| Pregunta | Respuesta corta |
|---|---|
| ¿Por qué no guardar el precio como `REAL`? | Porque 0.1 no es exacto en binario; en centavos las comparaciones son exactas. |
| ¿Qué pasa si la tablet estuvo offline mucho tiempo? | La fecha de copia queda vieja; se fuerza una instantánea nueva y los precios viejos dan `CONFLICTO`. |
| ¿Por qué no borrar el producto en SQLite? | Porque un borrador viejo puede referenciarlo; la lápida conserva la fila y el catálogo la oculta. |
| ¿Qué evita duplicar una solicitud? | La PK `solicitud_uuid` y, en un sistema real, una tabla de idempotencia en el servidor. |
| ¿La tablet puede vender sin stock? | No: el semáforo la rechaza y, en un sistema real, el servidor vuelve a validar stock antes de confirmar. |
| ¿MongoDB puede cambiar el precio? | No. MongoDB decora la ficha; el precio vive en PostgreSQL. |

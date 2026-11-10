# U8 - Mapa de los tres motores

## Tabla de autoridad

| Motor | Qué guarda | Quién manda | Qué no guarda |
|---|---|---|---|
| **PostgreSQL 18.6** (`foodstore_u8_lab`) | Categorías, productos, precio de lista, stock, pedidos, detalle de venta, clientes, roles y auditoría. | Es la **fuente de verdad** de precio, stock y ventas. Toda confirmación nace acá. | Fotos, reseñas, atributos variables del producto; borradores offline. |
| **MongoDB** (U7) | Ficha ampliada del producto: imágenes, alérgenos, reseñas y atributos que cambian por producto. También eventos de catálogo. | Es la fuente de verdad del **contenido** de la ficha. Referencia `producto_id` de PostgreSQL. | Precio, stock, pedidos, ventas y datos personales. |
| **SQLite 3.54** (`tablet_u8.db`) | `producto_cache` (id, nombre, precio en centavos, stock visto, disponible, eliminado, fecha de copia), borradores, ítems y cola de sincronización. | **No manda** sobre el servidor. Solo propone y simula. | Clientes, mails, celulares, ventas confirmadas, credenciales. |

## Flujo

```text
                    MongoDB (U7)
                 ficha / contenido
                        |
                        | producto_id
                        v
PostgreSQL  ->  v_snapshot_movil  ->  CSV  ->  SQLite
(precio,          (solo catálogo)             (producto_cache)
 stock, ventas)                                     |
                                                    | borrador + ítems
                                                    v
                                              cola_sync PENDIENTE
                                                    |
                                          semáforo local (SQLite)
                                                    |
                         +--------------------------+--------------------------+
                         |                          |                          |
                    RECHAZADO                   CONFLICTO              SIMULADO_APROBADO
                  (no hay venta)             (revisión humana)         (no es venta)
```

## Reglas de frontera

1. **PostgreSQL decide precio, stock y venta.** La tablet nunca envía un
   `UPDATE` de stock ni un `INSERT` de pedido confirmado.
2. **MongoDB decora, no decide.** Si la ficha y PostgreSQL discrepan en precio,
   gana PostgreSQL.
3. **SQLite es una foto con fecha.** `stock_visto` y `precio_centavos` son
   valores del momento de la copia; no son una reserva.
4. **La cola es una propuesta.** `SIMULADO_APROBADO` significa "los datos
   coinciden", no "venta confirmada".
5. **La baja lógica viaja como lápida.** La tablet conserva la fila con
   `eliminado = 1` para no romper borradores viejos, pero el catálogo operativo
   la oculta.

> Nota de alcance: el mapa fija la frontera de autoridad de cada motor. La
> implementación de U7 se conserva en su entrega y no se modifica en U8; MongoDB
> sigue siendo la fuente del contenido de la ficha, nunca del precio ni del stock.

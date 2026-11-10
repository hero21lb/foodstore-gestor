# Normalización - Food Store

## Dependencias funcionales relevantes

- `categoria.id -> nombre, descripcion, activo`
- `producto.id -> nombre, descripcion, precio, stock, categoria_id, activo`
- `cliente.id -> nombre, apellido, mail, celular`; además, `mail -> cliente.id`
- `pedido.id -> fecha, forma_pago, cliente_id`
- `detalle_pedido.id -> cantidad, precio_unitario, pedido_id, producto_id`
- `(pedido_id, producto_id) -> cantidad, precio_unitario` por la restricción UNIQUE.

## 1FN

Cada tabla tiene una clave primaria y atributos atómicos. Los renglones del pedido
no se almacenan como una lista dentro de `pedido`: se representan en
`detalle_pedido`.

## 2FN

Los atributos de detalle (`cantidad`, `precio_unitario`) dependen de la línea del
pedido y no de una parte de la combinación pedido-producto. En la variante con
identificador artificial también se conserva `UNIQUE(pedido_id, producto_id)`.

## 3FN / BCNF

Los datos de categoría y cliente no se repiten en producto ni pedido. El precio
histórico se guarda en `detalle_pedido`, porque representa el valor al momento de
la venta y no depende transitivamente del precio actual del producto. Las
dependencias no triviales tienen como determinante una clave candidata, por lo
que las relaciones principales cumplen BCNF.

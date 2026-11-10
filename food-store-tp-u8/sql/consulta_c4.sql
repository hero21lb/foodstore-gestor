-- C4: después de recargar el catálogo con la instantánea que trae la lápida.
.print 'C4: la fila del producto 2 sigue en la tablet, marcada como eliminada'
SELECT id, nombre, precio_centavos, disponible, eliminado, fecha_copia
FROM producto_cache
WHERE id = 2;

.print 'C4: el catálogo operativo ya no lo muestra'
SELECT count(*) AS productos_2_en_catalogo
FROM vw_catalogo_disponible
WHERE id = 2;

.print 'C4: pero la fila no se borró'
SELECT count(*) AS fila_2_en_cache
FROM producto_cache
WHERE id = 2;

-- ============================================================
-- U8 - PostgreSQL de PRUEBAS (foodstore_u8_lab)
-- NO ejecutar sobre railway ni sobre foodstore.
-- Crea la vista de instantánea que consume la tablet y dos
-- productos inventados para completar el catálogo de la feria.
-- ============================================================

SET TIME ZONE 'America/Argentina/Buenos_Aires';

-- Instantánea móvil: solo columnas aptas para viajar a la tablet.
-- El precio viaja en centavos enteros; stock y estado son de lectura.
-- La fecha se fija a la zona de negocio para que no dependa de la
-- zona horaria de la sesión que exporta.
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id                                   AS producto_id,
       p.nombre,
       (p.precio * 100)::bigint               AS precio_centavos,
       p.stock,
       (p.activo AND p.stock > 0)             AS disponible,
       (NOT p.activo)                         AS eliminado,
       (now() AT TIME ZONE 'America/Argentina/Buenos_Aires')::date
                                              AS fecha_copia
FROM producto p;

COMMENT ON VIEW v_snapshot_movil IS
  'Parada 5 U8: proyección mínima para la tablet. No incluye cliente, mail, celular ni ventas.';

-- Dos productos inventados para la feria. Idempotente por nombre.
INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id)
SELECT 'Pizza Feria', 'Pizza individual para la feria', 1200.00, 15,
       (SELECT id FROM categoria WHERE nombre = 'Pizzas')
WHERE NOT EXISTS (SELECT 1 FROM producto WHERE nombre = 'Pizza Feria');

INSERT INTO producto (nombre, descripcion, precio, stock, categoria_id)
SELECT 'Limonada Feria', 'Limonada artesanal 500 ml', 600.00, 30,
       (SELECT id FROM categoria WHERE nombre = 'Bebidas')
WHERE NOT EXISTS (SELECT 1 FROM producto WHERE nombre = 'Limonada Feria');

-- La vista debe devolver una fila por producto, sin duplicados.
SELECT count(*) AS filas_snapshot,
       count(DISTINCT producto_id) AS productos_distintos
FROM v_snapshot_movil;

-- U8 - Exportación de la instantánea (psql).
-- Ejecutar conectado a foodstore_u8_lab, desde la carpeta u8/.
-- El CSV resultante se importa en SQLite con:
--   .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
\copy (SELECT producto_id, nombre, precio_centavos, stock, disponible, eliminado, fecha_copia FROM v_snapshot_movil ORDER BY producto_id) TO 'servidor_snapshot.csv' CSV HEADER

-- Para los casos C2, C3 y C4, cambiar el nombre del archivo:
--   \copy (...) TO 'snapshots/caso_c2.csv' CSV HEADER

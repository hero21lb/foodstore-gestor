-- Parte B. Configuracion global aplicada previamente por el usuario.
SELECT name,setting,pending_restart FROM pg_settings WHERE name IN ('log_connections','log_disconnections','log_statement','log_line_prefix');
SET application_name='foodstore_u5_auditoria';
SET log_statement='all';
SELECT count(*) clientes FROM cliente;
BEGIN;
INSERT INTO categoria(nombre,descripcion) VALUES ('U5_AUDITORIA_SINTETICA','Prueba con rollback');
UPDATE producto SET stock=stock WHERE id=(SELECT min(id) FROM producto);
ROLLBACK;
-- Intento de conexion SQL fallida: laboratorio_u5.py.

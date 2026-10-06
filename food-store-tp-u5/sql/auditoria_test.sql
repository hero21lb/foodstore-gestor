-- Food Store - Unidad 5 / Parte B
-- La configuración requiere reinicio o recarga del servidor según el parámetro.
-- Ejecutar como administrador del servidor, no como app_web.

ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'mod';
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u,db=%d,app=%a,client=%h ';
SELECT pg_reload_conf();

-- Secuencia de prueba: lectura, inserción y actualización.
SELECT id, nombre, apellido FROM cliente ORDER BY id LIMIT 1;
BEGIN;
INSERT INTO categoria (nombre, descripcion) VALUES ('AUDITORIA_TEST', 'Fila temporal de prueba');
UPDATE producto SET stock = stock WHERE id = (SELECT min(id) FROM producto);
ROLLBACK;

-- El intento fallido de autenticación contra fn_autenticar debe ejecutarse
-- solo si esa función existe en la instalación del equipo.
DO $$
BEGIN
  IF to_regprocedure('fn_autenticar(text,text)') IS NOT NULL THEN
    PERFORM fn_autenticar('usuario.sintetico@invalid.test', 'clave_incorrecta');
  ELSE
    RAISE NOTICE 'fn_autenticar(text,text) no está definida en esta base';
  END IF;
END $$;

SHOW log_connections;
SHOW log_disconnections;
SHOW log_statement;
SHOW log_line_prefix;

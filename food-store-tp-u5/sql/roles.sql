-- Food Store - Unidad 5 / Parte A
-- PostgreSQL 16+. Ejecutar como propietario de la base o administrador.
-- No contiene contraseñas: deben definirse fuera del repositorio.

DO $$ BEGIN
  CREATE ROLE rol_app_lectura NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE rol_app_escritura NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE rol_soporte NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE rol_reportes NOLOGIN;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE app_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE ROLE admin_datos LOGIN NOSUPERUSER CREATEDB CREATEROLE NOREPLICATION;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

GRANT SELECT ON categoria, producto, cliente, pedido, detalle_pedido TO rol_app_lectura;
GRANT SELECT ON categoria, producto, cliente, pedido, detalle_pedido TO rol_reportes;
GRANT SELECT ON auditoria_stock TO rol_soporte;
GRANT SELECT ON categoria, producto, pedido, detalle_pedido TO rol_soporte;

GRANT SELECT, INSERT, UPDATE ON producto, pedido, detalle_pedido TO rol_app_escritura;
GRANT SELECT ON categoria, cliente TO rol_app_escritura;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;

-- Permiso puntual a nivel de columna: soporte puede contactar clientes, pero
-- no recibe acceso al correo electrónico ni a otros datos de contacto.
GRANT SELECT (id, nombre, apellido) ON cliente TO rol_soporte;

GRANT rol_app_lectura, rol_app_escritura TO app_web;
GRANT rol_soporte, rol_reportes TO admin_datos;

-- Asegura que futuras tablas no queden abiertas por defecto.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SCHEMA public TO rol_app_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_app_lectura, rol_reportes;

-- Verificación reproducible.
\du app_web
\du admin_datos
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes')
ORDER BY grantee, table_name, privilege_type;

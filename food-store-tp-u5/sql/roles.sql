-- Parte A. Primera instalacion en foodstore; abortar ante roles existentes.
BEGIN;
DO $$ BEGIN
 IF current_database()<>'foodstore' THEN RAISE EXCEPTION 'Usar foodstore'; END IF;
 IF NOT EXISTS(SELECT FROM pg_extension WHERE extname='pgcrypto') THEN RAISE EXCEPTION 'Instalar pgcrypto manualmente'; END IF;
END $$;
CREATE ROLE rol_app_lectura NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_soporte NOLOGIN;
CREATE ROLE rol_reportes NOLOGIN;
CREATE ROLE app_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE admin_datos LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE foodstore_auth_owner NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE;
-- Sin passwords permanentes; validacion mediante SET SESSION AUTHORIZATION.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_app_lectura,rol_app_escritura,rol_soporte,rol_reportes,foodstore_auth_owner;
GRANT SELECT ON categoria,producto,cliente,pedido,detalle_pedido TO rol_app_lectura;
GRANT SELECT ON categoria,producto,pedido,detalle_pedido TO rol_reportes,rol_soporte;
GRANT SELECT(id,nombre,apellido) ON cliente TO rol_soporte;
GRANT SELECT ON auditoria_stock TO rol_soporte;
GRANT SELECT,INSERT,UPDATE ON producto,pedido,detalle_pedido TO rol_app_escritura;
GRANT SELECT ON categoria,cliente TO rol_app_escritura;
GRANT USAGE ON SEQUENCE producto_id_seq,pedido_id_seq,detalle_pedido_id_seq,auditoria_stock_id_seq TO rol_app_escritura;
GRANT INSERT ON auditoria_stock TO rol_app_escritura;
GRANT rol_app_lectura,rol_app_escritura TO app_web;
GRANT rol_soporte,rol_reportes TO admin_datos;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- Global: revocar solo en esquema no elimina el EXECUTE publico global.
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
CREATE TABLE usuario(
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,nombre text NOT NULL,
 mail text UNIQUE NOT NULL,rol text NOT NULL CHECK(rol IN ('cliente','operador','soporte')),
 fecha_alta timestamptz NOT NULL,activo boolean NOT NULL DEFAULT true,password_hash text NOT NULL);
-- Identidades enteramente sinteticas, independientes de cliente.
INSERT INTO usuario(nombre,mail,rol,fecha_alta,password_hash)
SELECT 'Persona sintetica '||n,'persona'||n||'@example.invalid',
 (ARRAY['cliente','operador','soporte'])[1+(n%3)],
 timestamptz '2026-01-01 00:00:00+00'+(n%6)*interval '1 month',
 public.crypt(encode(gen_random_bytes(24),'hex'),public.gen_salt('bf',10))
FROM generate_series(1,18) n;
GRANT SELECT(id,nombre,mail,rol,fecha_alta,activo) ON usuario TO rol_app_lectura;
GRANT SELECT(id,rol,fecha_alta) ON usuario TO rol_reportes;
GRANT SELECT(id,nombre,rol,activo) ON usuario TO rol_soporte;
GRANT UPDATE(rol,activo) ON usuario TO admin_datos;
GRANT SELECT,UPDATE(password_hash) ON usuario TO foodstore_auth_owner;
GRANT EXECUTE ON FUNCTION public.crypt(text,text),public.gen_salt(text,integer) TO foodstore_auth_owner;
CREATE FUNCTION fn_autenticar(p_mail text,p_password text) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
DECLARE found_id bigint;
BEGIN
 SELECT u.id INTO found_id FROM public.usuario u WHERE u.mail=p_mail AND u.activo
 AND u.password_hash=public.crypt(p_password,u.password_hash);
 RAISE LOG 'U5_AUTH resultado=% actor_motor=%',CASE WHEN found_id IS NULL THEN 'fallido' ELSE 'exitoso' END,session_user;
 RETURN found_id;
END $$;
CREATE FUNCTION fn_resetear_password(p_id bigint,p_password text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,pg_temp AS $$
BEGIN
 IF length(p_password)<16 THEN RAISE EXCEPTION 'Minimo 16 caracteres'; END IF;
 UPDATE public.usuario SET password_hash=public.crypt(p_password,public.gen_salt('bf',10)) WHERE id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Usuario inexistente'; END IF;
 RAISE LOG 'U5_RESET actor_motor=%',session_user;
END $$;
GRANT CREATE ON SCHEMA public TO foodstore_auth_owner;
ALTER FUNCTION fn_autenticar(text,text) OWNER TO foodstore_auth_owner;
ALTER FUNCTION fn_resetear_password(bigint,text) OWNER TO foodstore_auth_owner;
REVOKE CREATE ON SCHEMA public FROM foodstore_auth_owner;
REVOKE ALL ON FUNCTION fn_autenticar(text,text),fn_resetear_password(bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_autenticar(text,text) TO app_web;
GRANT EXECUTE ON FUNCTION fn_resetear_password(bigint,text) TO admin_datos;
COMMIT;
\du
SELECT grantee,table_name,privilege_type FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','admin_datos','foodstore_auth_owner') ORDER BY 1,2,3;
SELECT grantee,table_name,column_name,privilege_type FROM information_schema.role_column_grants
WHERE table_name IN ('usuario','cliente') AND grantee LIKE 'rol_%' ORDER BY 1,2,3,4;

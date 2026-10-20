-- Parte D. No se inventa un mes unico para todos los clientes.
BEGIN;
CREATE TABLE IF NOT EXISTS usuario_anon(id bigint PRIMARY KEY,rol text NOT NULL,mes_alta date NOT NULL,nombre_sintetico text NOT NULL,mail_sintetico text UNIQUE NOT NULL);
TRUNCATE usuario_anon;
INSERT INTO usuario_anon SELECT id,rol,date_trunc('month',fecha_alta AT TIME ZONE 'UTC')::date,'Usuario_'||lpad(id::text,6,'0'),'anon_'||id||'@example.invalid' FROM usuario;
COMMIT;
SELECT 'usuario' fuente,rol,date_trunc('month',fecha_alta AT TIME ZONE 'UTC')::date mes_alta,count(*) cantidad FROM usuario GROUP BY 2,3
UNION ALL SELECT 'usuario_anon',rol,mes_alta,count(*) FROM usuario_anon GROUP BY 2,3 ORDER BY 2,3,1;
WITH a AS(SELECT rol,date_trunc('month',fecha_alta AT TIME ZONE 'UTC')::date mes_alta,count(*) cantidad FROM usuario GROUP BY 1,2),b AS(SELECT rol,mes_alta,count(*) cantidad FROM usuario_anon GROUP BY 1,2)
SELECT count(*) diferencias FROM((SELECT * FROM a EXCEPT SELECT * FROM b) UNION ALL (SELECT * FROM b EXCEPT SELECT * FROM a)) d;
-- Tecnica determinista con id estable: seudonimizacion, no anonimato irreversible.

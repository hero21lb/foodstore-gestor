-- Food Store - Unidad 5 / Parte D
-- Anonimización determinista: conserva agrupamientos y conteos, no valores
-- identificables. No copia mail, celular ni nombres reales.

CREATE TABLE IF NOT EXISTS usuario_anon (
  id BIGINT PRIMARY KEY,
  rol TEXT NOT NULL,
  mes_alta DATE NOT NULL,
  nombre_sintetico TEXT NOT NULL,
  mail_sintetico TEXT NOT NULL UNIQUE
);

TRUNCATE usuario_anon;

-- El esquema de U1-U4 no posee usuario. Se modela el equivalente disponible
-- (cliente) para que el ejercicio pueda ejecutarse sin inventar columnas.
INSERT INTO usuario_anon (id, rol, mes_alta, nombre_sintetico, mail_sintetico)
SELECT id,
       'cliente' AS rol,
       date_trunc('month', current_date)::date AS mes_alta,
       'Usuario_' || lpad(row_number() OVER (ORDER BY id)::text, 6, '0'),
       'anon_' || id || '@example.invalid'
FROM cliente;

-- Consulta agregada sobre la tabla anonimizada.
SELECT rol, mes_alta, count(*) AS cantidad
FROM usuario_anon
GROUP BY rol, mes_alta
ORDER BY rol, mes_alta;

-- Consulta equivalente sobre la fuente real, sin proyectar PII.
SELECT 'cliente' AS rol, date_trunc('month', current_date)::date AS mes_alta,
       count(*) AS cantidad
FROM cliente
GROUP BY 1, 2
ORDER BY 1, 2;

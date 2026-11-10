-- ============================================================
-- TPI Food Store - orden de instalación reproducible
-- PostgreSQL 16+ / PL/pgSQL
-- Ejecutar desde psql en una base VACÍA:
--   \i setup_tpi.sql  (desde la carpeta bases de datos)
-- ============================================================

\ir sql/schema_completo.sql
\ir sql/data.sql
\ir sql/restricciones_tp2.sql
\ir sql/indices.sql
\ir sql/indices_u3.sql
\ir sql/views.sql
\ir sql/objetos_programables_tpi.sql

ANALYZE categoria;
ANALYZE producto;
ANALYZE cliente;
ANALYZE pedido;
ANALYZE detalle_pedido;

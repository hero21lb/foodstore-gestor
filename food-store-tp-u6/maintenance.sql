-- Ejecutar en psql fuera de BEGIN. Observacion previa y accion condicionada.
SELECT name,setting,unit FROM pg_settings
WHERE name IN ('autovacuum','autovacuum_analyze_threshold',
               'autovacuum_analyze_scale_factor','autovacuum_vacuum_threshold',
               'autovacuum_vacuum_scale_factor');
SELECT schemaname,relname,n_live_tup,n_dead_tup,n_mod_since_analyze,
       last_autovacuum,last_analyze,last_autoanalyze
FROM pg_stat_user_tables ORDER BY schemaname,relname;
-- Justificacion: luego de restore o carga, el planificador necesita estadisticas.
-- ANALYZE no reescribe la tabla ni requiere el bloqueo exclusivo de VACUUM FULL.
-- Solo ejecutar si aun no hay analisis o se supera el umbral real del servidor.
SELECT format('ANALYZE %I.%I;',schemaname,relname)
FROM pg_stat_user_tables
WHERE (last_analyze IS NULL AND last_autoanalyze IS NULL)
 OR n_mod_since_analyze >= current_setting('autovacuum_analyze_threshold')::numeric
    + current_setting('autovacuum_analyze_scale_factor')::numeric*n_live_tup
\gexec
SELECT relname,n_live_tup,n_dead_tup,n_mod_since_analyze,last_analyze,last_autoanalyze
FROM pg_stat_user_tables ORDER BY relname;

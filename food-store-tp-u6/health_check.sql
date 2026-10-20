SELECT clock_timestamp() AS instante, current_database() AS base,
       pg_size_pretty(pg_database_size(current_database())) AS tamano;
SELECT datname, numbackends, xact_commit, xact_rollback, deadlocks, stats_reset
FROM pg_stat_database WHERE datname = current_database();
SELECT relname, n_live_tup, n_dead_tup, n_mod_since_analyze,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables ORDER BY n_dead_tup DESC, relname;
SELECT pid, usename, application_name, state, clock_timestamp()-query_start AS duracion,
       wait_event_type, wait_event, left(query,160) AS consulta
FROM pg_stat_activity
WHERE datname=current_database() AND state <> 'idle' AND pid<>pg_backend_pid();

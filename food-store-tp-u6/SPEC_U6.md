# Plan de mantenimiento de Food Store - U6

Objetivo: respaldar, observar y recuperar Food Store en PostgreSQL 16+ sin
interrumpir ni sobrescribir la fuente. Laboratorio: Railway, PostgreSQL 18.6;
base principal `foodstore`, restauracion `foodstore_restore_test`.

| Tarea | Frecuencia propuesta | Condicion de exito |
|---|---|---|
| Respaldo custom | Diaria, 02:00 America/Argentina/Buenos_Aires | .dump fechado, pg_dump retorna 0, listado legible, log y conteos guardados |
| Chequeo de salud | Diaria, luego del respaldo | Consultas ejecutadas; alertar ante actividad bloqueada, errores o crecimiento inusual |
| Mantenimiento | Semanal | Revisar autovacuum/estadisticas; ANALYZE solo si faltan estadisticas o se supera umbral de modificaciones |
| Restauracion de prueba | Semanal | Crear base nueva, restaurar sin errores, conteos coincidentes y cero invalidos |

RPO previsto: hasta 24 horas con frecuencia diaria. RTO objetivo para este
conjunto pequeno: 120 segundos. En el ensayo, RTO se mide desde inmediatamente
antes de CREATE DATABASE hasta terminar las validaciones; RPO observado se
discute con la antiguedad del respaldo al inicio, no con la duracion del restore.

Reglas: nunca eliminar ni reemplazar `foodstore`; no programar pruebas
destructivas; abortar si `foodstore_restore_test` existe. Secretos solo mediante
variables de entorno efimeras; .dump excluidos de Git. Repositorio contiene
scripts, evidencia resumida y logs sin datos de filas. No hay programacion
automatica activa: las frecuencias anteriores son el plan propuesto.

Ejecutar primero manualmente backup_foodstore.ps1, health_check.sql,
maintenance.sql y restore_test.ps1. Si falla pg_dump o una validacion, terminar
con codigo distinto de cero y conservar diagnostico. La aplicacion permanece
apagada durante este ensayo; se comprueba que no hay otros escritores para
comparar los conteos del respaldo.

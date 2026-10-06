# Informe de auditoría - Parte B

Se configuraron `log_connections=on`, `log_disconnections=on` y `log_statement=mod`. El prefijo registra fecha/hora, PID, usuario, base, aplicación y cliente. La configuración se aplica con `ALTER SYSTEM` y `pg_reload_conf()` desde `sql/auditoria_test.sql`; la instancia puede requerir reinicio para ciertos parámetros.

El log permite identificar quién, qué operación, cuándo y desde qué cliente ocurrió. El registro nativo no garantiza el detalle de cada fila leída o modificada; para granularidad de auditoría SQL puede evaluarse `pgaudit`, con revisión de volumen, retención y permisos.

El archivo de log es un activo sensible porque puede contener nombres de usuario, consultas, errores y metadatos de conexión. Debe ser legible solo por el servicio de PostgreSQL y operadores autorizados mediante permisos del sistema operativo; no debe exponerse a `PUBLIC`, a la aplicación ni a un asistente de IA sin anonimización.

La salida real debe generarse en la máquina de desarrollo ejecutando el script y copiarse, ya anonimizada, en `log_auditoria_prueba.txt`.

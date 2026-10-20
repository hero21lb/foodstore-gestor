# Parte B - Auditoria real en Railway

Verificacion 20/10/2026: PostgreSQL 18.6, base foodstore en postgrefacu.
El usuario activo previamente log_connections=on, log_disconnections=on,
log_statement=mod y log_line_prefix con fecha, PID, usuario, base, app y origen.
No se ejecuto ALTER SYSTEM desde Codex. La salida esta en salida_auditoria.txt.

Se ejecuto SELECT count(*) de cliente, INSERT de categoria y UPDATE de producto
con ROLLBACK; se rechazo una conexion SQL con un usuario inexistente. Se
capturaron logs reales de Railway, no ejemplos. Para registrar las lecturas,
la sesion de auditoria usa log_statement=all. El nivel global mod no registra SELECT.

Quien: usuario de conexion y actor_motor en U5_AUTH. Que: sentencias/eventos;
cuando: fecha UTC; desde donde: origen IP sustituido por IP_SINTETICA en la entrega.
SET SESSION AUTHORIZATION permite probar los privilegios del actor, pero la
conexion original es de postgres: no se afirma haber probado el login SQL real
con passwords permanentes de app_web/admin_datos. Ambos quedan sin password.

No hay detalle automatico fila por fila ni prueba de exfiltracion real. pgaudit
puede ampliar la auditoria de objetos/sentencias; los valores anteriores/nuevos
de cada fila requieren una estrategia adicional, por ejemplo triggers especificos.
El trigger de stock existente no reemplaza la auditoria general del servidor.

Los logs son un activo sensible: pueden contener consultas, identidades y secretos.
Solo administradores/auditores autorizados deben acceder, con lectura restringida
y sin escritura para los actores auditados, retencion acotada y almacenamiento protegido.

## Hallazgo corregido
RAISE LOG incluyo el STATEMENT con parametros interpolados por psycopg2, incluso
con log_statement=none. Eran claves aleatorias de laboratorio, pero se trato como
un defecto real: ahora las llamadas sensibles usan log_min_error_statement=panic,
log_statement=none y longitudes de parametros cero; se repitio el ensayo. En
la evidencia se sustituyeron los parametros completos por PARAMETROS_REDACTADOS.
Para una aplicacion real conviene ademas protocolo extendido con bind, politica
central de logs y limitacion de intentos. No activar all globalmente en produccion.

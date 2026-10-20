# Parte C - Simulacro y lectura critica

Ejecucion real: laboratorio_u5.py, contra foodstore. Orden: tres fallos de
fn_autenticar, exito, lectura de las 18 filas sinteticas de usuario sin hashes,
GRANT admin_datos TO app_web. El GRANT fallo con SQLSTATE 42501 y al finalizar
pg_has_role confirmo que no existe esa membresia. Otras pruebas negaron lectura
de hashes, DELETE de pedidos, reseteo desde app_web y lectura de mail por soporte.

El script simulacro_incidente.sql describe las llamadas; laboratorio_u5.py contiene
la orquestacion ejecutable y aserciones. Las claves se generan solo en memoria.
La lectura masiva devuelve realmente todas las filas al cliente y solo registra
su cantidad; no se sustituye esa lectura por un mero COUNT.

## Reconstruccion con Codex, no atribuida a OpenCode
El log permite observar fallos seguidos de exito y luego una lectura e intento
de ampliacion de privilegios denegado. Es compatible con un ejercicio de abuso
de una cuenta, pero no prueba quien estaba al teclado ni robo de credenciales,
fuerza bruta automatizada o extraccion fuera del cliente de laboratorio.

## Contraste con la ejecucion
Coinciden el orden, actores sinteticos y denegacion. El conteo de 18 filas se
confirma en pruebas_reales.json: el log de una sentencia SELECT no demuestra por
si solo cuantas filas se recibieron. El usuario del prefijo puede ser postgres
por la conexion administrativa original; el actor efectivo se cambia con SET
SESSION AUTHORIZATION y queda explicito en U5_AUTH. No inventar una IP atacante,
fecha local o causa humana a partir del log anonimizado.

OpenCode se intento ejecutar para revisar el SQL; devolvio HTTP 400 por esquemas
incompatibles de herramientas. opencode_auditoria.jsonl conserva el error. No
produjo una reconstruccion valida; falta enviarle exclusivamente el log anonimizado
y conservar su respuesta completa para cumplir literalmente esa parte de la consigna.

## Propuesta de contencion para decision humana
En un incidente real: revocar/suspender temporalmente la cuenta de aplicacion,
conservar evidencia, revisar membresias y origen; rotar credenciales si hay indicios
de compromiso y aplicar rate limiting. No bloquear un origen deducido de un token
anonimizado ni cambiar roles automaticamente por una sugerencia de IA. Aqui no se
aplico contencion real: fue un simulacro propio. La aprobacion final es del estudiante.
